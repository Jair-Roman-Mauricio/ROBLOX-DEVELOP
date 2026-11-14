"""Helicóptero de transporte AMZ-07 (exterior + interior visible) para la intro de Selva.

Sigue el baúl: 14 Hard-Surface Modeling (mid-poly con biseles y normales limpias), 45 Procedural
Blender Assets (bmesh, sin bpy.ops, rutas absolutas, una semilla) y Exporting and Validating Models
for Roblox (1 unidad = 1 stud, transformaciones aplicadas, una malla por pieza móvil, < 20k tris,
un material por malla, nombres [A-Za-z0-9_]).

Se modela en coordenadas de Roblox (x = estribor, y = arriba, z = hacia la cola; morro en -Z) y una
sola función T() pasa a Blender (morro en -Y, estribor en -X), que es el "frente" del importador.

Piezas (cada una un objeto, mismo origen = punto bajo el centro del helicóptero en el suelo):
  Casco      fuselaje con hueco real de puerta y de rampa, pared con grosor e interior oliva
  Vidrios    parabrisas, ventanas de cabina y cristales de ojos de buey (material Vidrio)
  Puerta     hoja corrediza de estribor (se desliza +Z hacia la cola, PUERTA_RECORRIDO studs)
  Rampa      rampa trasera (bisagra en RAMPA_BISAGRA, eje X)
  Rotor      rotor principal de 5 palas (eje vertical en ROTOR_EJE)
  RotorCola  rotor de cola de 4 palas (eje X en COLA_EJE)
  Motores    turbinas, carenados, escapes, mástil
  Tren       ruedas, patas y sponsons
  Detalles   riel de la puerta, antenas, luces, rejillas, ojos de buey, matrícula
  Interior   bodega (suelo, asientos de lona, cajas, mamparo) y cabina (asientos, panel)

blender -b --factory-startup --python art/blender/build_helicoptero.py
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

AQUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(AQUI, "out"); os.makedirs(OUT, exist_ok=True)
EXPORT = os.path.join(os.path.dirname(AQUI), "export"); os.makedirs(EXPORT, exist_ok=True)
random.seed(707)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# medidas que también usa el código de Roblox (coordenadas de Roblox relativas al pivote)
PUERTA_Z = (-5.6, -1.4)          # hueco de la puerta, a lo largo
PUERTA_F = (0.137, 0.885)        # hueco de la puerta, fracción de alto del casco (y 2.5 .. 7.7)
PUERTA_RECORRIDO = 4.5
RAMPA_Z = 5.2
ROTOR_EJE = (0.0, 11.75, -0.6)
COLA_EJE = (0.62, 10.9, 23.7)

def T(p):  # Roblox -> Blender
    return Vector((-p[0], p[2], p[1]))

# ---------- paleta (un material con textura de colores planos) ----------
PALETA = {
    "blanco": "E9E7DF", "naranja": "E0682A", "turquesa": "1C8C94", "gris": "50565A", "grisclaro": "8E9496",
    "negro": "1B1D1F", "amarillo": "F0C228", "cromo": "B8BBB8", "rojo": "D8322A", "verde": "36C46A",
    "oliva": "4E5638", "olivaosc": "353B27", "lona": "9A2E26", "suelo": "3C3F3E", "caja": "6B5A3A",
    "pantalla": "2E5A3E", "ambar": "8A6428", "piel": "2B2E30", "goma": "141516", "faro": "FFF2C8",
}
NOMBRES = list(PALETA)
CELDA = 8
def srgb(h): return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
img = bpy.data.images.new("PaletaHelicoptero", CELDA * len(NOMBRES), CELDA, alpha=False)
px = []
for _y in range(CELDA):
    for n in NOMBRES:
        px += (srgb(PALETA[n]) + [1.0]) * CELDA
img.pixels = px
img.filepath_raw = os.path.join(EXPORT, "PaletaHelicoptero.png"); img.file_format = "PNG"; img.save()

def material_paleta():
    m = bpy.data.materials.new("Paleta"); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; t.interpolation = "Closest"
    nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.5; p.inputs["Metallic"].default_value = 0.0
    return m
def material_vidrio():
    m = bpy.data.materials.new("Vidrio"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.02, 0.05, 0.07, 1); p.inputs["Roughness"].default_value = 0.04
    p.inputs["Alpha"].default_value = 0.42
    try: m.surface_render_method = "BLENDED"
    except Exception: pass
    return m
MAT_PALETA, MAT_VIDRIO = material_paleta(), material_vidrio()
def uv_de(col):
    i = NOMBRES.index(col)
    return ((i + 0.5) / len(NOMBRES), 0.5)

# ---------- acumulador de malla ----------
class Malla:
    def __init__(self, nombre, mat=None):
        self.nombre, self.mat = nombre, mat or MAT_PALETA
        self.v, self.f, self.c = [], [], []
    def bm(self, bm, col):
        """Añade un bmesh (en coords de Roblox). col: str o función(cara)->str."""
        base = len(self.v)
        self.v += [vt.co.copy() for vt in bm.verts]
        bm.verts.index_update()
        for fc in bm.faces:
            self.f.append([base + vt.index for vt in fc.verts])
            self.c.append(col(fc) if callable(col) else col)
        bm.free()
    def objeto(self, angulo=34):
        me = bpy.data.meshes.new(self.nombre)
        me.from_pydata([T(p) for p in self.v], [], self.f)
        me.update()
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        uv = bm.loops.layers.uv.new("UVMap")
        bm.faces.ensure_lookup_table()
        for fc, col in zip(bm.faces, self.c):
            u = uv_de(col)
            for lp in fc.loops: lp[uv].uv = u
            fc.smooth = True
        lim = math.radians(angulo)
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > lim: e.smooth = False
        bm.to_mesh(me); bm.free()
        me.materials.append(self.mat)
        o = bpy.data.objects.new(self.nombre, me); scene.collection.objects.link(o)
        return o

# ---------- primitivas (coords de Roblox) ----------
def orientar(bm, rot, pos):
    bmesh.ops.transform(bm, matrix=rot.to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(pos), verts=bm.verts)

def biselar(bm, b, seg=2):
    if b > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=b, segments=seg, profile=0.5,
                        affect="EDGES", clamp_overlap=True)

def caja(M, c, s, col, b=0.06, rot=(0, 0, 0), seg=2):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=Vector(s), verts=bm.verts)
    biselar(bm, min(b, min(s) * 0.45), seg)
    r = Matrix.Rotation(math.radians(rot[1]), 3, "Y") @ Matrix.Rotation(math.radians(rot[0]), 3, "X") @ Matrix.Rotation(math.radians(rot[2]), 3, "Z")
    orientar(bm, r, c); M.bm(bm, col)

def torno(M, a, b, perfil, col, seg=16, tapa0=True, tapa1=True, escala=(1, 1)):
    """Sólido de revolución de a hacia b. perfil = [(radio, t 0..1)]."""
    a, b = Vector(a), Vector(b); eje = b - a; L = eje.length
    rot = Vector((0, 0, 1)).rotation_difference(eje.normalized()).to_matrix()
    bm = bmesh.new(); anillos = []
    for r, t in perfil:
        anillo = []
        for k in range(seg):
            ang = 2 * math.pi * k / seg
            anillo.append(bm.verts.new((r * math.cos(ang) * escala[0], r * math.sin(ang) * escala[1], t * L)))
        anillos.append(anillo)
    for i in range(len(anillos) - 1):
        for k in range(seg):
            q = (anillos[i][k], anillos[i][(k + 1) % seg], anillos[i + 1][(k + 1) % seg], anillos[i + 1][k])
            bm.faces.new(q)
    if tapa0 and perfil[0][0] > 0: bm.faces.new(list(reversed(anillos[0])))
    if tapa1 and perfil[-1][0] > 0: bm.faces.new(anillos[-1])
    orientar(bm, rot, a); M.bm(bm, col)

def cil(M, a, b, r, col, seg=12, r2=None):
    torno(M, a, b, [(r, 0), (r if r2 is None else r2, 1)], col, seg)

def ovoide(M, c, rad, col, u=20, v=12, rot=None):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1)
    bmesh.ops.scale(bm, vec=Vector(rad), verts=bm.verts)
    orientar(bm, rot or Matrix.Identity(3), c); M.bm(bm, col)

def placa(M, pts_zy, x0, x1, col, b=0.05):
    """Prisma de un polígono en el plano ZY extruido entre x0 y x1 (aletas, deriva)."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for z, y in pts_zy]
    f = bm.faces.new(a)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=Vector((x1 - x0, 0, 0)), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    biselar(bm, b, 1); M.bm(bm, col)

