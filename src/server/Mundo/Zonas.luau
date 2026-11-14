--!strict
--[[
	Contenido de cada zona del mapa: claro inicial (A), pueblos fantasma (B, D, E),
	helicóptero estrellado (C) y paso de salida (F).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Estructuras = require(script.Parent.Parent.Modelos.Estructuras)
local Kit = require(script.Parent.Parent.Modelos.Kit)
local Terreno = require(script.Parent.Terreno)

local C = Config.Mapa

local Zonas = {}

-- Punto del suelo en (x, z); si el raycast falla usa la altura calculada.
local function suelo(datos: Terreno.Datos, x: number, z: number): Vector3
	local p = Kit.suelo(x, z)
	return p or Vector3.new(x, datos.altura(x, z), z)
end

local function sobreCamino(datos: Terreno.Datos, x: number, z: number, margen: number): boolean
	return datos.distanciaCamino(x, z) < C.ANCHO_CAMINO + margen
end

function Zonas.pueblo(rng: Random, centro: Vector3, radio: number, datos: Terreno.Datos, padre: Instance): Model
	local m = Kit.modelo("Pueblo", padre)
	Estructuras.maloca(
		rng,
		CFrame.new(suelo(datos, centro.X, centro.Z)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		m
	)

	local n = rng:NextInteger(5, 7)
	local a0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, n do
		for _ = 1, 6 do
			local a = a0 + i / n * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local r = rng:NextNumber(30, radio - 14)
			local x, z = centro.X + math.cos(a) * r, centro.Z + math.sin(a) * r
			if not sobreCamino(datos, x, z, 10) then
				local p = suelo(datos, x, z)
				local cf = CFrame.lookAt(p, Vector3.new(centro.X, p.Y, centro.Z))
				Estructuras.choza(rng, cf, m)
				Estructuras.antorcha(
					rng,
					CFrame.new(suelo(datos, (cf * CFrame.new(5.5, 0, -9)).X, (cf * CFrame.new(5.5, 0, -9)).Z)),
					m
				)
				if rng:NextNumber() < 0.6 then
					local q = cf * CFrame.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(4, 9))
					Estructuras.pilaCajas(rng, CFrame.new(suelo(datos, q.X, q.Z)), m)
				end
				break
			end
		end
	end

	-- antorchas alrededor de la maloca y restos de la vida del pueblo
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		Estructuras.antorcha(rng, CFrame.new(suelo(datos, centro.X + math.cos(a) * 18, centro.Z + math.sin(a) * 18)), m)
	end
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = suelo(datos, centro.X + math.cos(a) * 22, centro.Z + math.sin(a) * 22)
		Estructuras.troncosApilados(rng, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), m)
	end

	-- vallas rotas en tramos del perímetro, sin cortar senderos
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local desde = suelo(datos, centro.X + math.cos(a) * (radio - 6), centro.Z + math.sin(a) * (radio - 6))
		local b = a + rng:NextNumber(0.25, 0.45)
		local hasta = suelo(datos, centro.X + math.cos(b) * (radio - 6), centro.Z + math.sin(b) * (radio - 6))
		local medio = (desde + hasta) / 2
		if
			not sobreCamino(datos, desde.X, desde.Z, 4)
			and not sobreCamino(datos, hasta.X, hasta.Z, 4)
			and not sobreCamino(datos, medio.X, medio.Z, 4)
		then
			Estructuras.valla(rng, desde, hasta, m)
		end
	end

	-- tótems con glifos marcan el límite de la zona protegida
	local totems = 12
	for i = 1, totems do
		local a = i / totems * math.pi * 2
		local x, z = centro.X + math.cos(a) * radio, centro.Z + math.sin(a) * radio
		if not sobreCamino(datos, x, z, 3) then
			local p = suelo(datos, x, z)
			Estructuras.totem(
				rng,
				CFrame.lookAt(p, Vector3.new(centro.X, p.Y, centro.Z)) * CFrame.Angles(0, math.pi, 0),
				m
			)
		end
	end
	return m
end

-- Claro inicial: campamento improvisado de los supervivientes. Devuelve los puntos de aparición.
function Zonas.inicio(rng: Random, centro: Vector3, datos: Terreno.Datos, padre: Instance): (Model, { Vector3 })
	local m = Kit.modelo("ClaroInicial", padre)
	local giro = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local function en(x: number, z: number): CFrame
		local q = (CFrame.new(centro) * giro * CFrame.new(x, 0, z)).Position
		return CFrame.new(suelo(datos, q.X, q.Z)) * giro
	end
	Estructuras.fogon(rng, en(0, 0), m, true)
	Estructuras.lona(rng, en(13, 4) * CFrame.Angles(0, 0.3, 0), m)
	Estructuras.lona(rng, en(-12, 8) * CFrame.Angles(0, -0.5, 0), m, Color3.fromRGB(150, 120, 60))
	Estructuras.maletas(rng, en(4, -9), m)
	Estructuras.pilaCajas(rng, en(-14, -6), m)
	Estructuras.bengala(en(20, -12), m)
	Estructuras.bengala(en(-22, -14), m)
	Estructuras.barril(rng, en(16, 12), m)
	Estructuras.barril(rng, en(18, 10), m, true)
	local spawns = {}
	for i = 1, Config.MAX_POR_EQUIPO do
		local a = i / Config.MAX_POR_EQUIPO * math.pi * 2 + 0.3
		table.insert(spawns, en(math.cos(a) * 6, math.sin(a) * 6).Position + Vector3.new(0, 3.5, 0))
	end
	return m, spawns
end

function Zonas.helicoptero(rng: Random, centro: Vector3, datos: Terreno.Datos, padre: Instance): Model
	local m = Kit.modelo("Accidente", padre)
	local giro = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local function en(x: number, z: number): CFrame
		local q = (CFrame.new(centro) * giro * CFrame.new(x, 0, z)).Position
		return CFrame.new(suelo(datos, q.X, q.Z)) * giro
	end
	Estructuras.helicoptero(rng, en(0, 0), m, true)
	Estructuras.radar(rng, en(-16, 6) * CFrame.Angles(0, 0.6, 0), m)
	Estructuras.pilaCajas(rng, en(14, -10), m)
	Estructuras.maletas(rng, en(-6, -16), m)
	Estructuras.barril(rng, en(-12, -6), m, true)
	return m
end

-- `fuera` apunta desde el centro del mapa hacia la salida: la portada mira hacia el interior.
function Zonas.salida(rng: Random, centro: Vector3, fuera: Vector2, datos: Terreno.Datos, padre: Instance): Model
	local m = Kit.modelo("Salida", padre)
	local p = suelo(datos, centro.X, centro.Z)
	local cf = CFrame.lookAt(p, p - Vector3.new(fuera.X, 0, fuera.Y))
	Estructuras.portadaSalida(rng, cf, m)
	for i = 1, 3 do
		local q = cf * CFrame.new(rng:NextNumber(-14, 14), 0, -10 - i * 6)
		local s = suelo(datos, q.X, q.Z)
		Estructuras.antorcha(rng, CFrame.new(s), m)
	end
	return m
end

return Zonas
