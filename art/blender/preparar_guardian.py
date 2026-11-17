"""Prepara el árbol GuardianTree (OBJ de Blender) para el importador 3D de Roblox.

  Tronco  ~16.000 triángulos  corteza
  Raices  ~10.300             corteza
  Lianas   ~5.300
  Copa     núcleo de follaje opaco (FoliageCore)
  Hojas    tarjetas con recorte alfa (Leaves + leaf_cluster.png)

Una malla por material, menos de 20.000 triángulos cada una. El color de los materiales del MTL
se multiplica por el color de vértice (oclusión pintada) y se hornea en una textura pequeña por
malla, porque Roblox usa una textura por MeshPart. Pie del tronco en el origen, 1 unidad = 1 stud
(el juego lo escala).

Uso:
  Blender -b --factory-startup --python art/blender/preparar_guardian.py -- <guardian_tree.obj> art/export/ArbolGuardian.glb
"""
import bpy, sys, bmesh, os, math
import numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
TEX = 512

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=SRC)
objs = {o.name.split(".")[0]: o for o in bpy.data.objects if o.type == 'MESH'}
for o in objs.values():
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# separar la copa en núcleo y hojas (dos materiales)
copa = objs["TREE_Canopy"]
bpy.ops.object.select_all(action='DESELECT'); copa.select_set(True); bpy.context.view_layer.objects.active = copa
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
piezas = {}
for o in bpy.data.objects:
    if o.type != 'MESH': continue
    mat = o.material_slots[0].material.name if o.material_slots else ""
    if o.name.startswith("TREE_Canopy"):
        piezas["Hojas" if mat.startswith("Leaves") else "Copa"] = o
    elif o.name.startswith("TREE_Trunk"): piezas["Tronco"] = o
    elif o.name.startswith("TREE_Roots"): piezas["Raices"] = o
    elif o.name.startswith("TREE_Lianas"): piezas["Lianas"] = o

# pie del tronco en el origen
co = np.array([v.co[:] for v in piezas["Tronco"].data.vertices])
base = co[co[:, 2] < co[:, 2].min() + 0.6]
mover = (-base[:, 0].mean(), -base[:, 1].mean(), -co[:, 2].min())
from mathutils import Matrix, Vector
for o in piezas.values():
    o.data.transform(Matrix.Translation(Vector(mover)))

hoja_png = bpy.data.images.load(os.path.join(os.path.dirname(SRC), "leaf_cluster.png"))
hoja_px = np.array(hoja_png.pixels[:], np.float32).reshape(hoja_png.size[1], hoja_png.size[0], 4)

def kd(mat):
    b = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    return np.array(b.inputs["Base Color"].default_value[:3])

# --------------------------------------------------------------------------- corteza
# El modelo original solo trae un color plano por material: en Roblox el tronco se ve de
# plástico. Se hornea una corteza procedural (surcos verticales, grietas, grano, musgo arriba y
# la oclusión del color de vértice) en una textura de color y otra de relieve por pieza.
CORTEZA = {"Tronco": 2048, "Raices": 1024, "Lianas": 512}

def nodo(nt, tipo, **kw):
    n = nt.nodes.new(tipo)
    for k, v in kw.items():
        if k in n.inputs:
            n.inputs[k].default_value = v
        else:
            setattr(n, k, v)
    return n

