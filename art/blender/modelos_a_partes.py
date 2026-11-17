"""Convierte el peñasco (Sketchfab) y el árbol (Meshy) en DATOS para reconstruirlos con partes de
Roblox, sin subir ninguna malla: así cargan para cualquier cuenta.

  piedra y tronco  → triángulos de muy baja resolución con el color de la textura por cara;
                     el juego pone dos WedgeParts por triángulo (Modelos/Triangulos.luau)
  follaje          → esferas ajustadas a las masas de hojas (k-medias), con su color medio
  troncos del peñasco → segmentos (cilindros)

Salida: src/server/Modelos/Datos/ModelosSelva.luau. Coordenadas de Roblox (Y arriba), pie en el
origen. El peñasco y las rocas van en sus unidades originales; la ceiba, con altura 1.

Uso:
  Blender -b --factory-startup --python art/blender/modelos_a_partes.py -- <stone_rockpart11.glb> <art/export/ArbolSelva.glb> <salida.luau>
(ArbolSelva.glb es el árbol ya remallado y con el color horneado por optimizar_arbol.py.)
"""
import bpy, sys, bmesh
import numpy as np
a = sys.argv[sys.argv.index("--")+1:]
ROCA_SRC, ARBOL_SRC, OUT = a[0], a[1], a[2]
T_PENASCO, T_ROCA = 230, 44
K_HOJAS_PENASCO, K_HOJAS_CEIBA, N_TRONCOS = 34, 14, 14
T_CEIBA = 520
VOXEL_CEIBA = 0.022
rs = np.random.RandomState(7)

def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
def importar(ruta):
    bpy.ops.import_scene.gltf(filepath=ruta)
    objs = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in objs:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    return objs
def unir(lista, nombre):
    bpy.ops.object.select_all(action='DESELECT')
    for o in lista: o.select_set(True)
    bpy.context.view_layer.objects.active = lista[0]
    if len(lista) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = nombre
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o
def lim(o, que):
    c = np.array([v.co[:] for v in o.data.vertices]); print('LIM', que, len(c), np.round(c.min(0), 2), np.round(c.max(0), 2), flush=True)
