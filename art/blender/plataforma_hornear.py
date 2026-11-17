"""
Prepara la plataforma offshore (Descargas/storm-rig/storm_rig/platform.blend) para Roblox.

El original no tiene UV y su aspecto sale de shaders procedurales (óxido, sal, zona húmeda) que
Roblox no entiende: importado tal cual se ve de plástico. Para cada malla única (las copias
enlazadas comparten malla y textura):
  - UV con Smart UV Project
  - hornea color, relieve (normal) y rugosidad a imágenes; tamaño según su superficie
  - deja un material con esas imágenes (el importador de Roblox crea un SurfaceAppearance)
Las lámparas, marcas y ventanas no se hornean: son color plano (las lámparas pasan a Neon
en el juego).

  Blender -b <platform.blend> --python plataforma_hornear.py -- <salida.glb>
"""
import bpy, bmesh, sys, math, os, time
import numpy as np

OUT = sys.argv[sys.argv.index("--") + 1]
PLANOS = ("M_Lamp_", "M_Mark_", "M_Window_")
PX_POR_M = 16  # densidad de textura

# Metal (0..1) del acero limpio de cada material. El original lo deja en 0.15 y una rugosidad
# alta: en Roblox se ve pintura mate. Aquí el metal limpio brilla, la pintura es semimetálica
# (se ve acero bajo la pintura) y el óxido no es metal.
METAL = {
    "M_Steel_GreyBlue": 0.95, "M_Steel_DarkWet": 0.95, "M_Pipe_Grey": 0.95, "M_Grating": 0.95,
    "M_Helideck": 0.6, "M_Cladding_GreyBlue": 0.75,
    "M_Paint_Ochre": 0.55, "M_Leg_OchreWeathered": 0.55, "M_Brace_OchreWet": 0.55,
    "M_Paint_Red": 0.5, "M_Paint_White": 0.5, "M_Lifeboat_Orange": 0.1,
}
MIN_TAM, MAX_TAM = 128, 1024

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 4
sc.render.bake.margin = 4

objs = [o for o in bpy.data.objects if o.type == 'MESH']
por_malla = {}
for o in objs:
    por_malla.setdefault(o.data.name, o)