def material_corteza(color, liana):
    m = bpy.data.materials.new("CortezaHornear"); m.use_nodes = True
    nt = m.node_tree; L = nt.links.new
    bsdf = nt.nodes["Principled BSDF"]
    tc = nodo(nt, "ShaderNodeTexCoord")
    mp = nodo(nt, "ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (3.0, 3.0, 0.9) if not liana else (14, 14, 14)  # surcos alargados en vertical
    L(tc.outputs["Object"], mp.inputs["Vector"])
    dist = nodo(nt, "ShaderNodeTexNoise", **{"Scale": 2.0, "Detail": 4.0})
    L(tc.outputs["Object"], dist.inputs["Vector"])
    mezcla = nodo(nt, "ShaderNodeMix", data_type='VECTOR')
    mezcla.inputs["Factor"].default_value = 0.25
    L(mp.outputs["Vector"], mezcla.inputs[4]); L(dist.outputs["Color"], mezcla.inputs[5])
    grietas = nodo(nt, "ShaderNodeTexVoronoi", feature='DISTANCE_TO_EDGE', **{"Scale": 5.0})
    L(mezcla.outputs[1], grietas.inputs["Vector"])
    rampa = nodo(nt, "ShaderNodeValToRGB")
    rampa.color_ramp.elements[0].position = 0.0
    rampa.color_ramp.elements[1].position = 0.09
    L(grietas.outputs["Distance"], rampa.inputs["Fac"])
    grano = nodo(nt, "ShaderNodeTexNoise", **{"Scale": 40.0, "Detail": 10.0, "Roughness": 0.65})
    L(mp.outputs["Vector"], grano.inputs["Vector"])
    # color: grieta casi negra -> corteza con grano
    oscuro = (color[0] * 0.18, color[1] * 0.16, color[2] * 0.14, 1)
    claro_a = (min(1, color[0] * 0.95), min(1, color[1] * 0.85), min(1, color[2] * 0.8), 1)
    claro_b = (min(1, color[0] * 0.55), min(1, color[1] * 0.5), min(1, color[2] * 0.45), 1)
    g = nodo(nt, "ShaderNodeMix", data_type='RGBA')
    L(grano.outputs["Fac"], g.inputs["Factor"])
    g.inputs[6].default_value = claro_b; g.inputs[7].default_value = claro_a
    c = nodo(nt, "ShaderNodeMix", data_type='RGBA')
    L(rampa.outputs["Color"], c.inputs["Factor"])
    c.inputs[6].default_value = oscuro; L(g.outputs[2], c.inputs[7])
    # musgo en las caras que miran arriba
    geo = nodo(nt, "ShaderNodeNewGeometry")
    sep = nodo(nt, "ShaderNodeSeparateXYZ"); L(geo.outputs["Normal"], sep.inputs["Vector"])
    musgoN = nodo(nt, "ShaderNodeTexNoise", **{"Scale": 6.0, "Detail": 6.0})
    L(tc.outputs["Object"], musgoN.inputs["Vector"])
    mm = nodo(nt, "ShaderNodeMath", operation='MULTIPLY'); L(sep.outputs["Z"], mm.inputs[0]); L(musgoN.outputs["Fac"], mm.inputs[1])
    mr = nodo(nt, "ShaderNodeMapRange", **{"From Min": 0.25, "From Max": 0.45}); L(mm.outputs[0], mr.inputs["Value"])
    mu = nodo(nt, "ShaderNodeMix", data_type='RGBA'); L(mr.outputs["Result"], mu.inputs["Factor"])
    L(c.outputs[2], mu.inputs[6]); mu.inputs[7].default_value = (0.05, 0.09, 0.02, 1)
    # oclusión pintada en el modelo (color de vértice)
    ao = nodo(nt, "ShaderNodeVertexColor", layer_name="Col")
    fin = nodo(nt, "ShaderNodeMix", data_type='RGBA', blend_type='MULTIPLY')
    fin.inputs["Factor"].default_value = 1.0
    L(mu.outputs[2], fin.inputs[6]); L(ao.outputs["Color"], fin.inputs[7])
    L(fin.outputs[2], bsdf.inputs["Base Color"])
    # relieve: las grietas se hunden, el grano rugoso
    alto = nodo(nt, "ShaderNodeMath", operation='ADD')
    L(rampa.outputs["Color"], alto.inputs[0]); alto.inputs[1].default_value = 0
    bump = nodo(nt, "ShaderNodeBump", **{"Strength": 0.9, "Distance": 0.04})
    L(rampa.outputs["Color"], bump.inputs["Height"])
    L(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return m

def hornear(o, color, tam):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 4; sc.cycles.device = 'CPU'
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    while len(o.data.uv_layers):
        o.data.uv_layers.remove(o.data.uv_layers[0])
    o.data.uv_layers.new(name="UV")
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    m = material_corteza(color, o.name == "Lianas")
    o.data.materials.clear(); o.data.materials.append(m)
    imgs = {}
    for clave, tipo, color_space in (("Color", 'DIFFUSE', 'sRGB'), ("Normal", 'NORMAL', 'Non-Color')):
        img = bpy.data.images.new(o.name + clave, tam, tam)
        img.colorspace_settings.name = color_space
        t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = img
        for n in m.node_tree.nodes: n.select = False
        t.select = True; m.node_tree.nodes.active = t
        if tipo == 'DIFFUSE':
            sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
        sc.render.bake.margin = 6
        bpy.ops.object.bake(type=tipo)
        img.pack(); imgs[clave] = img
        m.node_tree.nodes.remove(t)
    final = bpy.data.materials.new(o.name); final.use_nodes = True
    nt = final.node_tree; b = nt.nodes["Principled BSDF"]
    tcol = nt.nodes.new("ShaderNodeTexImage"); tcol.image = imgs["Color"]
    tnor = nt.nodes.new("ShaderNodeTexImage"); tnor.image = imgs["Normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tcol.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tnor.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    # mapa de rugosidad explícito: sin él, Roblox deja la corteza brillante como plástico
    rug = bpy.data.images.new(o.name + "Rugosidad", 8, 8)
    rug.colorspace_settings.name = 'Non-Color'
    rug.pixels = [0.95, 0.95, 0.95, 1.0] * 64; rug.pack()
    trug = nt.nodes.new("ShaderNodeTexImage"); trug.image = rug
    nt.links.new(trug.outputs["Color"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = 0.0
    o.data.materials.clear(); o.data.materials.append(final)
    print("CORTEZA", o.name, tam)

for nombre, o in piezas.items():
    o.name = nombre; o.data.name = nombre
    mat = o.material_slots[0].material
    color = kd(mat)
    me = o.data
    # oclusión pintada: media del color de vértice (escala de grises en el OBJ)
    ca = me.color_attributes[0] if me.color_attributes else None
    occ = np.ones(len(me.vertices))
    if ca is not None and ca.domain == 'POINT':
        cols = np.array([c.color[:3] for c in ca.data]); occ = cols.mean(1)
    if nombre == "Hojas":
        # textura RGBA: color de la hoja con algo de variación de la propia imagen, alfa recortado
        h, w = hoja_px.shape[:2]
        lum = hoja_px[..., :3].mean(2, keepdims=True)
        rgb = np.clip(color * (0.75 + 0.5 * lum), 0, 1)
        alfa = (hoja_px[..., 3:4] > 0.5).astype(np.float32)
        px = np.concatenate([rgb, alfa], 2)
        img = bpy.data.images.new("Hojas", w, h, alpha=True)
        img.pixels = px.ravel(); img.pack()
    else:
        # sin UV útil para hornear: el color de vértice ya multiplica el color base en el
        # importador de Roblox, así que solo se guarda el color plano del material
        img = None
    nuevo = bpy.data.materials.new(nombre); nuevo.use_nodes = True
    b = nuevo.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.9
    b.inputs["Metallic"].default_value = 0.0
    if img:
        t = nuevo.node_tree.nodes.new("ShaderNodeTexImage"); t.image = img
        nuevo.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
        nuevo.node_tree.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
        try: nuevo.surface_render_method = 'DITHERED'
        except Exception: pass
    me.materials.clear(); me.materials.append(nuevo)
    # el color de vértice queda como oclusión (gris) multiplicando el color base
    if ca is not None:
        ca.name = "Col"
    for p in me.polygons: p.use_smooth = True
    if nombre in CORTEZA:
        hornear(o, color, CORTEZA[nombre])
    print("PIEZA", nombre, "tris", sum(len(p.vertices) - 2 for p in me.polygons), "dim", [round(x, 2) for x in o.dimensions])

for o in list(bpy.data.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='SELECT')
# sin colores de vértice: la oclusión ya va dentro de la textura de corteza
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_apply=True,
                          export_vertex_color='NONE')
print("ESCRITO", OUT)