# ---------- casco: loft de secciones superelípticas ----------
# estaciones clave (z, semiancho, y abajo, y arriba)
CLAVES = [(-14.3, 0.3, 4.0, 4.6), (-13.9, 1.25, 3.05, 5.2), (-13.2, 2.3, 2.35, 6.05), (-12.1, 3.1, 1.95, 7.0),
          (-10.6, 3.6, 1.72, 7.85), (-8.6, 3.82, 1.58, 8.35), (-6.6, 3.86, 1.55, 8.5), (4.6, 3.86, 1.55, 8.5),
          (5.6, 3.78, 1.95, 8.48), (6.8, 3.55, 2.95, 8.42), (8.0, 3.15, 4.15, 8.3), (9.1, 2.55, 5.3, 8.12),
          (9.8, 1.9, 6.0, 7.95)]
def seccion(z):
    for (z0, *a), (z1, *b) in zip(CLAVES, CLAVES[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0); t = t * t * (3 - 2 * t)
            return [p + (q - p) * t for p, q in zip(a, b)]
    return list(CLAVES[0][1:] if z < CLAVES[0][0] else CLAVES[-1][1:])
N_SUPER = 2.9
# fracciones de alto (abajo -> arriba) con bordes exactos de franjas, puerta y parabrisas
FR = [0.0, 0.025, 0.06, 0.1, 0.137, 0.2, 0.27, 0.338, 0.417, 0.5, 0.58, 0.66, 0.74, 0.81, 0.885, 0.93, 0.965, 0.99, 1.0]
def punto(z, f, lado=1, sec=None):
    w, yb, yt = sec or seccion(z)
    s = 2 * f - 1
    sn = math.copysign(abs(s) ** (N_SUPER / 2), s)
    cs = max(0.0, 1 - sn * sn) ** 0.5
    return Vector((lado * w * cs ** (2 / N_SUPER), yb + (yt - yb) * f, z))
def normal_casco(z, f, lado=1):
    a, b = punto(z, f - 0.01, lado), punto(z, f + 0.01, lado)
    c, d = punto(z - 0.05, f, lado), punto(z + 0.05, f, lado)
    n = (b - a).cross(d - c) * lado
    return n.normalized() if n.x * lado > 0 else -n.normalized()

ZS = sorted(set([round(-14.3 + 0.35 * i, 3) for i in range(6)] + [round(-12.2 + 0.6 * i, 3) for i in range(7)]
                + [-8.6, -7.6, -6.6] + list(PUERTA_Z) + [-4.5, -3.5, -2.5]
                + [round(-0.4 + 1.0 * i, 3) for i in range(6)] + [RAMPA_Z, 6.0, 6.8, 7.4, 8.0, 8.6, 9.1, 9.5, 9.8]))
ANILLO = [(f, 1) for f in FR] + [(f, -1) for f in reversed(FR[1:-1])]

def es_puerta(z, f, lado): return lado > 0 and PUERTA_Z[0] <= z <= PUERTA_Z[1] and PUERTA_F[0] <= f <= PUERTA_F[1]
def es_vidrio(z, f, lado):
    if z <= -10.65 and 0.5 <= f <= 0.885: return True                    # parabrisas
    if -10.65 <= z <= -8.6 and 0.5 <= f <= 0.81: return True             # ventanas laterales de cabina
    return False
def es_rampa(z, f, lado): return z >= RAMPA_Z and f <= 0.27
def color_casco(f):
    return "naranja" if f < 0.338 else ("turquesa" if f < 0.417 else "blanco")

def casco():
    bm = bmesh.new(); filas = []
    for z in ZS:
        sec = seccion(z)
        filas.append([bm.verts.new(punto(z, f, l, sec)) for f, l in ANILLO])
    n = len(ANILLO); quitar = {"puerta": [], "vidrio": [], "rampa": []}; info = {}
    for i in range(len(ZS) - 1):
        for k in range(n):
            q = [filas[i][k], filas[i + 1][k], filas[i + 1][(k + 1) % n], filas[i][(k + 1) % n]]
            fc = bm.faces.new(q)
            zc = (ZS[i] + ZS[i + 1]) / 2
            f0, l0 = ANILLO[k]; f1, l1 = ANILLO[(k + 1) % n]
            fc_ = (f0 + f1) / 2; lado = l0 if f0 not in (0.0, 1.0) else l1
            info[fc] = (zc, fc_, lado)
            if es_puerta(zc, fc_, lado): quitar["puerta"].append(fc)
            elif es_vidrio(zc, fc_, lado): quitar["vidrio"].append(fc)
            elif es_rampa(zc, fc_, lado): quitar["rampa"].append(fc)
    # tapas: morro (abanico) y trasera (por encima de la rampa)
    for fila, z, rev in ((filas[0], ZS[0], True), (filas[-1], ZS[-1], False)):
        c = bm.verts.new(Vector((0, sum(v.co.y for v in fila) / len(fila), z)))
        for k in range(n):
            tri = [fila[k], fila[(k + 1) % n], c]
            fc = bm.faces.new(list(reversed(tri)) if rev else tri)
            info[fc] = (z, 0.5, 1)
            if not rev and fila[k].co.y < 6.9 and fila[(k + 1) % n].co.y < 6.9: quitar["rampa"].append(fc)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, quitar, info

def extraer(bm, caras, info):
    """Copia unas caras de bm a un bmesh nuevo (con su info) y las borra de bm."""
    nb = bmesh.new(); mapa = {}; ninfo = {}
    for fc in caras:
        vs = []
        for v in fc.verts:
            if v not in mapa: mapa[v] = nb.verts.new(v.co)
            vs.append(mapa[v])
        ninfo[nb.faces.new(vs)] = info[fc]
    bmesh.ops.delete(bm, geom=caras, context="FACES_ONLY")
    return nb, ninfo

def engrosar(bm, info, grosor, col_ext, col_int, col_canto):
    """Da grosor hacia dentro y colorea: exterior por franjas, interior oliva, cantos gris."""
    externas = set(bm.faces)
    for fc in list(bm.faces):
        z, f, l = info.get(fc, (0, 0.5, 1)); fc.normal_update()
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=grosor)
    def col(fc):
        if fc in externas: return col_ext(info.get(fc, (0, 0.5, 1)))
        fc.normal_update(); cen = fc.calc_center_median()
        eje = Vector((0, 5.0, cen.z)); radial = (cen - eje); radial.z = 0
        return col_int if fc.normal.dot(radial) < -0.2 * radial.length else col_canto
    return col