def area_mundo(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    a = sum(f.calc_area() for f in bm.faces); bm.free()
    return a

def potencia(n):
    p = MIN_TAM
    while p < n and p < MAX_TAM:
        p *= 2
    return p

def material_de(o):
    return o.material_slots[0].material if o.material_slots else None

inicio = time.time()
hechos = 0
for nombre, o in sorted(por_malla.items()):
    mat = material_de(o)
    if mat is None or mat.name.startswith(PLANOS) or not mat.use_nodes:
        continue
    me = o.data
    # UV
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    while len(me.uv_layers):
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name="UV")
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode='OBJECT')

    tam = potencia(math.sqrt(max(area_mundo(o), 0.01)) * PX_POR_M)
    # copia del material solo para esta malla: el horneado escribe en sus imágenes
    m = mat.copy(); m.name = "B_" + nombre
    me.materials.clear(); me.materials.append(m)
    nt = m.node_tree
    imgs = {}
    mitad = max(MIN_TAM, tam // 2)
    for clave, tipo, espacio, t in (("Color", 'DIFFUSE', 'sRGB', tam), ("Normal", 'NORMAL', 'Non-Color', tam),
                                    ("Rugosidad", 'ROUGHNESS', 'Non-Color', mitad), ("AO", 'AO', 'Non-Color', mitad)):
        img = bpy.data.images.new(nombre + "_" + clave, t, t)
        img.colorspace_settings.name = espacio
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = img
        for x in nt.nodes: x.select = False
        n.select = True; nt.nodes.active = n
        if tipo == 'DIFFUSE':
            sc.render.bake.use_pass_direct = False
            sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
        sc.cycles.samples = 24 if tipo == 'AO' else 4
        bpy.ops.object.bake(type=tipo)
        imgs[clave] = img
        nt.nodes.remove(n)

    # --- mapas para Roblox
    def pix(img):
        w, h = img.size
        return np.array(img.pixels[:], np.float32).reshape(h, w, 4)
    rug = pix(imgs["Rugosidad"])[..., 0]
    ao = pix(imgs["AO"])[..., 0]
    # óxido: donde el shader original sube la rugosidad hacia 0.85
    oxido = np.clip((rug - 0.66) / 0.16, 0, 1)
    nivel = METAL.get(mat.name, 0.6)
    metal = nivel * (1 - oxido)
    rug2 = np.clip(rug * 0.62 + oxido * 0.3, 0.18, 1)
    orm = np.stack([ao, rug2, metal, np.ones_like(ao)], -1)
    img_orm = bpy.data.images.new(nombre + "_ORM", mitad, mitad)
    img_orm.colorspace_settings.name = 'Non-Color'
    img_orm.pixels = orm.ravel(); img_orm.pack()
    # suciedad en juntas y rincones: la oclusión oscurece el color
    col = pix(imgs["Color"])
    h, w = col.shape[:2]
    ao_grande = np.kron(ao, np.ones((h // ao.shape[0], w // ao.shape[1]), np.float32))
    col[..., :3] *= (0.45 + 0.55 * ao_grande)[..., None]
    imgs["Color"].pixels = col.ravel()
    imgs["Color"].pack(); imgs["Normal"].pack()

    final = bpy.data.materials.new("R_" + nombre); final.use_nodes = True
    ft = final.node_tree; b = ft.nodes["Principled BSDF"]
    tc = ft.nodes.new("ShaderNodeTexImage"); tc.image = imgs["Color"]
    tn = ft.nodes.new("ShaderNodeTexImage"); tn.image = imgs["Normal"]
    to = ft.nodes.new("ShaderNodeTexImage"); to.image = img_orm
    sep = ft.nodes.new("ShaderNodeSeparateColor")
    nm = ft.nodes.new("ShaderNodeNormalMap")
    ft.links.new(tc.outputs["Color"], b.inputs["Base Color"])
    ft.links.new(tn.outputs["Color"], nm.inputs["Color"]); ft.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    # glTF: rugosidad en G y metal en B de la misma imagen (metallicRoughnessTexture)
    ft.links.new(to.outputs["Color"], sep.inputs["Color"])
    ft.links.new(sep.outputs["Green"], b.inputs["Roughness"])
    ft.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
    me.materials.clear(); me.materials.append(final)
    for ob in objs:
        if ob.data == me and ob.material_slots:
            ob.material_slots[0].link = 'DATA'
    hechos += 1
    print("HORNEADA", hechos, nombre, mat.name, tam, round(time.time() - inicio), "s", flush=True)

# los materiales planos: un material simple con el color base (y sin shader procedural)
for o in objs:
    mat = material_de(o)
    if mat and mat.name.startswith(PLANOS) and mat.use_nodes:
        bsdf = next((x for x in mat.node_tree.nodes if x.type == 'BSDF_PRINCIPLED'), None)
        col = tuple(bsdf.inputs["Base Color"].default_value) if bsdf else (1, 1, 1, 1)
        if mat.name.startswith("M_Lamp_"):
            em = next((x for x in mat.node_tree.nodes if x.type == 'EMISSION'), None)
            if bsdf and bsdf.inputs["Emission Color"].default_value[:3] != (0, 0, 0):
                col = tuple(bsdf.inputs["Emission Color"].default_value)
            elif em:
                col = tuple(em.inputs["Color"].default_value)
        plano = bpy.data.materials.get("P_" + mat.name) or bpy.data.materials.new("P_" + mat.name)
        plano.use_nodes = True
        plano.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = col
        o.material_slots[0].material = plano

bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, use_selection=True,
                          export_apply=True, export_vertex_color='NONE')
print("ESCRITO", OUT, hechos, "mallas horneadas", round(time.time() - inicio), "s")
