"""Convierte la serpiente de la jungla (OBJ exportado por export_obj.py --serpent-only) en una
serpiente articulada para Roblox: el cuerpo se endereza a lo largo de su columna y se corta en
segmentos que el juego mueve uno detrás de otro.

  Cabeza      cabeza, mandíbula, garganta, colmillos, lengua, cuernos, babas y la vegetación
              de la cabeza, en una pieza rígida            -> Cabeza
  Ojos        malla aparte para que el juego la haga brillar  -> Ojos
  Cuerpo NN   tubo de escamas del segmento NN (su centro es el eje del segmento) -> CuerpoNN
  Lomo NN     árboles, rocas, raíces y hierba que crecen sobre ese segmento    -> LomoNN

Todo queda en línea recta: la cabeza mira a -Z de Roblox (+Y de Blender), arriba es +Y de Roblox.
Colores: una paleta de 16x16 en la que cada material ocupa una celda; las caras apuntan su UV
a la celda de su material (el importador de Roblox no siempre respeta colores de vértice).
Paleta oscurecida a propósito: la serpiente tiene que leerse como una silueta en la noche.

Uso:
  Blender -b --factory-startup --python art/blender/serpiente_por_segmentos.py -- \
      <serpiente_sola.obj> <salida.glb> [segmentos=24] [escala=3.5]
"""
import bpy, bmesh, sys, math, random
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

A = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = A[0], A[1]
NSEG = int(A[2]) if len(A) > 2 else 24
ESCALA = float(A[3]) if len(A) > 3 else 3.5
SOLAPE = 0.18  # unidades de Blender que cada tubo se mete en el vecino (tapa las juntas al curvarse)
TRIS_TUBO = 1600
TRIS_LOMO = 4200
TRIS_CABEZA = 14000
R = random.Random(7)

# columna de build_serpent.py (SERP_Spine): misma curva, mismos asas automáticas
H = Vector((-2.0, -4.0, 7.2))
D = Vector((-0.25, -1.0, -0.26)).normalized()
SPINE_PTS = [(40, 150, -0.3), (22, 128, -0.3), (32, 104, -0.3), (14, 84, -0.3), (-8, 66, -0.3),
             (-13, 46, -0.3), (-3, 31, -0.4), (3, 21, 0.2), (5.5, 14, 4.2), (4, 7.5, 8.2),
             (1.2, 2.5, 9.6), tuple(H - D * 3.5), tuple(H)]

# paleta (sRGB 0-255): oscura, verde ácido apagado en el musgo, ojos aparte
PALETA = {
    "Scales": (46, 36, 22), "BodyScales": (34, 26, 16), "Mouth": (70, 22, 18), "Throat": (14, 8, 4),
    "Fang": (170, 156, 110), "Tongue": (120, 20, 26), "Bark": (40, 28, 16), "Canopy": (30, 44, 14),
    "Leaf": (36, 52, 16), "Grass": (44, 58, 18), "Moss": (54, 70, 20), "Root": (58, 40, 20),
    "MudDrip": (30, 20, 10), "Water": (60, 66, 50), "Rock": (52, 46, 36), "EyeGlow": (220, 230, 90),
}
CELDAS = list(PALETA)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=SRC, forward_axis='NEGATIVE_Z', up_axis='Y')
objs = [o for o in bpy.data.objects if o.type == 'MESH']
print("IMPORTADOS", len(objs))

# ---------------------------------------------------------------- columna: polilínea y marcos
cu = bpy.data.curves.new("sp", 'CURVE'); cu.dimensions = '3D'; cu.resolution_u = 24
s = cu.splines.new('BEZIER'); s.bezier_points.add(len(SPINE_PTS) - 1)
for bp, p in zip(s.bezier_points, SPINE_PTS):
    bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
co = bpy.data.objects.new("sp", cu); bpy.context.scene.collection.objects.link(co)
bpy.context.view_layer.update()
me = co.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
P = np.array([v.co[:] for v in me.vertices])
# remuestrear cada 0.05 unidades
seg = np.linalg.norm(np.diff(P, axis=0), axis=1); acum = np.concatenate([[0], np.cumsum(seg)])
LARGO = acum[-1]
ss = np.arange(0, LARGO, 0.05)
P = np.stack([np.interp(ss, acum, P[:, k]) for k in range(3)], 1)
T = np.gradient(P, axis=0); T /= np.linalg.norm(T, axis=1, keepdims=True)
# marcos de rotación mínima; la normal inicial es el "arriba" del mundo proyectado
N = np.zeros_like(T)
n0 = np.array([0, 0, 1.0]) - T[0] * T[0][2]; N[0] = n0 / np.linalg.norm(n0)
for i in range(1, len(T)):
    n = N[i - 1] - T[i] * np.dot(N[i - 1], T[i]); N[i] = n / np.linalg.norm(n)