bm, quitar, info = casco()
bm_puerta, info_puerta = extraer(bm, quitar["puerta"], info)
bm_vidrio, _ = extraer(bm, quitar["vidrio"], info)
bm_rampa, info_rampa = extraer(bm, quitar["rampa"], info)

CASCO = Malla("Casco")
CASCO.bm(bm, engrosar(bm, info, 0.16, lambda i: color_casco(i[1]), "oliva", "gris"))

VIDRIOS = Malla("Vidrios", MAT_VIDRIO)
VIDRIOS.bm(bm_vidrio, "negro")

# puerta: la pieza recortada, separada un poco hacia fuera, con grosor
PUERTA = Malla("Puerta")
for v in bm_puerta.verts: v.co.x += 0.09
bmesh.ops.recalc_face_normals(bm_puerta, faces=bm_puerta.faces)
for fc in bm_puerta.faces:
    fc.normal_update()
    if fc.normal.x < 0: fc.normal_flip()
PUERTA.bm(bm_puerta, engrosar(bm_puerta, info_puerta, 0.14, lambda i: color_casco(i[1]), "oliva", "gris"))
zc_p = (PUERTA_Z[0] + PUERTA_Z[1]) / 2
# marco, manilla y ojo de buey de la puerta
for f, z0, z1 in ((PUERTA_F[0] + 0.012, PUERTA_Z[0], PUERTA_Z[1]), (PUERTA_F[1] - 0.012, PUERTA_Z[0], PUERTA_Z[1])):
    p = punto(zc_p, f); n = normal_casco(zc_p, f)
    caja(PUERTA, p + n * 0.2, (0.08, 0.12, z1 - z0 - 0.1), "gris", 0.03)
for z in (PUERTA_Z[0] + 0.07, PUERTA_Z[1] - 0.07):
    for f in (0.2, 0.4, 0.6, 0.8):
        pass
caja(PUERTA, punto(PUERTA_Z[1] - 0.6, 0.45) + Vector((0.25, 0, 0)), (0.12, 0.85, 0.22), "cromo", 0.05)
caja(PUERTA, punto(PUERTA_Z[1] - 0.6, 0.45) + Vector((0.2, 0, 0)), (0.06, 1.05, 0.4), "gris", 0.03)