def tris(o): return sum(len(p.vertices) - 2 for p in o.data.polygons)
def decimar(o, objetivo):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    # varias pasadas: con proporciones muy pequeñas una sola se queda corta
    for _ in range(6):
        n = tris(o)
        if n <= objetivo * 1.03: break
        m = o.modifiers.new("d", 'DECIMATE'); m.ratio = max(objetivo / n, 0.02); m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
    m = o.modifiers.new("t", 'TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=m.name)
def imagen_color(o):
    for s in o.material_slots:
        nt = s.material.node_tree
        b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        l = b.inputs["Base Color"].links
        if l and l[0].from_node.type == 'TEX_IMAGE': return l[0].from_node.image
def pixeles(img):
    w, h = img.size
    return np.array(img.pixels[:], np.float32).reshape(h, w, 4), w, h
def a_roblox(p): return (p[0], p[2], -p[1])

def triangulos(o, mover, escala=1.0):
    """vértices y triángulos con color por cara (media de 4 muestras de la textura)."""
    px, w, h = pixeles(imagen_color(o))
    me = o.data; uv = me.uv_layers[0].data
    vs = [a_roblox(((v.co[0] + mover[0]) * escala, (v.co[1] + mover[1]) * escala, (v.co[2] + mover[2]) * escala)) for v in me.vertices]
    ts = []
    for p in me.polygons:
        uvs = np.array([uv[li].uv[:] for li in p.loop_indices]); c = uvs.mean(0)
        col = np.zeros(3)
        for q in [c] + [(c + u) / 2 for u in uvs]:
            x = int(q[0] % 1.0 * (w - 1)); y = int(q[1] % 1.0 * (h - 1)); col += px[y, x, :3]
        col /= 4
        ts.append((p.vertices[0], p.vertices[1], p.vertices[2], col))
    return vs, ts

def kmedias(pts, pesos, k, vueltas=25):
    c = pts[rs.choice(len(pts), k, replace=False, p=pesos / pesos.sum())]
    for _ in range(vueltas):
        d = ((pts[:, None, :] - c[None, :, :]) ** 2).sum(2); g = d.argmin(1)
        for i in range(k):
            m = g == i
            if m.any(): c[i] = (pts[m] * pesos[m, None]).sum(0) / pesos[m].sum()
    return c, g

def islas(bm):
    bm.verts.ensure_lookup_table(); visto = set(); res = []
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

def fmt(x): return ("%.3f" % x).rstrip("0").rstrip(".") if abs(x) > 0.0005 else "0"
def luau_tri(vs, ts):
    v = ",".join(fmt(c) for p in vs for c in p)
    t = ",".join("%d,%d,%d,%d,%d,%d" % (i + 1, j + 1, k + 1, round(c[0] * 255), round(c[1] * 255), round(c[2] * 255)) for i, j, k, c in ts)
    return "v = {%s},\n\t\tt = {%s}," % (v, t)

salida = []
# ------------------------------------------------------------------------------- peñasco
limpiar(); objs = importar(ROCA_SRC)
g_roca = [o for o in objs if o.name.startswith("Rock")]
g_ramas = [o for o in objs if o.name.startswith("Branch")]
g_hojas = [o for o in objs if o.name.startswith("Leaf")]
roca = unir(g_roca, "Roca"); ramas = unir(g_ramas, "Ramas"); hojas = unir(g_hojas, "Hojas")
bm = bmesh.new(); bm.from_mesh(roca.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(roca.data); bm.free()
co = np.array([v.co[:] for v in roca.data.vertices])
mover = (-(co[:, 0].max() + co[:, 0].min()) / 2, -(co[:, 1].max() + co[:, 1].min()) / 2, -co[:, 2].min())
dim = co.max(0) - co.min(0)

# La piedra original es una lámina abierta con costuras y el reductor no baja de ~300
# triángulos. Se envuelve con una icoesfera ceñida a su superficie, y el color de cada cara se
# toma de las caras del original más cercanas.
from mathutils import kdtree
px, w, h = pixeles(imagen_color(roca))
uv = roca.data.uv_layers[0].data
kd = kdtree.KDTree(len(roca.data.polygons)); colores = []
for i, p in enumerate(roca.data.polygons):
    c = np.mean([uv[li].uv[:] for li in p.loop_indices], 0)
    colores.append(px[int(c[1] % 1.0 * (h - 1)), int(c[0] % 1.0 * (w - 1)), :3])
    kd.insert(p.center, i)
kd.balance(); colores = np.array(colores)

from mathutils.bvhtree import BVHTree
from mathutils import Vector
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(roca, dg)

def piedra(nx, ny, escala):
    # mapa de alturas: un rayo hacia abajo por cada nudo de una rejilla; conserva los picos.
    # Donde el rayo no toca piedra el nudo baja al suelo y forma la falda.
    xs = np.linspace(co[:, 0].min(), co[:, 0].max(), nx + 1); ys = np.linspace(co[:, 1].min(), co[:, 1].max(), ny + 1)
    zmin = co[:, 2].min()
    alt = np.full((nx + 1, ny + 1), np.nan)
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            hit = bvh.ray_cast(Vector((x, y, co[:, 2].max() + 5)), Vector((0, 0, -1)))
            if hit[0] is not None: alt[i, j] = hit[0].z
    vs, idx, ts = [], {}, []
    def vert(i, j):
        if (i, j) not in idx:
            z = zmin if np.isnan(alt[i, j]) else alt[i, j]
            idx[(i, j)] = len(vs)
            vs.append(a_roblox(((xs[i] + mover[0]) * escala, (ys[j] + mover[1]) * escala, (z + mover[2]) * escala)))
        return idx[(i, j)]
    for i in range(nx):
        for j in range(ny):
            esq = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(np.isnan(alt[e]) for e in esq): continue
            # diagonal alternada para que la malla no tenga veta
            tri = [(esq[0], esq[1], esq[2]), (esq[0], esq[2], esq[3])] if (i + j) % 2 == 0 else [(esq[0], esq[1], esq[3]), (esq[1], esq[2], esq[3])]
            for t3 in tri:
                pts = [Vector((xs[e[0]], ys[e[1]], zmin if np.isnan(alt[e]) else alt[e])) for e in t3]
                cerca = kd.find_n((pts[0] + pts[1] + pts[2]) / 3, 24)
                ts.append((vert(*t3[0]), vert(*t3[1]), vert(*t3[2]), colores[[q for _, q, _ in cerca]].mean(0)))
    return vs, ts

k = 1 / max(dim[0], dim[1])  # roca suelta: lado mayor en planta = 1
sv, st = piedra(5, 7, k)
print("ROCA suelta tris", len(st))
vs, ts = piedra(10, 13, 1.0)
print("PENASCO tris", len(ts), "dim", dim)

# follaje del peñasco: centro de cada tarjeta de hoja → k-medias
bm = bmesh.new(); bm.from_mesh(hojas.data)
cent = np.array([np.mean([w.co[:] for w in isl], 0) for isl in islas(bm)]); bm.free()
c, g = kmedias(cent, np.ones(len(cent)), K_HOJAS_PENASCO)
esferas = []
for i in range(len(c)):
    m = g == i
    if m.sum() < 20: continue
    r = np.sqrt(((cent[m] - c[i]) ** 2).sum(1).mean()) * 0.62
    p = a_roblox(c[i] + np.array(mover))
    esferas.append((p[0], p[1], p[2], r))
# troncos: las ramas más largas, como segmentos
bm = bmesh.new(); bm.from_mesh(ramas.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
seg = []
for isl in islas(bm):
    if len(isl) < 40: continue
    p = np.array([w.co[:] for w in isl]); m = p.mean(0)
    if p[:, 2].min() + mover[2] < 1.0: continue  # raíces que cuelgan por debajo de la piedra
    u, s, vt = np.linalg.svd(p - m, full_matrices=False); eje = vt[0]; t = (p - m) @ eje
    radio = np.sqrt((((p - m) - np.outer(t, eje)) ** 2).sum(1).mean())
    seg.append((t.max() - t.min(), m + eje * t.min(), m + eje * t.max(), radio))
bm.free(); seg.sort(key=lambda s: -s[0])
troncos = []
for largo, p1, p2, radio in seg[:N_TRONCOS]:
    q1 = a_roblox(p1 + np.array(mover)); q2 = a_roblox(p2 + np.array(mover))
    troncos.append(q1 + q2 + (float(np.clip(radio * 1.1, 0.15, 0.45)),))
salida.append("\tPenasco = {\n\t\tancho = %s,\n\t\talto = %s,\n\t\t%s\n\t\thojas = {%s},\n\t\ttroncos = {%s},\n\t},"
    % (fmt(max(dim[0], dim[1])), fmt(dim[2]), luau_tri(vs, ts), ",".join(fmt(x) for e in esferas for x in e), ",".join(fmt(x) for t in troncos for x in t)))
salida.append("\tRoca = {\n\t\talto = %s,\n\t\t%s\n\t}," % (fmt(dim[2] * k), luau_tri(sv, st)))

# --------------------------------------------------------------------------------- ceiba
limpiar(); arbol = unir(importar(ARBOL_SRC), "Arbol")
lim(arbol, "arbol")
px, w, h = pixeles(imagen_color(arbol))
me = arbol.data; uv = me.uv_layers[0].data
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv.active
es_hoja = []; cen = []; area = []; col = []
for f in bm.faces:
    c = np.mean([l[uvl].uv[:] for l in f.loops], 0)
    rgb = px[int(c[1] % 1.0 * (h - 1)), int(c[0] % 1.0 * (w - 1)), :3]
    p = f.calc_center_median(); rad = (p.x ** 2 + p.y ** 2) ** 0.5
    verde = rgb[1] > rgb[0] * 1.08 and rgb[1] > rgb[2] * 1.25
    hoja = p.z > 0.36 and (verde or rad > 0.14)
    es_hoja.append(hoja); cen.append(p[:]); area.append(f.calc_area()); col.append(rgb)
es_hoja = np.array(es_hoja); cen = np.array(cen); area = np.array(area); col = np.array(col)
print("CEIBA caras hoja", es_hoja.sum(), "tronco", (~es_hoja).sum())
bm.free()
kdc = kdtree.KDTree(len(cen))
for i, p in enumerate(cen): kdc.insert(p, i)
kdc.balance()

# Todo el árbol como una sola piel cerrada y gruesa (vóxeles grandes funden las hojas en masas),
# sin fragmentos sueltos y reducida. El color de cada cara viene de las caras cercanas del
# árbol detallado: verde en la copa y el musgo, pardo en tronco y raíces.
bpy.ops.object.select_all(action='DESELECT'); arbol.select_set(True); bpy.context.view_layer.objects.active = arbol
bpy.ops.object.duplicate(); d = bpy.context.view_layer.objects.active
m = d.modifiers.new("r", 'REMESH'); m.mode = 'VOXEL'; m.voxel_size = VOXEL_CEIBA; m.adaptivity = 0
bpy.ops.object.modifier_apply(modifier=m.name)
b2 = bmesh.new(); b2.from_mesh(d.data)
grupos = islas(b2); total = sum(len(g) for g in grupos)
bmesh.ops.delete(b2, geom=[v for g in grupos if len(g) < total * 0.02 for v in g], context='VERTS')
b2.to_mesh(d.data); b2.free()
lim(d, 'ceiba voxel')
decimar(d, T_CEIBA); lim(d, 'ceiba reducida')
vs = [a_roblox(v.co[:]) for v in d.data.vertices]
ts = [(p.vertices[0], p.vertices[1], p.vertices[2], col[[i for _, i, _ in kdc.find_n(p.center, 16)]].mean(0)) for p in d.data.polygons]
bpy.data.objects.remove(d)
c, g = kmedias(cen[es_hoja], area[es_hoja], K_HOJAS_CEIBA)
hc, ha, hcol = cen[es_hoja], area[es_hoja], col[es_hoja]
esferas = []
for i in range(len(c)):
    m = g == i
    if not m.any(): continue
    r = np.sqrt((((hc[m] - c[i]) ** 2).sum(1) * ha[m]).sum() / ha[m].sum()) * 0.8
    rgb = (hcol[m] * ha[m, None]).sum(0) / ha[m].sum() * 0.9  # relleno interior, algo más oscuro
    p = a_roblox(c[i])
    esferas.append((p[0], p[1], p[2], r, rgb[0] * 255, rgb[1] * 255, rgb[2] * 255))
print("CEIBA tris", len(ts), "esferas", len(esferas))
salida.append("\tCeiba = {\n\t\t%s\n\t\thojas = {%s},\n\t}," % (luau_tri(vs, ts), ",".join(fmt(x) for e in esferas for x in e)))

open(OUT, "w").write("""--!strict
-- GENERADO por art/blender/modelos_a_partes.py: no editar a mano.
-- Geometría de baja resolución del peñasco, las rocas sueltas y la ceiba para reconstruirlos con
-- partes (Modelos/Triangulos). v = x,y,z por vértice; t = i,j,k,r,g,b por triángulo;
-- hojas = x,y,z,radio[,r,g,b] por esfera; troncos = x1,y1,z1,x2,y2,z2,radio por segmento.
return {
""" + "\n".join(salida) + "\n}\n")
print("ESCRITO", OUT)