B = np.cross(T, N)  # derecha
print("COLUMNA largo", round(LARGO, 1), "muestras", len(P))
kd = KDTree(len(P))
for i, p in enumerate(P):
    kd.insert(p, i)
kd.balance()

def enderezar(V, idx=None):
    """V (n,3) en el mundo -> coordenadas rectas: X derecha, Y = s (hacia la cabeza), Z arriba."""
    if idx is None:
        idx = np.array([kd.find(v)[1] for v in V])
    d = V - P[idx]
    return np.stack([np.einsum('ij,ij->i', d, B[idx]), ss[idx], np.einsum('ij,ij->i', d, N[idx])], 1), idx

def rigido(V, i):
    d = V - P[i]
    return np.stack([d @ B[i], np.full(len(V), ss[i]) + d @ T[i], d @ N[i]], 1)

# ---------------------------------------------------------------- utilidades de malla
def datos(o):
    m = o.data
    V = np.array([v.co[:] for v in m.vertices]).reshape(-1, 3)
    # el OBJ llega con Y arriba (convención de Roblox): volver a Z arriba como en el .blend
    V = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)
    F = [list(p.vertices) for p in m.polygons]
    mats = [o.material_slots[p.material_index].material.name.replace("MAT_", "") if o.material_slots else "Scales"
            for p in m.polygons]
    return V, F, mats

def islas(nv, F):
    padre = np.arange(nv)
    def raiz(a):
        while padre[a] != a:
            padre[a] = padre[padre[a]]; a = padre[a]
        return a
    for f in F:
        r0 = raiz(f[0])
        for v in f[1:]:
            r = raiz(v)
            if r != r0:
                padre[r] = r0
    return np.array([raiz(v) for v in range(nv)])

piezas = {}  # nombre -> lista de (V, F, mats)
def poner(nombre, V, F, mats):
    piezas.setdefault(nombre, []).append((V, F, mats))

def tramo(sv):
    return int(np.clip((LARGO - sv) / LARGO * NSEG, 0, NSEG - 1)) + 1  # 1 = junto a la cabeza

# ---------------------------------------------------------------- reparto
FIN = len(P) - 1
for o in objs:
    nombre = o.name.split(".")[0]
    V, F, mats = datos(o)
    if not F:
        continue
    if nombre == "SERP_Eyes":
        poner("Ojos", rigido(V, FIN), F, mats)
    elif nombre.startswith("SERP_") and nombre not in ("SERP_Body", "SERP_Drips"):
        poner("Cabeza", rigido(V, FIN), F, mats)
    elif nombre.startswith("VEG_Head"):
        poner("Cabeza", rigido(V, FIN), F, mats)
    elif nombre == "SERP_Body":
        W, idx = enderezar(V)
        # cada cara va a su tramo; las que caen cerca de un corte van a los dos (solape)
        cs = np.array([W[f, 1].mean() for f in F])
        for k in range(1, NSEG + 1):
            s1 = LARGO - (k - 1) * LARGO / NSEG; s0 = LARGO - k * LARGO / NSEG
            sel = [i for i, c in enumerate(cs) if s0 - SOLAPE <= c <= s1 + SOLAPE]
            poner("Cuerpo%02d" % k, W, [F[i] for i in sel], [mats[i] for i in sel])
    else:
        # vegetación del lomo y babas: cada isla se mueve rígida con el punto de la columna
        # más cercano a su vértice más próximo al cuerpo (la base de la planta)
        isl = islas(len(V), F)
        idx_v = np.array([kd.find(v)[1] for v in V])
        dist = np.linalg.norm(V - P[idx_v], axis=1)
        grupos = {}
        for fi, f in enumerate(F):
            grupos.setdefault(isl[f[0]], []).append(fi)
        for r, caras in grupos.items():
            vs = sorted({v for fi in caras for v in F[fi]})
            base = vs[int(np.argmin(dist[vs]))]
            W = rigido(V, idx_v[base])
            k = tramo(ss[idx_v[base]])
            poner("Lomo%02d" % k, W, [F[fi] for fi in caras], [mats[fi] for fi in caras])
    print("REPARTIDO", nombre, len(F))