# rampa: la pieza inferior trasera, cerrada
RAMPA = Malla("Rampa")
RAMPA.bm(bm_rampa, engrosar(bm_rampa, info_rampa, 0.16, lambda i: "naranja", "suelo", "gris"))
RAMPA_BISAGRA = (0.0, seccion(RAMPA_Z)[1] + 0.1, RAMPA_Z)

# ---------- ojos de buey ----------
DET = Malla("Detalles")
def ojo_de_buey(M_aro, z, f, lado, r=0.62, en_puerta=False, M_vidrio=None):
    p = punto(z, f, lado) + Vector((0.09 * lado if en_puerta else 0, 0, 0)); n = normal_casco(z, f, lado)
    a = p - n * 0.05; b = p + n * (0.24 if en_puerta else 0.16)
    torno(M_aro, a, b, [(r, 0), (r + 0.14, 0.15), (r + 0.14, 0.75), (r - 0.02, 1)], "gris", 20, False, False)
    torno(M_aro, a + n * 0.05, b - n * 0.04, [(r + 0.01, 0), (r + 0.01, 1)], "negro", 20, True, True)
    torno(M_vidrio or VIDRIOS, b - n * 0.03, b - n * 0.02, [(r - 0.02, 0), (r - 0.02, 1)], "negro", 20, True, True)
for z in (0.8, 2.9):
    ojo_de_buey(DET, z, 0.66, 1)
VIDRIO_PUERTA = Malla("VidrioPuerta", MAT_VIDRIO)
ojo_de_buey(PUERTA, zc_p, 0.66, 1, en_puerta=True, M_vidrio=VIDRIO_PUERTA)
for z in (-6.0, -3.8, -1.6, 0.6, 2.8):
    ojo_de_buey(DET, z, 0.66, -1)

# riel de la puerta con soportes
y_riel = punto(0, 0.915)
x_riel = y_riel.x + 0.34
cil(DET, (x_riel, y_riel.y, PUERTA_Z[0] - 0.4), (x_riel, y_riel.y, PUERTA_Z[1] + PUERTA_RECORRIDO + 0.4), 0.08, "cromo", 10)
for z in (PUERTA_Z[0] - 0.2, zc_p + 2.4, PUERTA_Z[1] + PUERTA_RECORRIDO + 0.2):
    caja(DET, (x_riel - 0.18, y_riel.y, z), (0.42, 0.14, 0.22), "gris", 0.04)
y_rb = punto(0, 0.1)
caja(DET, (y_rb.x + 0.12, y_rb.y, (PUERTA_Z[0] + PUERTA_Z[1] + PUERTA_RECORRIDO) / 2), (0.14, 0.1, PUERTA_Z[1] - PUERTA_Z[0] + PUERTA_RECORRIDO), "gris", 0.03)

# paneles: líneas de juntas sutiles (tiras finas apenas levantadas) a lo largo del casco
for z in (-8.6, -6.6, 4.6):
    for lado in (1, -1):
        for k in range(len(FR) - 1):
            f0, f1 = FR[k], FR[k + 1]
            if lado > 0 and PUERTA_Z[0] <= z <= PUERTA_Z[1]: continue
            if f0 < 0.03 or f1 > 0.97: continue
            if z <= -8.6 and f1 > 0.5: continue
            a, b = punto(z, f0, lado), punto(z, f1, lado)
            n = normal_casco(z, (f0 + f1) / 2, lado)
            d = b - a
            caja(DET, (a + b) / 2 + n * 0.015, (0.05, d.length + 0.01, 0.05), "grisclaro", 0,
                 rot=(0, 0, math.degrees(math.atan2(-d.x, d.y))))

# parabrisas: montantes
for z, f0, f1 in ((-10.65, 0.5, 0.885), (-8.6, 0.5, 0.81)):
    for lado in (1, -1):
        a, b = punto(z, f0, lado), punto(z, f1, lado); d = b - a; n = normal_casco(z, (f0 + f1) / 2, lado)
        caja(DET, (a + b) / 2 + n * 0.04, (0.16, d.length, 0.16), "blanco", 0.05,
             rot=(0, 0, math.degrees(math.atan2(-d.x, d.y))))
# montante central y limpiaparabrisas
cil(DET, punto(-14.0, 0.62, 1) * Vector((0, 1, 1)) + Vector((0, 0, 0.1)), punto(-11.2, 0.9, 1) * Vector((0, 1, 1)) + Vector((0, 0.08, 0)), 0.11, "blanco", 8)
for lado in (1, -1):
    a = punto(-12.9, 0.52, lado) + normal_casco(-12.9, 0.52, lado) * 0.08
    cil(DET, a, a + Vector((-0.5 * lado, 1.1, -0.15)), 0.035, "negro", 6)

# rejillas y escotillas en el lomo
for lado in (1, -1):
    for z in (-6.2, 2.6):
        p = punto(z, 0.93, lado); n = normal_casco(z, 0.93, lado)
        caja(DET, p + n * 0.04, (0.06, 0.55, 1.1), "negro", 0.02, rot=(0, 0, -lado * 50))
    p = punto(-4.0, 0.25, lado); n = normal_casco(-4.0, 0.25, lado)
    if lado < 0: caja(DET, p + n * 0.03, (0.05, 0.5, 0.7), "gris", 0.02)

# luces de navegación, baliza y faro
LUCES = []
for lado, col in ((1, "verde"), (-1, "rojo")):
    p = punto(-9.4, 0.3, lado) + normal_casco(-9.4, 0.3, lado) * 0.1
    ovoide(DET, p, (0.14, 0.14, 0.22), col, 10, 6); LUCES.append((col, p))
