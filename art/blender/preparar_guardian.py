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
import bpy, sys, bmesh, os
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
    print("PIEZA", nombre, "tris", sum(len(p.vertices) - 2 for p in me.polygons), "dim", [round(x, 2) for x in o.dimensions])

for o in list(bpy.data.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_apply=True,
                          export_vertex_color='ACTIVE', export_all_vertex_colors=False)
print("ESCRITO", OUT)
