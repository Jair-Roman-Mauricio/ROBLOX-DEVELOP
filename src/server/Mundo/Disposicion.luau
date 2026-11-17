--!strict
--[[
	Grafo de zonas del mapa (primer paso de la generación, según CONTEXT.md):
	coloca inicio, pueblos, helicóptero y salida; traza el río y los senderos que los conectan.

	Distribución base (propuesta del CONTEXT.md, norte = -Z):
	  A inicio (sur) · B pueblo 1 (suroeste) · C helicóptero (centro-oeste)
	  D pueblo 2 (centro-este) · E pueblo 3 (noroeste) · F salida (noreste)
	Cada semilla desplaza las zonas, cambia el trazado del río y de los senderos, elige atajos
	distintos y puede reflejar el mapa este-oeste.

	Encima va el culto a la serpiente (docs/SELVA-CULTO.md): el templo (T) unido a la salida,
	un estilo de aldea por pueblo, el lago negro junto a los palafitos, el lago de la cascada en
	el borde, arroyos que bajan al río, rápidos y santuarios junto a los senderos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Mapa
local S = C.TAMANO
local MITAD = S / 2

export type Zona = {
	id: string,
	tipo: string,
	nombre: string,
	pos: Vector2,
	radio: number,
	altura: number, -- la rellena Terreno
	estilo: string?, -- aldea: "ladera", "palafitos" o "ruinas"
	inclinacion: Vector2, -- desnivel por stud de la meseta (aldea de ladera); la rellena Terreno
}

export type Lago = {
	tipo: string, -- "pantano" o "cascada"
	centro: Vector2,
	radio: number,
	fuera: Vector2, -- pantano: hacia la aldea; cascada: hacia la cresta de la que cae
	nivel: number, -- la rellena Terreno
}

export type Arroyo = {
	puntos: { Vector2 },
	niveles: { number }, -- superficie del agua en cada muestra; la rellena Terreno
	activo: boolean, -- Terreno lo apaga si tendría que cortar un cañón
	motivo: string?, -- por qué no se excavó (para depurar)
}

export type Santuario = { pos: Vector2, frente: Vector2 }

export type Camino = {
	a: string,
	b: string,
	puntos: { Vector2 },
	alturas: { number }, -- las rellena Terreno
}

export type Disposicion = {
	zonas: { Zona },
	porId: { [string]: Zona },
	caminos: { Camino },
	rio: { Vector2 },
	crestas: { Vector2 },
	espejo: boolean,
	lagos: { Lago },
	arroyos: { Arroyo },
	rapidos: { Vector2 },
	santuarios: { Santuario },
	-- sitios donde no crece nada (santuarios); los lagos y arroyos ya los evita el agua
	reservas: { { pos: Vector2, radio: number } },
}

local PLANTILLA = {
	{ id = "A", tipo = "inicio", nombre = "Claro inicial", u = 0.50, v = 0.88, radio = 40 },
	{ id = "B", tipo = "pueblo", nombre = "Pueblo 1", u = 0.20, v = 0.72, radio = 66 },
	{ id = "C", tipo = "helicoptero", nombre = "Helicóptero", u = 0.27, v = 0.45, radio = 48 },
	{ id = "D", tipo = "pueblo", nombre = "Pueblo 2", u = 0.70, v = 0.40, radio = 66 },
	{ id = "E", tipo = "pueblo", nombre = "Pueblo 3", u = 0.20, v = 0.18, radio = 66 },
	{ id = "F", tipo = "salida", nombre = "Salida", u = 0.80, v = 0.12, radio = 36 },
	-- el templo: hito que se ve sobre el dosel, al final del recorrido
	{ id = "T", tipo = "templo", nombre = "Templo de la Serpiente", u = 0.64, v = 0.21, radio = 90 },
}

-- cada pueblo cuenta una historia distinta
local ESTILOS = { B = "ladera", D = "palafitos", E = "ruinas" }

local A = Config.Mapa.Agua
local CU = Config.Mapa.Culto

local RUTA = { { "A", "B" }, { "B", "C" }, { "C", "D" }, { "D", "E" }, { "E", "F" }, { "F", "T" } }
local ATAJOS = { { "A", "D" }, { "C", "E" }, { "D", "F" }, { "A", "C" }, { "B", "E" } }

-- Puntos de control del río en coordenadas normalizadas: entra por el norte, baja al
-- centro y sale por el este, como en el mapa de referencia.
local RIO = {
	{ 0.50, -0.03, 0.05 },
	{ 0.50, 0.18, 0.06 },
	{ 0.48, 0.38, 0.04 },
	{ 0.55, 0.57, 0.04 },
	{ 0.74, 0.66, 0.04 },
	{ 1.03, 0.66, 0.08 },
}

local Disposicion = {}

local function mundo(u: number, v: number): Vector2
	return Vector2.new((u - 0.5) * S, (v - 0.5) * S)
end

local function catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: number): Vector2
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- Curva suave que pasa por los puntos de control, muestreada cada `paso` studs.
local function muestrear(ctrl: { Vector2 }, paso: number): { Vector2 }
	local salida = { ctrl[1] }
	for i = 1, #ctrl - 1 do
		local p0 = ctrl[math.max(1, i - 1)]
		local p1, p2 = ctrl[i], ctrl[i + 1]
		local p3 = ctrl[math.min(#ctrl, i + 2)]
		local pasos = math.max(1, math.ceil((p2 - p1).Magnitude / paso))
		for k = 1, pasos do
			table.insert(salida, catmull(p0, p1, p2, p3, k / pasos))
		end
	end
	return salida
end

local function limitar(p: Vector2, margen: number): Vector2
	return Vector2.new(math.clamp(p.X, -margen, margen), math.clamp(p.Y, -margen, margen))
end

-- Sendero serpenteante por desplazamiento de punto medio.
local function sendero(rng: Random, a: Vector2, b: Vector2): { Vector2 }
	local ctrl = { a, b }
	local desvio = (b - a).Magnitude * 0.2
	for _ = 1, 3 do
		local nuevos = { ctrl[1] }
		for i = 1, #ctrl - 1 do
			local p, q = ctrl[i], ctrl[i + 1]
			local dir = q - p
			local perp = Vector2.new(-dir.Y, dir.X).Unit
			local medio = (p + q) / 2 + perp * rng:NextNumber(-desvio, desvio)
			table.insert(nuevos, limitar(medio, MITAD * 0.86))
			table.insert(nuevos, q)
		end
		ctrl = nuevos
		desvio *= 0.45
	end
	return muestrear(ctrl, C.CELDA)
end

local function distanciaA(p: Vector2, puntos: { Vector2 }): number
	local mejor = math.huge
	for _, q in puntos do
		local d = (p - q).Magnitude
		if d < mejor then
			mejor = d
		end
	end
	return mejor
end

-- Devuelve nil si la disposición no cumple las separaciones mínimas (se reintenta).
function Disposicion.generar(rng: Random): (Disposicion?, string?)
	local espejo = C.ESPEJO_ALEATORIO and rng:NextNumber() < 0.5
	local function u(valor: number): number
		return if espejo then 1 - valor else valor
	end

	-- río
	local ctrlRio = {}
	for _, p in RIO do
		local jit = p[3]
		table.insert(ctrlRio, mundo(u(p[1] + rng:NextNumber(-jit, jit)), p[2] + rng:NextNumber(-jit, jit) * 0.5))
	end
	local rio = muestrear(ctrlRio, C.CELDA)

	-- zonas
	local zonas: { Zona } = {}
	local porId: { [string]: Zona } = {}
	for _, z in PLANTILLA do
		local zona: Zona = {
			id = z.id,
			tipo = z.tipo,
			nombre = z.nombre,
			pos = mundo(u(z.u + rng:NextNumber(-0.05, 0.05)), z.v + rng:NextNumber(-0.04, 0.04)),
			radio = z.radio,
			altura = 0,
			estilo = (ESTILOS :: any)[z.id],
			inclinacion = Vector2.zero,
		}
		local libre = distanciaA(zona.pos, rio) - (C.ANCHO_RIO + C.ORILLA)
		if libre < zona.radio + 20 then
			return nil, ("la zona %s queda junto al río"):format(z.id)
		end
		for _, otra in zonas do
			if (otra.pos - zona.pos).Magnitude < otra.radio + zona.radio + 80 then
				return nil, ("las zonas %s y %s se solapan"):format(otra.id, z.id)
			end
		end
		table.insert(zonas, zona)
		porId[zona.id] = zona
	end

	-- senderos: ruta obligatoria + atajos al azar
	local aristas = table.clone(RUTA)
	local candidatos = table.clone(ATAJOS)
	for _ = 1, rng:NextInteger(C.ATAJOS[1], C.ATAJOS[2]) do
		local k = rng:NextInteger(1, #candidatos)
		table.insert(aristas, table.remove(candidatos, k) :: { string })
	end
	local caminos: { Camino } = {}
	for _, arista in aristas do
		local a, b = porId[arista[1]], porId[arista[2]]
		table.insert(caminos, { a = a.id, b = b.id, puntos = sendero(rng, a.pos, b.pos), alturas = {} })
	end

	local lagos = Disposicion.lagos(rng, zonas, caminos, rio)
	local arroyos = Disposicion.arroyos(rng, zonas, lagos)
	local santuarios = Disposicion.santuarios(rng, zonas, caminos, rio)
	local reservas = {}
	for _, s in santuarios do
		table.insert(reservas, { pos = s.pos, radio = 10 })
	end

	-- dos crestas flanquean la salida para formar un paso entre elevaciones
	local f = porId.F
	local dir = f.pos.Unit
	local perp = Vector2.new(-dir.Y, dir.X)
	local crestas = { f.pos + perp * 78 + dir * 12, f.pos - perp * 78 + dir * 12 }

	return {
		zonas = zonas,
		porId = porId,
		caminos = caminos,
		rio = rio,
		crestas = crestas,
		espejo = espejo,
		lagos = lagos,
		arroyos = arroyos,
		rapidos = Disposicion.rapidos(rng, caminos, rio),
		santuarios = santuarios,
		reservas = reservas,
	},
		nil
end

-- Distancia mínima de `p` a cualquier sendero (muestreado cada 2 puntos).
local function distanciaCaminos(p: Vector2, caminos: { Camino }): number
	local mejor = math.huge
	for _, cam in caminos do
		for j = 1, #cam.puntos, 2 do
			local d = (p - cam.puntos[j]).Magnitude
			if d < mejor then
				mejor = d
			end
		end
	end
	return mejor
end

local function distanciaZonas(p: Vector2, zonas: { Zona }, extra: number): number
	local mejor = math.huge
	for _, z in zonas do
		mejor = math.min(mejor, (p - z.pos).Magnitude - z.radio - extra)
	end
	return mejor
end

-- Lago negro junto a la aldea de palafitos y lago pequeño al pie de una cascada en el borde.
-- Ninguno pisa senderos, zonas ni el río: si no cabe, ese lago no se crea.
function Disposicion.lagos(rng: Random, zonas: { Zona }, caminos: { Camino }, rio: { Vector2 }): { Lago }
	local lagos: { Lago } = {}
	local function cabe(c: Vector2, r: number, margenCamino: number, ignorar: Zona?): boolean
		if distanciaCaminos(c, caminos) < C.ANCHO_CAMINO + r + margenCamino then
			return false
		end
		if distanciaA(c, rio) < C.ANCHO_RIO + C.ORILLA + r + 30 then
			return false
		end
		for _, z in zonas do
			if z ~= ignorar and (c - z.pos).Magnitude < z.radio + r + 40 then
				return false
			end
		end
		for _, l in lagos do
			if (c - l.centro).Magnitude < l.radio + r + 60 then
				return false
			end
		end
		return math.max(math.abs(c.X), math.abs(c.Y)) < MITAD * 0.78
	end

	-- pantano: tocando el borde de la aldea de palafitos, por el lado que no cruza senderos
	local aldea: Zona? = nil
	for _, z in zonas do
		if z.estilo == "palafitos" then
			aldea = z
		end
	end
	if aldea then
		local hecho = false
		local r = rng:NextNumber(A.PANTANO_RADIO[1], A.PANTANO_RADIO[2])
		while not hecho and r >= A.PANTANO_RADIO[1] * 0.7 do
			local a0 = rng:NextNumber(0, math.pi * 2)
			for k = 0, 15 do
				local a = a0 + k / 16 * math.pi * 2
				local dir = Vector2.new(math.cos(a), math.sin(a))
				local c = aldea.pos + dir * (aldea.radio + r + 6)
				if cabe(c, r, 20, aldea) then
					table.insert(lagos, { tipo = "pantano", centro = c, radio = r, fuera = -dir, nivel = 0 })
					hecho = true
					break
				end
			end
			r *= 0.85
		end
	end

	-- cascada: en la franja del borde, que la cresta de detrás quede fuera del área jugable
	local r = A.CASCADA_RADIO
	for _ = 1, 60 do
		local t = rng:NextNumber(-0.7, 0.7) * MITAD
		local lado = rng:NextInteger(1, 4)
		local f = MITAD * 0.72
		local c, fuera
		if lado == 1 then
			c, fuera = Vector2.new(t, -f), Vector2.new(0, -1)
		elseif lado == 2 then
			c, fuera = Vector2.new(t, f), Vector2.new(0, 1)
		elseif lado == 3 then
			c, fuera = Vector2.new(-f, t), Vector2.new(-1, 0)
		else
			c, fuera = Vector2.new(f, t), Vector2.new(1, 0)
		end
		if cabe(c, r, 70, nil) then
			table.insert(lagos, { tipo = "cascada", centro = c, radio = r, fuera = fuera, nivel = 0 })
			break
		end
	end
	return lagos
end

-- Nacimientos de los arroyos: uno sale del lago de la cascada (por el lado opuesto a la pared)
-- y los demás en la franja del borde, lejos de las zonas. El cauce lo traza Terreno siguiendo
-- la pendiente hacia abajo, como el agua.
function Disposicion.arroyos(rng: Random, zonas: { Zona }, lagos: { Lago }): { Arroyo }
	local arroyos: { Arroyo } = {}
	for _, l in lagos do
		if l.tipo == "cascada" then
			table.insert(arroyos, {
				puntos = { l.centro - l.fuera * (l.radio - 4), l.centro - l.fuera * (l.radio + 6) },
				niveles = {},
				activo = true,
			})
		end
	end
	local quiero = rng:NextInteger(A.ARROYOS[1], A.ARROYOS[2]) + 1 -- alguno se pierde por el camino
	for _ = 1, 60 do
		if #arroyos >= quiero then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local p = Vector2.new(math.cos(a), math.sin(a))
		p = p / math.max(math.abs(p.X), math.abs(p.Y)) * MITAD * 0.76
		local lejos = distanciaZonas(p, zonas, 60) > 0
		for _, otro in arroyos do
			if (otro.puntos[#otro.puntos] - p).Magnitude < 300 then
				lejos = false
			end
		end
		for _, l in lagos do
			if (l.centro - p).Magnitude < l.radio + 60 then
				lejos = false
			end
		end
		if lejos then
			table.insert(arroyos, { puntos = { p }, niveles = {}, activo = true })
		end
	end
	return arroyos
end

-- Tramos del río poco profundos y con rocas, lejos de los cruces de los senderos.
function Disposicion.rapidos(rng: Random, caminos: { Camino }, rio: { Vector2 }): { Vector2 }
	local rapidos: { Vector2 } = {}
	for _ = 1, 40 do
		if #rapidos >= A.RAPIDOS then
			break
		end
		local p = rio[rng:NextInteger(4, #rio - 4)]
		local valido = math.max(math.abs(p.X), math.abs(p.Y)) < MITAD * 0.8
			and distanciaCaminos(p, caminos) > C.ANCHO_RIO + A.RAPIDO_LARGO + 30
		for _, q in rapidos do
			if (p - q).Magnitude < 220 then
				valido = false
			end
		end
		if valido then
			table.insert(rapidos, p)
		end
	end
	return rapidos
end

-- Santuarios junto a los senderos, a un lado y mirando al sendero, separados entre sí.
function Disposicion.santuarios(rng: Random, zonas: { Zona }, caminos: { Camino }, rio: { Vector2 }): { Santuario }
	local santuarios: { Santuario } = {}
	for _ = 1, 200 do
		if #santuarios >= CU.SANTUARIOS then
			break
		end
		local cam = caminos[rng:NextInteger(1, #caminos)]
		if #cam.puntos < 12 then
			continue
		end
		local k = rng:NextInteger(6, #cam.puntos - 6)
		local dir = cam.puntos[k + 1] - cam.puntos[k - 1]
		if dir.Magnitude < 1e-3 then
			continue
		end
		local lado = if rng:NextNumber() < 0.5 then -1 else 1
		local perp = Vector2.new(-dir.Y, dir.X).Unit * lado
		local p = cam.puntos[k] + perp * (C.ANCHO_CAMINO + 7)
		local valido = distanciaZonas(p, zonas, 40) > 0
			and distanciaA(p, rio) > C.ANCHO_RIO + C.ORILLA + 25
			and distanciaCaminos(p, caminos) > C.ANCHO_CAMINO + 4
		for _, s in santuarios do
			if (s.pos - p).Magnitude < CU.SANTUARIO_ESPACIO then
				valido = false
			end
		end
		if valido then
			table.insert(santuarios, { pos = p, frente = -perp })
		end
	end
	return santuarios
end

return Disposicion