ovoide(DET, (0, 1.6, -9.6), (0.3, 0.18, 0.3), "faro", 12, 6); LUCES.append(("faro", Vector((0, 1.45, -9.6))))
caja(DET, (0, 1.7, -9.6), (0.75, 0.16, 0.75), "gris", 0.05)

# antenas
for p, h in (((0.0, 8.5, -7.8), 1.1), ((0.9, 8.45, 3.6), 0.9), ((-0.9, 8.45, 4.2), 0.7)):
    cil(DET, p, (p[0], p[1] + h, p[2] + 0.25), 0.04, "negro", 6)
    cil(DET, p, (p[0], p[1] + 0.12, p[2]), 0.12, "gris", 8)
for lado in (1, -1):
    a = (lado * 0.6, 1.65, -11.3)
    cil(DET, a, (lado * 0.6, 1.15, -10.6), 0.04, "negro", 6)

# ---------- motores, carenado y mástil ----------
MOT = Malla("Motores")
caja(MOT, (0, 8.95, -2.0), (4.0, 1.3, 11.4), "blanco", 0.55, seg=3)
ovoide(MOT, (0, 8.75, 5.3), (1.7, 1.05, 4.2), "blanco", 20, 12)
for lado in (1, -1):
    x = lado * 1.5
    torno(MOT, (x, 10.0, -7.0), (x, 10.0, 1.7),
          [(0.75, 0), (1.02, 0.03), (1.08, 0.1), (1.1, 0.35), (1.06, 0.7), (0.92, 0.9), (0.7, 1.0)], "blanco", 24, False, True)
    torno(MOT, (x, 10.0, -6.85), (x, 10.0, -6.2), [(0.78, 0), (0.78, 1)], "negro", 24, True, False)
    torno(MOT, (x, 10.0, -6.95), (x, 10.0, -6.15), [(0.02, 0), (0.28, 0.6), (0.3, 1.0)], "grisclaro", 14)
    for k in range(10):  # álabes de la toma
        ang = k / 10 * math.tau
        caja(MOT, (x + math.cos(ang) * 0.5, 10.0 + math.sin(ang) * 0.5, -6.35), (0.06, 0.48, 0.05), "gris", 0,
             rot=(0, 0, math.degrees(ang) + 90))
    torno(MOT, (x, 10.0, -7.08), (x, 10.0, -6.9), [(0.76, 0), (0.9, 0.5), (1.03, 1.0)], "cromo", 24, False, False)
    # escape doblado hacia fuera
    a, b = Vector((x, 10.0, 1.6)), Vector((x + lado * 0.8, 10.25, 3.7))
    torno(MOT, a, b, [(0.62, 0), (0.6, 0.6), (0.55, 1)], "grisclaro", 16, True, False)
    torno(MOT, b - (b - a).normalized() * 0.25, b + (b - a).normalized() * 0.02, [(0.47, 0), (0.47, 1)], "negro", 16, False, True)
    # rejillas laterales del carenado
    for k in range(5):
        caja(MOT, (lado * 1.98, 8.75 + k * 0.17, 0.9 + k * 0.0), (0.05, 0.08, 1.5), "negro", 0)
    # carenado lateral entre motor y lomo
    caja(MOT, (lado * 1.55, 9.25, -2.3), (1.0, 0.7, 7.2), "blanco", 0.3)
# mástil y plato oscilante
cil(MOT, (0, 9.6, ROTOR_EJE[2]), (0, ROTOR_EJE[1] - 0.25, ROTOR_EJE[2]), 0.42, "gris", 16)
torno(MOT, (0, 10.65, ROTOR_EJE[2]), (0, 10.95, ROTOR_EJE[2]), [(0.95, 0), (0.95, 1)], "cromo", 20)
for k in range(3):
    ang = k / 3 * math.tau
    cil(MOT, (math.cos(ang) * 0.7, 10.95, ROTOR_EJE[2] + math.sin(ang) * 0.7),
        (math.cos(ang) * 0.55, ROTOR_EJE[1] - 0.1, ROTOR_EJE[2] + math.sin(ang) * 0.55), 0.06, "gris", 6)
ovoide(MOT, (0, 9.85, 2.6), (0.28, 0.2, 0.28), "rojo", 10, 6); LUCES.append(("rojo", Vector((0, 10.0, 2.6))))