# ---------------------------------------------------------------- construir, aclarar y diezmar
img = bpy.data.images.new("Paleta", 16, 16)
px = np.zeros((16, 16, 4), np.float32)
def lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
for i, n in enumerate(CELDAS):
    x, y = (i % 8) * 2, (i // 8) * 2
    px[y:y + 2, x:x + 2, :3] = lin(np.array(PALETA[n], np.float32)); px[y:y + 2, x:x + 2, 3] = 1
img.pixels = px.ravel(); img.pack()
mat = bpy.data.materials.new("Paleta"); mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]; bsdf.inputs["Roughness"].default_value = 0.55
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = 'Closest'
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

def uv_de(nombre_mat):
    i = CELDAS.index(nombre_mat) if nombre_mat in CELDAS else 0
    return ((i % 8) * 2 + 1) / 16, ((i // 8) * 2 + 1) / 16

def objeto(nombre, partes, objetivo, aclarar):
    Vs, Fs, Ms, off = [], [], [], 0
    if aclarar:
        # quitar islas pequeñas (hierba, musgo) hasta acercarse al presupuesto; árboles y rocas se quedan
        todas = []
        for V, F, mats in partes:
            isl = islas(len(V), F) if F else []
            g = {}
            for fi, f in enumerate(F):
                g.setdefault(isl[f[0]], []).append(fi)
            for caras in g.values():
                todas.append((V, [F[i] for i in caras], [mats[i] for i in caras]))
        tris = sum(sum(len(f) - 2 for f in c[1]) for c in todas)
        todas.sort(key=lambda c: -len(c[1]))
        quedan, cuenta = [], 0
        for c in todas:
            t = sum(len(f) - 2 for f in c[1])
            if cuenta + t <= objetivo * 1.6 or len(c[1]) > 200:
                quedan.append(c); cuenta += t
        partes = quedan
    for V, F, mats in partes:
        usados = sorted({v for f in F for v in f}); mapa = {v: i + off for i, v in enumerate(usados)}
        Vs.append(V[usados]); Fs += [[mapa[v] for v in f] for f in F]; Ms += mats; off += len(usados)
    if not Fs:
        return None
    V = np.concatenate(Vs) * ESCALA
    m = bpy.data.meshes.new(nombre); m.from_pydata(V.tolist(), [], Fs); m.update()
    m.materials.append(mat)
    uv = m.uv_layers.new(name="UV")
    for p, mn in zip(m.polygons, Ms):
        u, v = uv_de(mn)
        for li in p.loop_indices:
            uv.data[li].uv = (u, v)
    o = bpy.data.objects.new(nombre, m); bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    for p in m.polygons:
        p.use_smooth = nombre.startswith("Cuerpo") or nombre == "Cabeza"
    t = sum(len(p.vertices) - 2 for p in m.polygons)
    if t > objetivo:
        d = o.modifiers.new("d", 'DECIMATE'); d.ratio = objetivo / t
        bpy.ops.object.modifier_apply(modifier="d")
    # origen: centro del eje del tramo para el tubo; para el resto, el del tubo vecino lo da el juego
    print("PIEZA", nombre, "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
    return o

hechos = []
for nombre in sorted(piezas):
    if nombre.startswith("Cuerpo"):
        objetivo, aclarar = TRIS_TUBO, False
    elif nombre.startswith("Lomo"):
        objetivo, aclarar = TRIS_LOMO, True
    elif nombre == "Cabeza":
        objetivo, aclarar = TRIS_CABEZA, True
    else:
        objetivo, aclarar = 3000, False
    o = objeto(nombre, piezas[nombre], objetivo, aclarar)
    if o:
        hechos.append(o)

# el origen de cada malla, en el centro de su caja (lo mismo que hace Roblox al importar)
for o in hechos:
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
for o in list(bpy.data.objects):
    if o not in hechos:
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_apply=True)
print("ESCRITO", OUT, "largo studs", round(LARGO * ESCALA, 1), "segmentos", NSEG)
