--!strict
--[[
	Contenido de cada zona del mapa: claro inicial (A), pueblos fantasma (B, D, E),
	helicóptero estrellado (C), paso de salida (F) y templo de la serpiente (T).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aldea = require(script.Parent.Parent.Modelos.Aldea)
local Atmosfera = require(script.Parent.Parent.Modelos.Atmosfera)
local Config = require(ReplicatedStorage.Shared.Config)
local Culto = require(script.Parent.Parent.Modelos.Culto)
local Disposicion = require(script.Parent.Disposicion)
local Estructuras = require(script.Parent.Parent.Modelos.Estructuras)
local Helicoptero = require(script.Parent.Parent.Modelos.Helicoptero)
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

-- Pueblo fantasma. Los tres comparten lo de siempre (antorchas, vallas y los tótems que marcan
-- la zona protegida) y cada uno cuenta su historia según `zona.estilo` (docs/SELVA-CULTO.md):
--   ladera     chozas de paja hundidas, cercas podridas, hamacas, vasijas volcadas, lianas
--   palafitos  chozas sobre el lago negro con pasarelas caídas y alguna medio hundida
--   ruinas     pozo de piedra en la plaza empedrada y sala de reuniones en ruinas
-- Todas se abandonaron a toda prisa: enseres tirados, puertas rotas, nada vivo. El altar de
-- cada una era para mantener lejos a la serpiente.
function Zonas.pueblo(
	rng: Random,
	centro: Vector3,
	zona: Disposicion.Zona,
	datos: Terreno.Datos,
	padre: Instance,
	lago: Disposicion.Lago?
): Model
	local radio = zona.radio
	local estilo = zona.estilo or "ladera"
	local m = Kit.modelo("Pueblo", padre)
	m:SetAttribute("Estilo", estilo)

	-- sitios ocupados, para que nada se monte encima de otra cosa
	local ocupado: { { p: Vector2, r: number } } = {}
	local function libreEn(x: number, z: number, r: number): boolean
		if sobreCamino(datos, x, z, r * 0.6 + 3) then
			return false
		end
		if lago and (Vector2.new(x, z) - lago.centro).Magnitude < lago.radio + r + 2 then
			return false
		end
		for _, o in ocupado do
			if (o.p - Vector2.new(x, z)).Magnitude < o.r + r then
				return false
			end
		end
		return true
	end
	local function ocupar(p: Vector3, r: number)
		table.insert(ocupado, { p = Vector2.new(p.X, p.Z), r = r })
	end
	local function buscar(rMin: number, rMax: number, r: number): Vector3?
		for _ = 1, 24 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(rMin, math.max(rMin, rMax))
			local x, z = centro.X + math.cos(a) * d, centro.Z + math.sin(a) * d
			if libreEn(x, z, r) then
				local p = suelo(datos, x, z)
				ocupar(p, r)
				return p
			end
		end
		return nil
	end
	local function mirandoAlCentro(p: Vector3): CFrame
		return CFrame.lookAt(p, Vector3.new(centro.X, p.Y, centro.Z))
	end

	-- el centro: maloca, o pozo con la sala de reuniones en las ruinas
	if estilo == "ruinas" then
		local p = suelo(datos, centro.X, centro.Z)
		Aldea.pozo(rng, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), m)
		ocupar(p, 8)
		local sala = buscar(30, radio - 20, 18)
		if sala then
			Aldea.sala(rng, mirandoAlCentro(sala), m)
		end
	else
		local p = suelo(datos, centro.X, centro.Z)
		Estructuras.maloca(rng, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), m)
		ocupar(p, 13)
	end

	-- altar de protección mirando al centro
	local altar = buscar(24, radio - 18, 12)
	if altar then
		Culto.altar(rng, mirandoAlCentro(altar), m)
	end

	-- viviendas
	for _ = 1, rng:NextInteger(5, 7) do
		local p = buscar(30, radio - 14, 9)
		if p then
			local cf = mirandoAlCentro(p)
			if estilo == "ruinas" and rng:NextNumber() < 0.5 then
				Aldea.ruina(rng, cf, m)
			else
				local hundida = rng:NextNumber()
					< (if estilo == "ladera" then 0.5 elseif estilo == "ruinas" then 0.6 else 0.25)
				Estructuras.choza(rng, cf, m, hundida)
				if rng:NextNumber() < 0.6 then
					Aldea.puertaRota(rng, cf * CFrame.new(0, 0, -9), m)
				end
				if estilo == "ladera" and rng:NextNumber() < 0.75 then
					Aldea.lianas(rng, p + Vector3.yAxis * 13, p.Y, m)
				end
			end
			local q = cf * CFrame.new(5.5, 0, -9)
			Estructuras.antorcha(rng, CFrame.new(suelo(datos, q.X, q.Z)), m)
		end
	end

	-- hamacas en la aldea de ladera
	if estilo == "ladera" then
		for _ = 1, 3 do
			local p = buscar(18, radio - 10, 5)
			if p then
				local giro = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				local a, b = (giro * CFrame.new(-3.4, 0, 0)).Position, (giro * CFrame.new(3.4, 0, 0)).Position
				Aldea.hamaca(rng, suelo(datos, a.X, a.Z), suelo(datos, b.X, b.Z), m)
			end
		end
	end

	-- lo que dejaron al huir
	for _ = 1, 6 do
		local p = buscar(10, radio - 6, 3)
		if p then
			Aldea.enseres(rng, CFrame.new(p), m)
		end
	end

	-- palafitos sobre el lago negro, del lado de la aldea, con pasarelas hasta la orilla
	if lago then
		local base = math.atan2(lago.fuera.Y, lago.fuera.X)
		local n = 4
		for k = 0, n - 1 do
			local a = base + (k - (n - 1) / 2) * 0.55
			local dir = Vector2.new(math.cos(a), math.sin(a))
			local pos = lago.centro + dir * math.max(10, lago.radio - 22)
			local frente = Vector3.new(dir.X, 0, dir.Y)
			local agua = Vector3.new(pos.X, lago.nivel, pos.Y)
			local lecho = datos.altura(pos.X, pos.Y)
			Aldea.palafito(rng, CFrame.lookAt(agua, agua + frente), lecho, m, k == 1 or rng:NextNumber() < 0.2)
			local orilla = lago.centro + dir * (lago.radio + 3)
			local desde = Vector3.new(orilla.X, lago.nivel + 2.5, orilla.Y)
			local hasta = agua + frente * 12 + Vector3.yAxis * 2.5
			Aldea.pasarela(rng, desde, hasta, lago.nivel - 6, m, k % 2 == 1)
		end
		Atmosfera.sonido(
			m,
			Vector3.new(lago.centro.X, lago.nivel + 2, lago.centro.Y),
			Config.Mapa.Agua.Sonidos.Pantano,
			30,
			260
		)
	end

	-- antorchas alrededor del centro y leña apilada
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		local x, z = centro.X + math.cos(a) * 18, centro.Z + math.sin(a) * 18
		if libreEn(x, z, 1) then
			Estructuras.antorcha(rng, CFrame.new(suelo(datos, x, z)), m)
		end
	end
	for _ = 1, 2 do
		local p = buscar(16, 26, 4)
		if p then
			Estructuras.troncosApilados(rng, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), m)
		end
	end

	-- vallas rotas (podridas en la ladera) en tramos del perímetro, sin cortar senderos
	for _ = 1, if estilo == "ladera" then 5 else 3 do
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
		if
			not sobreCamino(datos, x, z, 3)
			and not (lago and (Vector2.new(x, z) - lago.centro).Magnitude < lago.radio + 3)
		then
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

-- Templo de la Serpiente: la escalera mira hacia `hacia` (por donde llega el sendero) y una
-- niebla espesa lo envuelve.
function Zonas.templo(rng: Random, centro: Vector3, hacia: Vector2, datos: Terreno.Datos, padre: Instance): Model
	local m = Kit.modelo("Templo", padre)
	local p = suelo(datos, centro.X, centro.Z)
	local dir = Vector3.new(hacia.X, 0, hacia.Y).Unit
	Culto.templo(rng, CFrame.lookAt(p, p + dir), m)
	Atmosfera.niebla(m, p + dir * 70, 70, true)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + 0.6
		Atmosfera.niebla(m, suelo(datos, p.X + math.cos(a) * 80, p.Z + math.sin(a) * 80), 60, true)
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
	Helicoptero.construir(rng, en(0, 0), m, true)
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
