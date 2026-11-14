--!strict
--[[
	Iluminación local según dónde está el jugador (lobby al atardecer, selva de noche).
	La aplica cada cliente: así el lobby y la partida conviven en el mismo servidor y la
	hora no depende de la réplica de ClockTime (baúl: Lighting Mood and Time of Day).
	También coloca luciérnagas y niebla baja alrededor de la cámara.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Ambiente = {}

local function asegurar(clase: string, nombre: string?): Instance
	local existente = if nombre then Lighting:FindFirstChild(nombre) else Lighting:FindFirstChildOfClass(clase)
	if existente then
		return existente
	end
	local nuevo = Instance.new(clase)
	if nombre then
		nuevo.Name = nombre
	end
	nuevo.Parent = Lighting
	return nuevo
end

local function emisor(nombre: string, tam: Vector3): (BasePart, ParticleEmitter)
	local parte = Instance.new("Part")
	parte.Name = nombre
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Transparency = 1
	parte.Size = tam
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Parent = parte
	parte.Parent = workspace.CurrentCamera
	return parte, e
end

function Ambiente.iniciar()
	local jugador = Players.LocalPlayer
	local atmosfera = asegurar("Atmosphere") :: Atmosphere
	local bloom = asegurar("BloomEffect", "SelvaBloom") :: BloomEffect
	local color = asegurar("ColorCorrectionEffect", "SelvaColor") :: ColorCorrectionEffect
	local cielo = asegurar("Sky") :: Sky
	cielo.StarCount = 3000
	cielo.MoonAngularSize = 14
	cielo.SunAngularSize = 16

	local zonaLuciernagas, luciernagas = emisor("Luciernagas", Vector3.new(120, 26, 120))
	luciernagas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	luciernagas.Color = ColorSequence.new(Color3.fromRGB(210, 255, 120), Color3.fromRGB(255, 230, 120))
	luciernagas.LightEmission = 1
	luciernagas.LightInfluence = 0
	luciernagas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.22),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	luciernagas.Lifetime = NumberRange.new(5, 9)
	luciernagas.Speed = NumberRange.new(0.3, 1.2)
	luciernagas.SpreadAngle = Vector2.new(180, 180)
	luciernagas.RotSpeed = NumberRange.new(-40, 40)
	luciernagas.Acceleration = Vector3.new(0, 0.08, 0)

	local zonaNiebla, niebla = emisor("NieblaBaja", Vector3.new(160, 6, 160))
	niebla.Texture = "rbxasset://textures/particles/smoke_main.dds"
	niebla.Color = ColorSequence.new(Color3.fromRGB(190, 205, 215))
	niebla.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	niebla.Size = NumberSequence.new(18, 30)
	niebla.Lifetime = NumberRange.new(10, 16)
	niebla.Speed = NumberRange.new(0.3, 0.8)
	niebla.SpreadAngle = Vector2.new(180, 0)
	niebla.Rotation = NumberRange.new(0, 360)
	niebla.RotSpeed = NumberRange.new(-6, 6)

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			local p = cam.CFrame.Position
			zonaLuciernagas.CFrame = CFrame.new(p + Vector3.new(0, 4, 0))
			zonaNiebla.CFrame = CFrame.new(p - Vector3.new(0, 7, 0))
		end
	end)

	local tweens: { Tween } = {}
	local actual = ""

	local function aplicar(nombre: string, segundos: number)
		if nombre == actual then
			return
		end
		actual = nombre
		local preset = (Config.Iluminacion :: any)[nombre]
		for _, t in tweens do
			t:Cancel()
		end
		table.clear(tweens)
		local function ir(objeto: Instance, props: { [string]: any })
			if segundos <= 0 then
				for k, v in props do
					(objeto :: any)[k] = v
				end
			else
				local t = TweenService:Create(objeto, TweenInfo.new(segundos, Enum.EasingStyle.Sine), props)
				t:Play()
				table.insert(tweens, t)
			end
		end
		ir(Lighting, preset.Lighting)
		ir(atmosfera, preset.Atmosphere)
		ir(bloom, preset.Bloom)
		ir(color, preset.Color)
		luciernagas.Rate = preset.Luciernagas
		niebla.Rate = preset.Niebla
	end

	local function actualizar()
		local zona = jugador:GetAttribute("Zona")
		if zona == "Partida" then
			aplicar("Noche", 0)
		elseif zona == "Lobby" then
			aplicar("Lobby", 0)
		end
	end
	jugador:GetAttributeChangedSignal("Zona"):Connect(actualizar)
	aplicar("Lobby", 0)
	actualizar()
end

return Ambiente
