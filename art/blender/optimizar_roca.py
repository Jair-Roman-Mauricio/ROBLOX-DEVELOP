"""Convierte el peñasco con árboles de Sketchfab (stone_rockpart11.glb, ~840.000 triángulos y
texturas 4K) en un modelo que Roblox puede importar y repetir por la selva:

  Roca   ~3.500 triángulos   la piedra, con colisión
  Ramas  ~6.000 triángulos   troncos y raíces gruesas (las ramitas se descartan)
  Hojas  ~8.400 triángulos   una parte de las tarjetas de hoja, agrandadas; atlas 1024 con alfa

Texturas a 1024 como máximo (baúl: Textures Decals and Texture Memory). Cada malla queda muy
por debajo del límite de 20.000 triángulos del importador. El original no se guarda en el repo
(85 MB); la licencia del modelo hay que comprobarla en su página de Sketchfab antes de publicar.

Uso:
  Blender -b --factory-startup --python art/blender/optimizar_roca.py -- <original.glb> art/export/RocaSelva.glb
"""
import bpy, sys, bmesh
import numpy as np
a = sys.argv[sys.argv.index("--")+1:]
SRC, OUT = a[0], a[1]
T_ROCA, T_RAMAS = 3500, 6000  # triángulos finales
PRE_RAMAS = 13000  # caras de tronco que se conservan antes de reducir
P_HOJAS, ESCALA_HOJAS = 0.07, 1.9  # fracción de tarjetas de hoja que queda y cuánto se agrandan
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
objs = [o for o in bpy.data.objects if o.type == 'MESH']
# aplicar transformaciones del mundo
for o in objs:
    mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
def unir(lista, nombre):
    bpy.ops.object.select_all(action='DESELECT')
    for o in lista: o.select_set(True)
    bpy.context.view_layer.objects.active = lista[0]
    if len(lista) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nombre; o.data.name = nombre
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o
def tris(o): return sum(len(p.vertices)-2 for p in o.data.polygons)
def decimar(o, objetivo):
    bpy.context.view_layer.objects.active = o
    n = tris(o)
    if n <= objetivo: return
    m = o.modifiers.new("d", 'DECIMATE'); m.ratio = objetivo / n; m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)

g_roca = [o for o in objs if o.name.startswith("Rock")]
g_ramas = [o for o in objs if o.name.startswith("Branch")]
hojas_objs = [o for o in objs if o.name.startswith("Leaf")]
roca = unir(g_roca, "Roca")
ramas = unir(g_ramas, "Ramas")

# --- atlas de hojas 2x2 -------------------------------------------------------------------
mats = []
for o in hojas_objs:
    for s in o.material_slots:
        if s.material not in mats: mats.append(s.material)
def imagen_de(mat):
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image: return n.image
T = 512
atlas = np.zeros((T*2, T*2, 4), np.float32)
celda = {}
for i, mat in enumerate(mats):
    im = imagen_de(mat).copy(); im.scale(T, T)
    px = np.array(im.pixels[:], np.float32).reshape(T, T, 4)
    # el color de los píxeles transparentes era blanco: se rellena con el verde medio de la hoja
    # para que el filtrado no deje un halo claro, y el alfa se endurece como en el original
    opaco = px[..., 3] > 0.5
    if opaco.any(): px[~opaco, :3] = px[opaco][:, :3].mean(0)
    px[..., 3] = np.clip((px[..., 3] - 0.35) / 0.3, 0, 1)
    cx, cy = i % 2, i // 2
    atlas[cy*T:(cy+1)*T, cx*T:(cx+1)*T] = px
    celda[mat.name] = (cx * 0.5, cy * 0.5)
for o in hojas_objs:
    me = o.data
    uv = me.uv_layers[0].data
    for p in me.polygons:
        ox, oy = celda[o.material_slots[p.material_index].material.name]
        for li in p.loop_indices:
            u, v = uv[li].uv
            # margen de medio texel para que el filtrado no mezcle celdas vecinas
            u = min(max(u % 1.0 if not 0 <= u <= 1 else u, 0.004), 0.996); v = min(max(v % 1.0 if not 0 <= v <= 1 else v, 0.004), 0.996)
            uv[li].uv = (ox + u * 0.5, oy + v * 0.5)