# botalón de cola
def botalon():
    bm = bmesh.new(); filas = []; seg = 16
    zs = [6.4 + 0.8 * i for i in range(23)]
    for z in zs:
        t = (z - 6.4) / (zs[-1] - 6.4)
        rx = 1.75 + (0.55 - 1.75) * t ** 0.8; ry = 1.45 + (0.6 - 1.45) * t ** 0.8
        yc = 7.25 + 0.9 * t
        filas.append([bm.verts.new((rx * math.cos(a), yc + ry * math.sin(a), z))
                      for a in (2 * math.pi * k / seg for k in range(seg))])
    for i in range(len(filas) - 1):
        for k in range(seg):
            bm.faces.new((filas[i][k], filas[i][(k + 1) % seg], filas[i + 1][(k + 1) % seg], filas[i + 1][k]))
    bm.faces.new(filas[-1]); bm.faces.new(list(reversed(filas[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    CASCO.bm(bm, "blanco")
botalon()
# deriva, estabilizadores y patín de cola (parte del casco)
placa(CASCO, [(20.6, 8.2), (24.6, 8.2), (25.1, 12.4), (24.0, 12.6)], -0.2, 0.2, "blanco", 0.08)
placa(CASCO, [(23.4, 8.1), (24.7, 8.1), (24.9, 6.6), (24.2, 6.6)], -0.16, 0.16, "blanco", 0.05)
for lado in (1, -1):
    bm = bmesh.new()
    pts = [(21.0, 0.0), (22.6, 0.0), (22.9, 3.0), (22.1, 3.0)]
    v = [bm.verts.new((lado * x, 8.35, z)) for z, x in pts]
    f = bm.faces.new(v if lado > 0 else list(reversed(v)))
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=Vector((0, 0.18, 0)), verts=[e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); biselar(bm, 0.06, 1)
    CASCO.bm(bm, "blanco")
    ovoide(DET, (lado * 3.0, 8.45, 22.8), (0.12, 0.12, 0.2), "verde" if lado > 0 else "rojo", 8, 6)
ovoide(DET, (0, 12.7, 24.3), (0.14, 0.14, 0.14), "rojo", 8, 6)
# carenado de la caja de cola
ovoide(MOT, (0, 11.0, 24.2), (0.55, 0.7, 0.9), "blanco", 14, 8)

# matrícula AMZ-07 a ambos lados del botalón (texto convertido a malla sin bpy.ops)
def matricula(lado):
    cu = bpy.data.curves.new("TxtAMZ", "FONT"); cu.body = "AMZ-07"; cu.align_x = "CENTER"; cu.align_y = "CENTER"
    cu.size = 1.1; cu.extrude = 0.03
    to = bpy.data.objects.new("TxtAMZ", cu); scene.collection.objects.link(to)
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(to.evaluated_get(dg))
    bpy.data.objects.remove(to); bpy.data.curves.remove(cu)
    bm = bmesh.new(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    # texto en XY (lectura +X), se coloca en el costado: lectura hacia la cola en estribor
    z0 = 14.6
    for v in bm.verts:
        x, y, z = v.co
        zz = z0 - lado * x; t = (zz - 6.4) / (24.0 - 6.4)
        rx = 1.75 + (0.55 - 1.75) * t ** 0.8; ry = 1.45 + (0.6 - 1.45) * t ** 0.8; yc = 7.25 + 0.9 * t
        yy = yc + y * 0.8; k = max(0.0, 1 - ((yy - yc) / ry) ** 2) ** 0.5
        v.co = Vector((lado * (rx * k - 0.02 + z), yy, zz))
    DET.bm(bm, "negro")
matricula(1); matricula(-1)

# ---------- rotores ----------
ROTOR = Malla("Rotor")
ex, ey, ez = ROTOR_EJE
torno(ROTOR, (ex, ey - 0.3, ez), (ex, ey + 0.55, ez), [(0.75, 0), (0.8, 0.3), (0.72, 0.75), (0.35, 1.0)], "gris", 20)
ovoide(ROTOR, (ex, ey + 0.55, ez), (0.42, 0.3, 0.42), "cromo", 14, 8)
for i in range(5):
    a = i / 5 * math.tau; d = Vector((math.cos(a), 0, math.sin(a))); s = Vector((-math.sin(a), 0, math.cos(a)))
    c0 = Vector(ROTOR_EJE)
    cil(ROTOR, c0 + d * 0.6, c0 + d * 1.75, 0.2, "gris", 10)                    # brazo
    caja(ROTOR, c0 + d * 1.4 + Vector((0, 0.18, 0)), (0.3, 0.3, 0.3), "cromo", 0.06)  # amortiguador
    L = 16.5
    bm = bmesh.new()                                                             # pala con perfil
    perf = [(-0.5, 0), (-0.25, 0.08), (0.2, 0.06), (0.5, 0), (0.2, -0.03), (-0.25, -0.04)]
    tramos = [1.6, 3, 6, 9, 12, L - 1.1, L - 1.05, L]
    filas = []
    for r in tramos:
        caida = -0.012 * (r - 1.6) ** 1.2
        filas.append([bm.verts.new(c0 + d * r + s * (u * 1.3) + Vector((0, v + caida, 0))) for u, v in perf])
    for j in range(len(filas) - 1):
        for k in range(len(perf)):
            bm.faces.new((filas[j][k], filas[j][(k + 1) % 6], filas[j + 1][(k + 1) % 6], filas[j + 1][k]))
    bm.faces.new(list(reversed(filas[0]))); bm.faces.new(filas[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ROTOR.bm(bm, lambda fc, c0=c0, d=d: "amarillo" if (fc.calc_center_median() - c0).dot(d) > L - 1.08 else "negro")

COLA = Malla("RotorCola")
cx, cy, cz = COLA_EJE
torno(COLA, (cx - 0.35, cy, cz), (cx + 0.3, cy, cz), [(0.3, 0), (0.32, 0.5), (0.12, 1)], "gris", 14)
for i in range(4):
    a = i / 4 * math.tau; d = Vector((0, math.cos(a), math.sin(a))); s = Vector((0, -math.sin(a), math.cos(a)))
    c0 = Vector(COLA_EJE) + Vector((0.05, 0, 0))
    bm = bmesh.new(); perf = [(-0.22, 0), (0, 0.05), (0.22, 0), (0, -0.03)]
    filas = [[bm.verts.new(c0 + d * r + s * u + Vector((v, 0, 0))) for u, v in perf] for r in (0.25, 1.6, 2.15, 2.2, 2.55)]
    for j in range(len(filas) - 1):
        for k in range(4):
            bm.faces.new((filas[j][k], filas[j][(k + 1) % 4], filas[j + 1][(k + 1) % 4], filas[j + 1][k]))
    bm.faces.new(list(reversed(filas[0]))); bm.faces.new(filas[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    COLA.bm(bm, lambda fc, c0=c0, d=d: "amarillo" if (fc.calc_center_median() - c0).dot(d) > 2.17 else "negro")

# ---------- tren y sponsons ----------
TREN = Malla("Tren")
def rueda(c, r=0.85, w=0.6):
    c = Vector(c)
    torno(TREN, c - Vector((w / 2, 0, 0)), c + Vector((w / 2, 0, 0)),
          [(r * 0.55, 0), (r * 0.88, 0.02), (r, 0.18), (r, 0.82), (r * 0.88, 0.98), (r * 0.55, 1)], "goma", 22, False, False)
    torno(TREN, c - Vector((w / 2 - 0.02, 0, 0)), c + Vector((w / 2 - 0.02, 0, 0)),
          [(r * 0.56, 0), (r * 0.5, 0.25), (r * 0.5, 0.75), (r * 0.56, 1)], "grisclaro", 22, True, True)
    torno(TREN, c - Vector((w / 2 + 0.03, 0, 0)), c + Vector((w / 2 + 0.03, 0, 0)), [(0.16, 0), (0.16, 1)], "cromo", 10)
for lado in (1, -1):
    ovoide(TREN, (lado * 3.95, 2.05, 2.7), (0.9, 0.78, 3.3), "naranja", 22, 12)
    torno(TREN, (lado * 3.95, 2.05, -0.75), (lado * 3.95, 2.05, -0.5), [(0.25, 0), (0.25, 1)], "gris", 10)
    caja(TREN, (lado * 3.45, 2.1, 2.7), (0.9, 0.5, 4.2), "naranja", 0.2)               # unión al casco
    rueda((lado * 4.0, 0.85, 3.0))
    cil(TREN, (lado * 4.0, 0.95, 3.0), (lado * 3.95, 1.6, 2.8), 0.2, "cromo", 10)
    cil(TREN, (lado * 3.4, 1.4, 1.8), (lado * 3.95, 1.05, 2.75), 0.12, "gris", 8)
    ovoide(DET, (lado * 3.95, 2.0, -0.58), (0.18, 0.18, 0.1), "faro", 10, 6)
# rueda de morro
cil(TREN, (0, 2.0, -10.4), (0, 0.85, -10.55), 0.16, "cromo", 10)
caja(TREN, (0, 0.85, -10.55), (0.75, 0.25, 0.3), "gris", 0.06)
for lado in (1, -1): rueda((lado * 0.3, 0.68, -10.55), 0.62, 0.36)

# ---------- interior ----------
INT = Malla("Interior")
Y_SUELO = 2.45
caja(INT, (0, Y_SUELO - 0.12, -1.3), (6.0, 0.24, 13.0), "suelo", 0.03)                # suelo de la bodega
for z in [-7 + 1.0 * i for i in range(13)]:
    caja(INT, (0, Y_SUELO + 0.01, z), (5.6, 0.04, 0.08), "negro", 0)                   # rieles del suelo
caja(INT, (0, Y_SUELO - 0.15, -10.2), (5.2, 0.2, 4.0), "suelo", 0.03)                 # piso de cabina
# mamparo con paso a la cabina
for lado in (1, -1):
    caja(INT, (lado * 2.55, 5.1, -7.6), (2.1, 5.4, 0.18), "olivaosc", 0.04)
caja(INT, (0, 7.55, -7.6), (3.0, 1.0, 0.18), "olivaosc", 0.04)
caja(INT, (0, 7.0, -7.55), (1.6, 0.06, 0.2), "gris", 0.02)
# costillas (marcos) en el techo y paredes
for z in [-6.6 + 1.6 * i for i in range(8)]:
    for lado in (1, -1):
        if lado > 0 and PUERTA_Z[0] - 0.2 <= z <= PUERTA_Z[1] + 0.2: continue
        p0, p1 = punto(z, 0.17, lado), punto(z, 0.86, lado)
        mid = (p0 + p1) / 2; n = normal_casco(z, 0.5, lado)
        caja(INT, mid - n * 0.32, (0.18, (p1 - p0).length, 0.22), "olivaosc", 0.04)
    caja(INT, (0, 8.15, z), (5.0, 0.2, 0.22), "olivaosc", 0.04)
# asientos de lona (babor completo, estribor detrás del hueco)
def asientos(lado, z0, z1):
    x = lado * 3.05; z = z0
    caja(INT, (x - lado * 0.35, 3.75, (z0 + z1) / 2), (0.08, 0.08, z1 - z0), "cromo", 0.02)
    caja(INT, (x + lado * 0.05, 6.05, (z0 + z1) / 2), (0.08, 0.08, z1 - z0), "cromo", 0.02)
    caja(INT, (x - lado * 0.75, 3.7, (z0 + z1) / 2), (0.08, 0.08, z1 - z0), "cromo", 0.02)
    while z + 1.2 <= z1 + 0.01:
        c = z + 0.6
        caja(INT, (x - lado * 0.4, 3.72, c), (0.82, 0.1, 1.1), "lona", 0.03)              # asiento
        caja(INT, (x + lado * 0.02, 4.9, c), (0.08, 2.2, 1.1), "lona", 0.02)              # respaldo
        for dz in (-0.3, 0.3):
            caja(INT, (x - lado * 0.01, 4.9, c + dz), (0.1, 2.2, 0.08), "ambar", 0)        # cinchas
        cil(INT, (x - lado * 0.75, Y_SUELO, c - 0.5), (x - lado * 0.75, 3.7, c - 0.5), 0.05, "cromo", 6)
        z += 1.25
asientos(-1, -6.9, 3.4)
asientos(1, -0.9, 3.4)
asientos(1, -7.3, -5.9) if False else None
# cajas amarradas al fondo y bolsas de equipo
for c, s in (((-1.1, Y_SUELO + 0.55, 3.9), (1.6, 1.1, 1.3)), ((0.7, Y_SUELO + 0.45, 4.1), (1.3, 0.9, 1.1)),
             ((-0.9, Y_SUELO + 1.4, 4.0), (1.2, 0.7, 1.0))):
    caja(INT, c, s, "caja", 0.07)
    caja(INT, (c[0], c[1], c[2]), (s[0] + 0.04, s[1] + 0.04, 0.12), "ambar", 0.02)
# tubos y lámparas del techo
for x in (-1.6, 1.6):
    cil(INT, (x, 8.0, -7.4), (x, 8.0, 4.6), 0.09, "gris", 8)
for z in (-5.0, -1.0, 3.0):
    caja(INT, (0, 7.95, z), (0.7, 0.14, 0.4), "gris", 0.04)
    caja(INT, (0, 7.87, z), (0.5, 0.04, 0.28), "faro", 0)
# cabina: asientos de pilotos, consola y panel
for lado in (1, -1):
    x = lado * 1.2
    caja(INT, (x, 3.3, -9.9), (1.15, 0.3, 1.1), "piel", 0.08)
    caja(INT, (x, 4.6, -9.35), (1.15, 2.4, 0.28), "piel", 0.1, rot=(-10, 0, 0))
    caja(INT, (x, 6.05, -9.15), (0.8, 0.5, 0.25), "piel", 0.08)
    caja(INT, (x, 2.85, -9.9), (0.7, 0.6, 0.7), "gris", 0.04)
    cil(INT, (x, 3.5, -11.4), (x, 4.1, -11.15), 0.06, "negro", 6)                     # cíclico
caja(INT, (0, 3.3, -10.6), (0.7, 1.3, 2.0), "gris", 0.06)                               # consola central
caja(INT, (0, 4.25, -12.0), (4.6, 1.3, 0.9), "negro", 0.1, rot=(25, 0, 0))              # panel
caja(INT, (0, 4.95, -11.75), (4.7, 0.18, 1.0), "gris", 0.06)                            # visera
for x in (-1.5, -0.5, 0.5, 1.5):
    caja(INT, (x, 4.3, -11.56), (0.75, 0.55, 0.04), "pantalla" if abs(x) > 1 else "ambar", 0, rot=(25, 0, 0))
caja(INT, (0, 8.0, -10.0), (2.2, 0.3, 1.6), "negro", 0.06)                              # panel de techo

# ---------- construir objetos ----------
objs = [m.objeto() for m in (CASCO, VIDRIOS, PUERTA, VIDRIO_PUERTA, RAMPA, ROTOR, COLA, MOT, TREN, DET, INT)]
tris = {}
for o in objs:
    n = sum(len(p.vertices) - 2 for p in o.data.polygons); tris[o.name] = n
print("TRIS", tris, "TOTAL", sum(tris.values()))
assert all(n < 20000 for n in tris.values()), "una malla supera 20k triángulos"

# ---------- exportar (puerta cerrada, rampa cerrada) ----------
for o in bpy.data.objects: o.select_set(o in objs)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.export_scene.gltf(filepath=os.path.join(EXPORT, "HelicopteroAMZ07.glb"), export_format="GLB",
                          use_selection=True, export_apply=True)
with open(os.path.join(EXPORT, "HelicopteroAMZ07.medidas.txt"), "w") as fh:
    fh.write(f"PUERTA_Z={PUERTA_Z}\nPUERTA_RECORRIDO={PUERTA_RECORRIDO}\nRAMPA_BISAGRA={RAMPA_BISAGRA}\n"
             f"ROTOR_EJE={ROTOR_EJE}\nCOLA_EJE={COLA_EJE}\nTRIS={tris}\n")

# ---------- render de previsualización ----------
world = bpy.data.worlds.new("Estudio"); world.use_nodes = True
bg = world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = (0.2, 0.2, 0.21, 1); bg.inputs["Strength"].default_value = 0.7
scene.world = world
sol = bpy.data.lights.new("Sol", "SUN"); sol.energy = 3.4; sol.angle = math.radians(3)
so = bpy.data.objects.new("Sol", sol); so.rotation_euler = (math.radians(48), math.radians(10), math.radians(-150)); scene.collection.objects.link(so)
rel = bpy.data.lights.new("Relleno", "AREA"); rel.energy = 9000; rel.size = 30
ro = bpy.data.objects.new("Relleno", rel); ro.location = T((40, 14, -30)); scene.collection.objects.link(ro)
ro.rotation_euler = (Vector((0, 0, 0)) - ro.location).to_track_quat("-Z", "Y").to_euler()
gd = bpy.data.meshes.new("Suelo"); gbm = bmesh.new(); bmesh.ops.create_circle(gbm, cap_ends=True, radius=200, segments=48); gbm.to_mesh(gd); gbm.free()
g = bpy.data.objects.new("Suelo", gd); scene.collection.objects.link(g)
ms = bpy.data.materials.new("Suelo"); ms.use_nodes = True; ms.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.16, 0.17, 1)
gd.materials.append(ms)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "AgX"
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); scene.collection.objects.link(cam); scene.camera = cam
def toma(nombre, desde, hacia, lente=40, res=(1600, 900)):
    scene.render.resolution_x, scene.render.resolution_y = res; cd.lens = lente
    cam.location = T(desde); cam.rotation_euler = (T(hacia) - T(desde)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, nombre); bpy.ops.render.render(write_still=True)
toma("heli_concepto.png", (44, 9, -12), (0, 6.0, 4), 35)
toma("heli_frente.png", (20, 7, -34), (0, 6, -2), 35)
toma("heli_trasera.png", (-26, 12, 40), (0, 6, 8), 35)
# puerta abierta y rampa abierta para comprobar el hueco y el interior
for nom in ("Puerta", "VidrioPuerta"): bpy.data.objects[nom].location = T((0, 0, PUERTA_RECORRIDO))
ra = bpy.data.objects["Rampa"]; h = Vector(RAMPA_BISAGRA)
ra.matrix_world = Matrix.Translation(T(h)) @ Matrix.Rotation(math.radians(-62), 4, "X") @ Matrix.Translation(-T(h))
toma("heli_puerta_abierta.png", (17, 5.5, -7), (0, 5, -2.5), 32)
toma("heli_rampa_abierta.png", (6, 6, 34), (0, 4.5, 2), 35)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "HelicopteroAMZ07.blend"))
print("LISTO")
