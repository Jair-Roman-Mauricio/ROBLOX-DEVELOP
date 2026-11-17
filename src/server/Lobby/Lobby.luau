--!strict
--[[
	Lobby: plataforma industrial de acero en alta mar, con 4 helipuertos. Cada vuelo lleva a un
	equipo de hasta 4 jugadores a una selva nueva.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Helicoptero = require(script.Parent.Parent.Modelos.Helicoptero)
local Kit = require(script.Parent.Parent.Modelos.Kit)
local Plataforma = require(script.Parent.Parent.Modelos.Plataforma)

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
	titulo.Font = Enum.Font.GothamBold
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
		M.DiamondPlate,
		{ forma = Enum.PartType.Cylinder }
	)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = (cf * CFrame.new(math.cos(a) * (R - 1), 0, math.sin(a) * (R - 1))).Position
		Kit.cilindro(m, p - Vector3.new(0, 40, 0), p, 1.2, Color3.fromRGB(65, 78, 86), M.Metal)
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
function Lobby.construir(): Lobby
	local rng = Random.new(20261113)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Lobby"
	carpeta.Parent = workspace
	local c = L.CENTRO
	Plataforma.construir(c, carpeta)
	local portales: { Portal } = {}
	-- Dos alas laterales; los discos no se solapan y el radio de embarque queda
	-- separado de la zona de llegada. El helicóptero conserva Interior, Rotor y Puerta.
	for i = 1, L.VUELOS do
		local x = if i <= 2 then -70 else 70
		local z = if i % 2 == 1 then -28 else 28
		local centro = c + Vector3.new(x, -1.4, z)
		local entrada = c + Vector3.new(if x < 0 then -34 else 34, 0, z)
		local borde = c + Vector3.new(if x < 0 then -55 else 55, 0, z)
		Plataforma.pasarela(carpeta, entrada, borde)
		table.insert(portales, helipuerto(rng, i, centro, c + Vector3.new(0, 0, z), carpeta))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLobby"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(c + Vector3.new(0, 1.5, 7), c + Vector3.new(0, 1.5, -20))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = carpeta
	-- Sincroniza con ReplicatedFirst: la carga no termina a mitad de la construcción.
	carpeta:SetAttribute("Listo", true)
	return { carpeta = carpeta, spawn = spawn, portales = portales }
end

return Lobby
