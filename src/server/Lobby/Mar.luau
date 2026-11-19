--!strict
--[[
	Mar de tormenta alrededor de la plataforma (versión Roblox de ocean.blend, docs/PLATAFORMA.md).

	- Agua de terreno en un cuadrado de 2 * RADIO studs con el nivel del mar en CENTRO.Y: olas,
	  reflejos y nado de verdad. El color y el oleaje los pone cada cliente (Config.Iluminacion
	  .Lobby.Agua) porque el agua del terreno es una sola para el lobby y la selva.
	- Un plano oscuro hasta el horizonte, fuera del agua de terreno; la neblina lo funde.
	- En cada pata: espuma que se apila alrededor, rociones del lado del viento a golpes, niebla
	  baja y el ruido de las olas al romper.
	- Quien cae al mar vuelve a la cubierta.

	El lobby está en z = 6000, lejos del mapa de la selva: Terreno.limpiar no toca este agua.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Modelos.Kit)

local L = Config.Lobby
local MAR = L.Mar
-- medio lado de la selva más un margen: ahí no se pone horizonte
local SELVA = Config.Mapa.TAMANO / 2 + 1024
local P = L.Plataforma

local HUMO = "rbxasset://textures/particles/smoke_main.dds"
local GOTAS = "rbxasset://textures/particles/sparkles_main.dds"
local OLAS_PATA = 9117143192 -- "Ocean Surf 1"

local Mar = {}

local function emisor(padre: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = padre
	return e
end

local function ancla(padre: Instance, nombre: string, cf: CFrame, tam: Vector3): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.CFrame = cf
	p.Size = tam
	p.Parent = padre
	return p
end

local function agua(c: Vector3)
	local terreno = workspace.Terrain
	local bloque = 512
	for x = -MAR.RADIO, MAR.RADIO - 1, bloque do
		for z = -MAR.RADIO, MAR.RADIO - 1, bloque do
			terreno:FillBlock(
				CFrame.new(c.X + x + bloque / 2, c.Y - MAR.PROFUNDIDAD / 2, c.Z + z + bloque / 2),
				Vector3.new(bloque, MAR.PROFUNDIDAD, bloque),
				Enum.Material.Water
			)
		end
		task.wait()
	end
end

local function horizonte(c: Vector3, padre: Instance)
	local m = Kit.modelo("Horizonte", padre)
	local tam = 1024
	local n = math.ceil(MAR.HORIZONTE / tam)
	for i = -n, n do
		for j = -n, n do
			local cx, cz = i * tam, j * tam
			-- solo fuera del agua de terreno, y nunca sobre la selva: el horizonte llega a 9000 studs
			-- y la selva está a 6000 del lobby; a la altura del mar tapaba los valles con una lámina
			-- de "agua" sin física que se atravesaba (el claro inicial salía inundado)
			local mundo = c + Vector3.new(cx, 0, cz)
			local sobreSelva = math.abs(mundo.X) < SELVA + tam / 2 and math.abs(mundo.Z) < SELVA + tam / 2
			if not sobreSelva and (math.abs(cx) + tam / 2 > MAR.RADIO or math.abs(cz) + tam / 2 > MAR.RADIO) then
				Kit.parte(
					m,
					CFrame.new(c + Vector3.new(cx, -0.3, cz)),
					Vector3.new(tam, 0.3, tam),
					Color3.fromRGB(20, 44, 54),
					Enum.Material.SmoothPlastic,
					{ colision = false, consulta = false, sombra = false, reflejo = 0.35, nombre = "Mar" }
				)
			end
		end
	end
end

-- Espuma, rociones, niebla y olas en una pata. `viento`: hacia dónde van las olas.
local function pata(padre: Instance, pie: Vector3, radio: number, viento: Vector3)
	local m = Kit.modelo("Pata", padre)
	-- a tamaño real la pata mide ~21 studs de radio; los rociones suben menos si la plataforma
	-- es más pequeña (la altura va con el cuadrado de la velocidad)
	local f = math.sqrt(radio / (6 / 0.28))
	-- espuma: manchas planas alrededor, más largas río abajo del viento
	local espuma = ancla(m, "Espuma", CFrame.new(pie + viento * radio * 0.6), Vector3.new(radio * 3, 1, radio * 3))
	emisor(espuma, {
		Texture = HUMO,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(Color3.fromRGB(225, 232, 235)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(10, 22),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.2, 0.6),
		Acceleration = viento * 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8),
		LightInfluence = 0.6,
		Rate = 14,
	})
	-- rociones: del lado de donde viene el viento, a golpes
	local golpe = ancla(
		m,
		"Rocion",
		CFrame.lookAt(pie - viento * radio, pie - viento * radio + Vector3.yAxis),
		Vector3.new(radio * 1.6, 2, radio * 0.6)
	)
	local gotas = emisor(golpe, {
		Texture = GOTAS,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(22, 22),
		Color = ColorSequence.new(Color3.fromRGB(235, 242, 245)),
		Size = NumberSequence.new(0.9, 0.3),
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(45 * f, 90 * f),
		Acceleration = Vector3.new(0, -80, 0) + viento * 18,
		Drag = 0.4,
		LightInfluence = 0.7,
		Rate = 0,
	})
	local bruma = emisor(golpe, {
		Texture = HUMO,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Color = ColorSequence.new(Color3.fromRGB(210, 220, 226)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(8, 26),
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(20 * f, 40 * f),
		Acceleration = Vector3.new(0, -12, 0) + viento * 14,
		Drag = 1,
		LightInfluence = 0.7,
		Rate = 0,
	})
	-- niebla baja pegada al agua
	local base = ancla(m, "Niebla", CFrame.new(pie + Vector3.yAxis * 4), Vector3.new(radio * 4, 6, radio * 4))
	emisor(base, {
		Texture = HUMO,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(Color3.fromRGB(196, 206, 214)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(30, 50),
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(1, 3),
		Acceleration = viento * 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-4, 4),
		Rate = 2,
	})
	local olas = Instance.new("Sound")
	olas.SoundId = "rbxassetid://" .. OLAS_PATA
	olas.Looped = true
	olas.Volume = 0.7
	olas.RollOffMinDistance = 40
	olas.RollOffMaxDistance = 420
	olas.Parent = espuma
	olas:Play()

	-- cada ola que llega revienta contra la pata: un golpe de rociones de medio segundo
	task.spawn(function()
		local rng = Random.new()
		task.wait(rng:NextNumber(0, 3))
		while m.Parent do
			local fuerza = rng:NextNumber(0.6, 1)
			gotas.Rate = 260 * fuerza
			bruma.Rate = 30 * fuerza
			task.wait(rng:NextNumber(0.35, 0.6))
			gotas.Rate = 0
			bruma.Rate = 0
			task.wait(rng:NextNumber(2.2, 4.5))
		end
	end)
end

-- `punto` pasa de metros del modelo original a studs del mundo (nil con la plataforma de respaldo).
function Mar.crear(c: Vector3, padre: Instance, punto: ((Vector3) -> Vector3)?, studsPorMetro: number?)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Mar"
	carpeta.Parent = padre
	agua(c)
	horizonte(c, carpeta)
	if punto and studsPorMetro then
		local a = math.rad(P.VIENTO)
		local viento = (punto(Vector3.new(math.cos(a), math.sin(a), 0)) - punto(Vector3.zero)).Unit
		for _, p in P.PATAS do
			pata(carpeta, punto(Vector3.new(p.X, p.Y, 0)), P.RADIO_PATA * studsPorMetro, viento)
		end
	end
end

-- Quien cae al agua cerca del lobby vuelve a aparecer en la cubierta.
function Mar.rescatar(c: Vector3, destino: () -> CFrame)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, pl in Players:GetPlayers() do
				local raiz = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if
					pl:GetAttribute("Zona") == "Lobby"
					and raiz
					and raiz:IsA("BasePart")
					and raiz.Position.Y < c.Y + 4
					and (raiz.Position - c).Magnitude < MAR.RADIO + 200
				then
					(pl.Character :: Model):PivotTo(destino())
				end
			end
		end
	end)
end

return Mar
