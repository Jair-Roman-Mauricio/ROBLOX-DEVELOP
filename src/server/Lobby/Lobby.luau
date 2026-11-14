--!strict
--[[
	Lobby: base de expediciones al atardecer, en el borde de la selva.
	Plaza central con fogata y cartel, y 4 helipuertos (los "portales"): cada uno lleva a un
	equipo de hasta 4 jugadores a una selva nueva.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Campamento = require(script.Parent.Parent.Modelos.Campamento)
local Estructuras = require(script.Parent.Parent.Modelos.Estructuras)
local Helicoptero = require(script.Parent.Parent.Modelos.Helicoptero)
local Kit = require(script.Parent.Parent.Modelos.Kit)
local Vegetacion = require(script.Parent.Parent.Modelos.Vegetacion)

local L = Config.Lobby
local M = Enum.Material

export type Portal = {
	indice: number,
	modelo: Model,
	centro: Vector3,
	lamparas: { BasePart },
	titulo: TextLabel,
	estado: TextLabel,
}

export type Lobby = {
	carpeta: Folder,
	spawn: SpawnLocation,
	portales: { Portal },
}

local Lobby = {}

local CREMA = Color3.fromRGB(244, 232, 206)
local AMBAR = Color3.fromRGB(255, 176, 70)

local function diferencia(a: number, b: number): number
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

local function cartelFlotante(padre: BasePart, indice: number): (TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Cartel"
	gui.Size = UDim2.fromOffset(280, 96)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Parent = padre

	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.BackgroundTransparency = 1
	titulo.Size = UDim2.fromScale(1, 0.55)
	titulo.Font = Enum.Font.Merriweather
	titulo.TextScaled = true
	titulo.TextColor3 = CREMA
	titulo.TextStrokeTransparency = 0.6
	titulo.Text = ("VUELO %d"):format(indice)
	titulo.Parent = gui

	local estado = Instance.new("TextLabel")
	estado.Name = "Estado"
	estado.BackgroundTransparency = 1
	estado.Position = UDim2.fromScale(0, 0.58)
	estado.Size = UDim2.fromScale(1, 0.36)
	estado.Font = Enum.Font.GothamMedium
	estado.TextScaled = true
	estado.TextColor3 = AMBAR
	estado.TextStrokeTransparency = 0.7
	estado.Text = ""
	estado.Parent = gui
	return titulo, estado
end

local function helipuerto(rng: Random, indice: number, centro: Vector3, mirar: Vector3, padre: Instance): Portal
	local m = Kit.modelo(("Vuelo%d"):format(indice), padre)
	local cf = CFrame.lookAt(centro, Vector3.new(mirar.X, centro.Y, mirar.Z))
	local R = L.RADIO_HELIPUERTO

	-- plataforma sobre pilotes
	Kit.parte(
		m,
		cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(1.4, R * 2 + 2, R * 2 + 2),
		Color3.fromRGB(66, 68, 70),
		M.Concrete,
		{ forma = Enum.PartType.Cylinder }
	)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = (cf * CFrame.new(math.cos(a) * (R - 1), 0, math.sin(a) * (R - 1))).Position
		Kit.cilindro(m, p - Vector3.new(0, 6, 0), p, 1.2, Color3.fromRGB(96, 74, 52), M.Wood)
	end
	-- anillo y "H"
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		Kit.parte(
			m,
			cf * CFrame.new(math.cos(a) * 9.5, 1.42, math.sin(a) * 9.5) * CFrame.Angles(0, -a, 0),
			Vector3.new(0.7, 0.06, 2.1),
			Color3.fromRGB(230, 190, 60),
			M.SmoothPlastic,
			Kit.FOLLAJE
		)
	end
	local blanco = Color3.fromRGB(235, 232, 220)
	Kit.parte(m, cf * CFrame.new(-3, 1.42, 0), Vector3.new(1.4, 0.06, 9), blanco, M.SmoothPlastic, Kit.FOLLAJE)
	Kit.parte(m, cf * CFrame.new(3, 1.42, 0), Vector3.new(1.4, 0.06, 9), blanco, M.SmoothPlastic, Kit.FOLLAJE)
	Kit.parte(m, cf * CFrame.new(0, 1.42, 0), Vector3.new(6, 0.06, 1.4), blanco, M.SmoothPlastic, Kit.FOLLAJE)
	-- luces del borde
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		Kit.parte(
			m,
			cf * CFrame.new(math.cos(a) * R, 1.6, math.sin(a) * R),
			Vector3.new(0.6, 0.4, 0.6),
			AMBAR,
			M.Neon,
			{ colision = false, consulta = false, sombra = false }
		)
	end
	-- 4 lámparas de plaza ocupada, delante del helicóptero
	local lamparas = {}
	for k = 1, Config.MAX_POR_EQUIPO do
		local x = (k - (Config.MAX_POR_EQUIPO + 1) / 2) * 3
		local lampara = Kit.parte(
			m,
			cf * CFrame.new(x, 1.6, -R + 2.5),
			Vector3.new(1.8, 0.35, 1.8),
			Color3.fromRGB(50, 52, 54),
			M.SmoothPlastic,
			{ colision = false, sombra = false, nombre = ("Plaza%d"):format(k) }
		)
		table.insert(lamparas, lampara)
	end

	-- morro hacia la plaza; la cola sobresale por detrás de la plataforma
	local heli = Helicoptero.construir(rng, cf * CFrame.new(0, 1.4, 0), m, false)
	local rotor = heli:FindFirstChild("Rotor")
	if rotor then
		Kit.etiquetar(rotor, "RotorLobby")
	end
	local cola = heli:FindFirstChild("RotorCola")
	if cola then
		Kit.etiquetar(cola, "RotorColaLobby")
	end
	local foco = Kit.parte(m, cf * CFrame.new(0, 7, -R - 1), Vector3.one * 0.6, AMBAR, M.Neon, Kit.FOLLAJE)
	Kit.luz(foco, Color3.fromRGB(255, 200, 140), 34, 1.6)

	local ancla = Kit.parte(m, cf * CFrame.new(0, 17, 0), Vector3.one, Color3.new(), M.SmoothPlastic, {
		transparencia = 1,
		colision = false,
		consulta = false,
		nombre = "AnclaCartel",
	})
	local titulo, estado = cartelFlotante(ancla, indice)
	m:SetAttribute("Jugadores", 0)
	m:SetAttribute("Cuenta", -1)
	return {
		indice = indice,
		modelo = m,
		centro = centro + Vector3.new(0, 1.4, 0),
		lamparas = lamparas,
		titulo = titulo,
		estado = estado,
	}
end

-- Hilera de bombillas colgando entre dos postes.
local function guirnalda(desde: Vector3, hasta: Vector3, padre: Instance)
	local cable = Color3.fromRGB(30, 28, 26)
	local n = 7
	local prev = desde
	for i = 1, n do
		local t = i / n
		local p = desde:Lerp(hasta, t) - Vector3.new(0, math.sin(math.pi * t) * 1.6, 0)
		Kit.cilindro(padre, prev, p, 0.08, cable, M.SmoothPlastic, Kit.FOLLAJE)
		if i < n then
			Kit.parte(
				padre,
				CFrame.new(p - Vector3.new(0, 0.35, 0)),
				Vector3.one * 0.5,
				Color3.fromRGB(255, 214, 150),
				M.Neon,
				{ forma = Enum.PartType.Ball, colision = false, consulta = false, sombra = false }
			)
		end
		prev = p
	end
end

local function cartelPrincipal(cf: CFrame, padre: Instance)
	local m = Kit.modelo("Cartel", padre)
	local madera = Color3.fromRGB(96, 74, 52)
	for _, x in { -6, 6 } do
		Kit.cilindro(m, (cf * CFrame.new(x, -1, 0)).Position, (cf * CFrame.new(x, 10, 0)).Position, 0.8, madera, M.Wood)
	end
	local tablero =
		Kit.parte(m, cf * CFrame.new(0, 6.5, 0), Vector3.new(13, 6, 0.5), Color3.fromRGB(70, 52, 38), M.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = tablero
	local function texto(t: string, y: number, alto: number, fuente: Enum.Font, color: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, alto)
		l.Font = fuente
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = t
		l.Parent = gui
	end
	texto("SELVA", 0.06, 0.42, Enum.Font.Merriweather, CREMA)
	texto("EXPEDICIONES AMAZONAS", 0.5, 0.14, Enum.Font.GothamMedium, AMBAR)
	texto(
		"Acércate a un helicóptero con tu equipo (máx. 4). El vuelo despega solo.",
		0.7,
		0.2,
		Enum.Font.GothamMedium,
		CREMA
	)
end

function Lobby.construir(): Lobby
	local rng = Random.new(20261113)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Lobby"
	carpeta.Parent = workspace
	local c = L.CENTRO
	local terreno = workspace.Terrain

	-- suelo: claro de hierba rodeado de colinas
	terreno:FillCylinder(CFrame.new(c - Vector3.new(0, 10, 0)), 20, L.RADIO_LIMITE + 60, M.LeafyGrass)
	terreno:FillCylinder(CFrame.new(c - Vector3.new(0, 1.5, 0)), 3, 46, M.Ground)
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2
		local r = L.RADIO_LIMITE + rng:NextNumber(20, 45)
		terreno:FillBall(
			c + Vector3.new(math.cos(a) * r, rng:NextNumber(-6, 4), math.sin(a) * r),
			rng:NextNumber(26, 40),
			if i % 3 == 0 then M.Rock else M.LeafyGrass
		)
	end
	-- cordillera lejana: horizonte para la cinemática del despegue
	for i = 1, 16 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / 16 * math.pi * 2
		local r = rng:NextNumber(330, 430)
		terreno:FillBall(
			c + Vector3.new(math.cos(a) * r, rng:NextNumber(-60, -25), math.sin(a) * r),
			rng:NextNumber(70, 110),
			if i % 2 == 0 then M.Rock else M.LeafyGrass
		)
	end
	local suelo = (Kit.suelo(c.X, c.Z) or c).Y
	local plaza = Vector3.new(c.X, suelo, c.Z)

	-- laguna al sur, detrás del punto de aparición
	local laguna = plaza + Vector3.new(0, 0, 108)
	local RADIO_LAGUNA = 30
	local nivelAgua = suelo - 1
	terreno:FillCylinder(CFrame.new(laguna + Vector3.new(0, 2, 0)), 6, RADIO_LAGUNA, M.Air)
	terreno:FillCylinder(CFrame.new(laguna - Vector3.new(0, 4, 0)), 6, RADIO_LAGUNA, M.Water)
	terreno:FillCylinder(CFrame.new(laguna - Vector3.new(0, 7.5, 0)), 1, RADIO_LAGUNA + 4, M.Mud)

	-- plaza de madera
	Kit.parte(
		carpeta,
		CFrame.new(plaza + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(1, 64, 64),
		Color3.fromRGB(116, 90, 62),
		M.WoodPlanks,
		{ forma = Enum.PartType.Cylinder }
	)
	Estructuras.fogon(rng, CFrame.new(plaza + Vector3.new(0, 1, 0)), carpeta, true)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.3
		local centro = plaza + Vector3.new(math.cos(a) * 7.5, 1.7, math.sin(a) * 7.5)
		local tangente = Vector3.new(-math.sin(a), 0, math.cos(a))
		Kit.cilindro(
			carpeta,
			centro - tangente * 2.6,
			centro + tangente * 2.6,
			1.6,
			Kit.variar(Color3.fromRGB(104, 78, 54), rng, 0.05),
			M.Wood
		)
	end
	-- arco de entrada al sur, de cara a la plaza, sobre la pasarela que baja al muelle
	cartelPrincipal(CFrame.lookAt(plaza + Vector3.new(0, 1, 37), plaza + Vector3.new(0, 1, 0)), carpeta)

	-- postes con guirnaldas y faroles
	local postes = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		local base = plaza + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
		Kit.cilindro(
			carpeta,
			base - Vector3.new(0, 1, 0),
			base + Vector3.new(0, 10, 0),
			0.6,
			Color3.fromRGB(96, 74, 52),
			M.Wood
		)
		table.insert(postes, base + Vector3.new(0, 9.6, 0))
		if i % 2 == 0 then
			local farol = Kit.parte(
				carpeta,
				CFrame.new(base + Vector3.new(0, 10.6, 0)),
				Vector3.new(0.9, 1.2, 0.9),
				Color3.fromRGB(255, 200, 120),
				M.Neon,
				Kit.FOLLAJE
			)
			Kit.luz(farol, Color3.fromRGB(255, 190, 120), 30, 1.4)
		end
	end
	for i = 1, #postes do
		guirnalda(postes[i], postes[i % #postes + 1], carpeta)
	end

	-- helipuertos en arco al norte de la plaza
	local portales = {}
	local angulos = { -66, -22, 22, 66 }
	for i = 1, L.VUELOS do
		local a = math.rad(angulos[(i - 1) % #angulos + 1])
		local centro = plaza + Vector3.new(math.sin(a) * 74, 0, -math.cos(a) * 74)
		table.insert(portales, helipuerto(rng, i, centro, plaza, carpeta))
		-- pasarela de tablones desde la plaza
		local dir = (centro - plaza).Unit
		local desde = plaza + dir * 31 + Vector3.new(0, 0.6, 0)
		local hasta = centro - dir * (L.RADIO_HELIPUERTO + 1) + Vector3.new(0, 1.2, 0)
		Kit.viga(carpeta, desde, hasta, 7, 0.5, Color3.fromRGB(122, 94, 62), M.WoodPlanks)
		local lado = Vector3.new(dir.Z, 0, -dir.X)
		local pie = Vector3.new(0, 1.2, 0)
		Estructuras.barril(rng, CFrame.new(hasta - pie + lado * 6), carpeta)
		Estructuras.pilaCajas(rng, CFrame.new(hasta - pie - lado * 7), carpeta)
		local baseFarol = desde:Lerp(hasta, 0.5) - Vector3.new(0, 0.8, 0) + lado * 4.6
		Campamento.farol(CFrame.lookAt(baseFarol, baseFarol + dir), carpeta)
	end

	-- barandilla de la plaza con huecos en las pasarelas y en la salida sur
	local huecos = { math.pi / 2 }
	for _, portal in portales do
		local d = portal.centro - plaza
		table.insert(huecos, math.atan2(d.Z, d.X))
	end
	local function abierto(a: number): boolean
		for _, h in huecos do
			if math.abs(diferencia(a, h)) < 0.14 then
				return true
			end
		end
		return false
	end
	local madera = Color3.fromRGB(104, 80, 56)
	local N = 56
	for i = 0, N - 1 do
		local a, b = i / N * math.pi * 2, (i + 1) / N * math.pi * 2
		local pa = plaza + Vector3.new(math.cos(a) * 32.4, 0, math.sin(a) * 32.4)
		local pb = plaza + Vector3.new(math.cos(b) * 32.4, 0, math.sin(b) * 32.4)
		if not abierto(a) then
			Kit.cilindro(carpeta, pa, pa + Vector3.new(0, 3.4, 0), 0.4, madera, M.Wood)
			if not abierto(b) then
				Kit.cilindro(carpeta, pa + Vector3.new(0, 3.1, 0), pb + Vector3.new(0, 3.1, 0), 0.3, madera, M.Wood)
				Kit.cilindro(carpeta, pa + Vector3.new(0, 1.8, 0), pb + Vector3.new(0, 1.8, 0), 0.22, madera, M.Wood)
			end
		end
	end

	-- base de operaciones: torre entre los helipuertos centrales, pabellón, jeep, combustible y muelle
	local objetivos = {}
	for _, portal in portales do
		table.insert(objetivos, portal.centro + Vector3.new(0, 2, 0))
	end
	local torre = plaza + Vector3.new(0, 0, -50)
	Campamento.torre(CFrame.lookAt(torre, plaza), carpeta, objetivos)
	local pabellon = plaza + Vector3.new(-72, 0, 34)
	Campamento.pabellon(rng, CFrame.lookAt(pabellon, plaza), carpeta)
	Campamento.jeep(CFrame.lookAt(plaza + Vector3.new(50, 0, 44), plaza + Vector3.new(30, 0, 20)), carpeta)
	local deposito = plaza + Vector3.new(80, 0, 10)
	Campamento.combustible(rng, CFrame.lookAt(deposito, plaza), carpeta)
	local orilla = laguna + Vector3.new(0, 0, -RADIO_LAGUNA - 3)
	Kit.viga(
		carpeta,
		plaza + Vector3.new(0, 0.6, 32),
		orilla + Vector3.new(0, 0.6, 0),
		6,
		0.5,
		Color3.fromRGB(122, 94, 62),
		M.WoodPlanks
	)
	Campamento.muelle(rng, CFrame.lookAt(orilla, Vector3.new(orilla.X, orilla.Y, laguna.Z)), 20, nivelAgua, carpeta)
	Campamento.canoa(
		rng,
		CFrame.new(laguna + Vector3.new(-9, nivelAgua - suelo - 0.5, -12)) * CFrame.Angles(0, 0.4, 0),
		carpeta
	)
	Campamento.canoa(
		rng,
		CFrame.new(laguna + Vector3.new(14, nivelAgua - suelo - 0.5, -4)) * CFrame.Angles(0, -0.2, 0),
		carpeta
	)

	-- rocas en la orilla de la laguna, dejando libre el muelle
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		if math.abs(diferencia(a, -math.pi / 2)) > 0.3 then
			local r = RADIO_LAGUNA + rng:NextNumber(0, 3)
			local p = Kit.suelo(laguna.X + math.cos(a) * r, laguna.Z + math.sin(a) * r)
			if p then
				Vegetacion.roca(rng, p, carpeta)
			end
		end
	end

	-- tiendas del campamento
	Estructuras.lona(rng, CFrame.lookAt(plaza + Vector3.new(36, 0, 22), plaza), carpeta, Color3.fromRGB(150, 120, 60))
	Estructuras.lona(rng, CFrame.lookAt(plaza + Vector3.new(-38, 0, 26), plaza), carpeta)

	-- selva alrededor, sin tapar helipuertos ni el camino de entrada
	local veg = Instance.new("Folder")
	veg.Name = "Vegetacion"
	veg.Parent = carpeta
	local ocupado: { { centro: Vector3, radio: number } } = {
		{ centro = torre, radio = 12 },
		{ centro = pabellon, radio = 24 },
		{ centro = deposito, radio = 14 },
		{ centro = laguna, radio = RADIO_LAGUNA + 6 },
		{ centro = plaza + Vector3.new(50, 0, 44), radio = 10 },
	}
	local function libre(p: Vector3): boolean
		for _, portal in portales do
			if
				(Vector3.new(p.X, 0, p.Z) - Vector3.new(portal.centro.X, 0, portal.centro.Z)).Magnitude
				< L.RADIO_HELIPUERTO + 16
			then
				return false
			end
		end
		for _, zona in ocupado do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(zona.centro.X, 0, zona.centro.Z)).Magnitude < zona.radio then
				return false
			end
		end
		return (p - plaza).Magnitude > 48
	end
	for _ = 1, 420 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(50, L.RADIO_LIMITE + 30)
		local x, z = plaza.X + math.cos(a) * r, plaza.Z + math.sin(a) * r
		local p = Kit.suelo(x, z)
		if p and libre(p) then
			local tipo = rng:NextNumber()
			if r > 95 and tipo < 0.55 then
				local crear: (Random, Vector3, Instance) -> Model = if tipo < 0.05
					then Vegetacion.ceiba
					elseif tipo < 0.3 then Vegetacion.palmera
					else Vegetacion.arbol
				crear(rng, p, veg)
			elseif tipo < 0.75 then
				Vegetacion.helecho(rng, p, veg)
			else
				Vegetacion.hojaGrande(rng, p, veg)
			end
		end
	end

	-- límite invisible
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		local p = plaza + Vector3.new(math.cos(a) * L.RADIO_LIMITE, 30, math.sin(a) * L.RADIO_LIMITE)
		Kit.parte(
			carpeta,
			CFrame.lookAt(p, Vector3.new(plaza.X, p.Y, plaza.Z)),
			Vector3.new(42, 120, 2),
			Color3.new(),
			M.SmoothPlastic,
			{
				transparencia = 1,
				sombra = false,
				consulta = false,
			}
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLobby"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(plaza + Vector3.new(0, 1.2, 22), plaza + Vector3.new(0, 1.2, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = carpeta

	return { carpeta = carpeta, spawn = spawn, portales = portales }
end

return Lobby
