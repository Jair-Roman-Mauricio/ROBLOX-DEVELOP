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

OUT = sys.argv[sys.argv.index("--") + 1]
PLANOS = ("M_Lamp_", "M_Mark_", "M_Window_")
PX_POR_M = 10  # densidad de textura
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
    for clave, tipo, espacio, t in (("Color", 'DIFFUSE', 'sRGB', tam), ("Normal", 'NORMAL', 'Non-Color', tam),
                                    ("Rugosidad", 'ROUGHNESS', 'Non-Color', max(MIN_TAM, tam // 2))):
        img = bpy.data.images.new(nombre + "_" + clave, t, t)
        img.colorspace_settings.name = espacio
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = img
        for x in nt.nodes: x.select = False
        n.select = True; nt.nodes.active = n
        if tipo == 'DIFFUSE':
            sc.render.bake.use_pass_direct = False
            sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
        bpy.ops.object.bake(type=tipo)
        img.pack(); imgs[clave] = img
        nt.nodes.remove(n)
    # metal: el valor del material original (constante)
    bsdf = next((x for x in nt.nodes if x.type == 'BSDF_PRINCIPLED'), None)
    metal = bsdf.inputs["Metallic"].default_value if bsdf and not bsdf.inputs["Metallic"].is_linked else 0.3
    final = bpy.data.materials.new("R_" + nombre); final.use_nodes = True
    ft = final.node_tree; b = ft.nodes["Principled BSDF"]
    tc = ft.nodes.new("ShaderNodeTexImage"); tc.image = imgs["Color"]
    tn = ft.nodes.new("ShaderNodeTexImage"); tn.image = imgs["Normal"]
    tr = ft.nodes.new("ShaderNodeTexImage"); tr.image = imgs["Rugosidad"]
    nm = ft.nodes.new("ShaderNodeNormalMap")
    ft.links.new(tc.outputs["Color"], b.inputs["Base Color"])
    ft.links.new(tn.outputs["Color"], nm.inputs["Color"]); ft.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    ft.links.new(tr.outputs["Color"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = metal
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
