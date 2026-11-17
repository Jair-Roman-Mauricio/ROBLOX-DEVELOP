"""Convierte el árbol de selva generado con Meshy (una sola malla de ~7,6 millones de triángulos
y texturas 4K, 350 MB) en un modelo que Roblox puede importar y repetir por la selva:

  Arbol  ~18.000 triángulos, una textura de color de 1024 horneada desde el original

Pasos: remallar por vóxeles (el original son miles de láminas sueltas), reducir,
desplegar UV nuevos y hornear el color del original sobre la malla reducida (baúl: flujo
high-poly → low-poly con bake). Queda con la base del tronco en el origen y altura 1, así el
juego lo escala a los studs que quiera. El original no se guarda en el repo.

Uso (tarda unos minutos):
  Blender -b --factory-startup --python art/blender/optimizar_arbol.py -- <original.glb> art/export/ArbolSelva.glb
"""
import bpy, sys, time
import numpy as np
from mathutils import Matrix, Vector
a = sys.argv[sys.argv.index("--")+1:]
SRC, OUT = a[0], a[1]
TRIS = int(a[2]) if len(a) > 2 else 18000
TEX = 1024
VOXEL = 0.012  # tamaño de vóxel del remallado, en unidades del original (mide ~1,9)
t0 = time.time()
def paso(msg): print("PASO %5.0fs %s" % (time.time() - t0, msg), flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
alto_obj = next(o for o in bpy.data.objects if o.type == 'MESH')
mw = alto_obj.matrix_world.copy(); alto_obj.parent = None; alto_obj.matrix_world = mw
bpy.context.view_layer.objects.active = alto_obj; alto_obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
alto_obj.name = "Original"
def tris(o): return sum(len(p.vertices) - 2 for p in o.data.polygons)
paso("importado: %d triángulos" % tris(alto_obj))

# copia de trabajo, soldada
bpy.ops.object.duplicate()
bajo = bpy.context.view_layer.objects.active
bajo.name = "Arbol"; bajo.data.name = "Arbol"
# El original son miles de láminas sueltas que se cruzan (hojas): reducirlo tal cual lo deja hecho
# trizas. Primero se rehace como una sola piel cerrada con un remallado por vóxeles.
m = bajo.modifiers.new("r", 'REMESH'); m.mode = 'VOXEL'; m.voxel_size = VOXEL; m.adaptivity = 0
bpy.ops.object.modifier_apply(modifier=m.name)
paso("remallado: %d triángulos" % tris(bajo))
for objetivo in (TRIS * 12, TRIS):
    n = tris(bajo)
    if n > objetivo:
        m = bajo.modifiers.new("d", 'DECIMATE'); m.ratio = objetivo / n; m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
    paso("reducido a %d" % tris(bajo))
for p in bajo.data.polygons: p.use_smooth = True

# UV nuevos y material con la textura de destino
while bajo.data.uv_layers: bajo.data.uv_layers.remove(bajo.data.uv_layers[0])
bajo.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003)
bpy.ops.object.mode_set(mode='OBJECT')
img = bpy.data.images.new("ArbolColor", TEX, TEX, alpha=False)
mat = bpy.data.materials.new("Arbol"); mat.use_nodes = True
nt = mat.node_tree; bsdf = nt.nodes["Principled BSDF"]
tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = img
bsdf.inputs["Roughness"].default_value = 0.85
bajo.data.materials.clear(); bajo.data.materials.append(mat)
nt.nodes.active = tx
paso("UV listos")

# hornear el color del original sobre la malla reducida
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = 1; sc.cycles.device = 'CPU'
sc.render.bake.use_selected_to_active = True
sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False; sc.render.bake.use_pass_color = True
sc.render.bake.cage_extrusion = 0.03; sc.render.bake.max_ray_distance = 0.1
sc.render.bake.margin = 6
bpy.ops.object.select_all(action='DESELECT')
alto_obj.select_set(True); bajo.select_set(True); bpy.context.view_layer.objects.active = bajo
bpy.ops.object.bake(type='DIFFUSE')
# los rayos que no encontraron el original dejan píxeles negros: se rellenan con el color medio
px = np.array(img.pixels[:], np.float32).reshape(-1, 4)
negro = px[:, :3].sum(1) < 0.03
if (~negro).any(): px[negro, :3] = px[~negro, :3].mean(0)
img.pixels = px.ravel()
img.pack()
nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
paso("color horneado")

bpy.data.objects.remove(alto_obj)
co = np.empty(len(bajo.data.vertices) * 3, np.float32); bajo.data.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
alto = co[:, 2].max() - co[:, 2].min()
franja = co[(co[:, 2] > co[:, 2].min() + alto * 0.25) & (co[:, 2] < co[:, 2].min() + alto * 0.4)]
cx, cy = franja[:, 0].mean(), franja[:, 1].mean()
r = np.sqrt((franja[:, 0] - cx) ** 2 + (franja[:, 1] - cy) ** 2) / alto
print("TRONCO radio p50 %.3f p90 %.3f" % (np.percentile(r, 50), np.percentile(r, 90)))
bajo.data.transform(Matrix.Scale(1 / alto, 4) @ Matrix.Translation(Vector((-cx, -cy, -co[:, 2].min()))))
bajo.data.update()
for x in list(bpy.data.objects):
    if x.type != 'MESH': bpy.data.objects.remove(x)
print("FINAL", bajo.name, "tris", tris(bajo))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True, export_yup=True)
paso("exportado")
