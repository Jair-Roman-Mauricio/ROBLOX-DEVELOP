--!strict
--[[
	Grafo de zonas del mapa (primer paso de la generación, según CONTEXT.md):
	coloca inicio, pueblos, helicóptero y salida; traza el río y los senderos que los conectan.

	Distribución base (propuesta del CONTEXT.md, norte = -Z):
	  A inicio (sur) · B pueblo 1 (suroeste) · C helicóptero (centro-oeste)
	  D pueblo 2 (centro-este) · E pueblo 3 (noroeste) · F salida (noreste)
	Cada semilla desplaza las zonas, cambia el trazado del río y de los senderos, elige atajos
	distintos y puede reflejar el mapa este-oeste.
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
}

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
}

local PLANTILLA = {
	{ id = "A", tipo = "inicio", nombre = "Claro inicial", u = 0.50, v = 0.88, radio = 40 },
	{ id = "B", tipo = "pueblo", nombre = "Pueblo 1", u = 0.20, v = 0.72, radio = 66 },
	{ id = "C", tipo = "helicoptero", nombre = "Helicóptero", u = 0.27, v = 0.45, radio = 48 },
	{ id = "D", tipo = "pueblo", nombre = "Pueblo 2", u = 0.70, v = 0.40, radio = 66 },
	{ id = "E", tipo = "pueblo", nombre = "Pueblo 3", u = 0.20, v = 0.18, radio = 66 },
	{ id = "F", tipo = "salida", nombre = "Salida", u = 0.80, v = 0.12, radio = 36 },
}

local RUTA = { { "A", "B" }, { "B", "C" }, { "C", "D" }, { "D", "E" }, { "E", "F" } }
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
	},
		nil
end

return Disposicion