hojas = unir(hojas_objs, "Hojas")
img_atlas = bpy.data.images.new("HojasAtlas", T*2, T*2, alpha=True)
img_atlas.pixels = atlas.ravel(); img_atlas.pack()
mh = bpy.data.materials.new("Hojas"); mh.use_nodes = True
nt = mh.node_tree; b = nt.nodes["Principled BSDF"]
tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = img_atlas
nt.links.new(tx.outputs["Color"], b.inputs["Base Color"]); nt.links.new(tx.outputs["Alpha"], b.inputs["Alpha"])
b.inputs["Roughness"].default_value = 0.8
mh.blend_method = 'CLIP' if hasattr(mh, "blend_method") else mh.blend_method
hojas.data.materials.clear(); hojas.data.materials.append(mh)

def islas(bm):
    bm.verts.ensure_lookup_table()
    visto = set(); res = []
    for v in bm.verts:
        if v.index in visto: continue
        pila = [v]; visto.add(v.index); vs = []
        while pila:
            x = pila.pop(); vs.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in visto: visto.add(y.index); pila.append(y)
        res.append(vs)
    return res
import random
random.seed(7)
# ramas: solo los troncos y ramas gruesas; las ramitas de 24 caras no se distinguen en juego
bm = bmesh.new(); bm.from_mesh(ramas.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
datos = []
for vs in islas(bm):
    co = np.array([w.co[:] for w in vs]); d = float(np.linalg.norm(co.max(0) - co.min(0)))
    datos.append((d, len({f.index for w in vs for f in w.link_faces}), vs))
datos.sort(key=lambda t: -t[0])
quitar, caras = [], 0
for d, nf, vs in datos:
    if caras + nf <= PRE_RAMAS and nf >= 60: caras += nf
    else: quitar.extend(vs)
bmesh.ops.delete(bm, geom=quitar, context='VERTS'); bm.to_mesh(ramas.data); bm.free()
# hojas: una parte de las tarjetas, agrandadas para que la copa siga pareciendo llena
bm = bmesh.new(); bm.from_mesh(hojas.data)
quitar = []
for vs in islas(bm):
    nf = len({f.index for w in vs for f in w.link_faces})
    if nf > 8 or random.random() < P_HOJAS:
        c = sum((w.co for w in vs), vs[0].co * 0) / len(vs)
        k = 1.0 if nf > 8 else ESCALA_HOJAS
        for w in vs: w.co = c + (w.co - c) * k
    else: quitar.extend(vs)
bmesh.ops.delete(bm, geom=quitar, context='VERTS'); bm.to_mesh(hojas.data); bm.free()

# --- reducir ------------------------------------------------------------------------------
bm = bmesh.new(); bm.from_mesh(roca.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(roca.data); bm.free()
decimar(roca, T_ROCA); decimar(ramas, T_RAMAS)
# solo queda un mapa UV por malla (Roblox usa el primero)
for o in (roca, ramas, hojas):
    while len(o.data.uv_layers) > 1: o.data.uv_layers.remove(o.data.uv_layers[1])
    for p in o.data.polygons: p.use_smooth = True
# texturas a 1024 como máximo
for im in bpy.data.images:
    if im.size[0] > 1024 or im.size[1] > 1024:
        f = 1024 / max(im.size); im.scale(max(1, int(im.size[0]*f)), max(1, int(im.size[1]*f))); im.pack()
# quitar vacíos
for o in list(bpy.data.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o)
# origen en el centro de la base de la piedra
from mathutils import Vector
co = np.array([v.co[:] for v in roca.data.vertices])
d = Vector((-(co[:, 0].max() + co[:, 0].min()) / 2, -(co[:, 1].max() + co[:, 1].min()) / 2, -co[:, 2].min()))
for o in (roca, ramas, hojas):
    o.data.transform(__import__("mathutils").Matrix.Translation(d))
for o in (roca, ramas, hojas):
    print("FINAL", o.name, "tris", tris(o), "dim", [round(x, 2) for x in o.dimensions])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True, export_yup=True, export_image_format='AUTO')
