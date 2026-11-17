--!strict
--[[
	Efectos de atmósfera colocados en el mundo (docs/SELVA-CULTO.md): bancos de niebla baja,
	haces de luna que entran por los huecos del dosel y la cascada.

	Baúl: Water Sky and Atmosphere Art (cascada = lámina escalonada + Beams con textura que se
	desplaza + espuma + niebla al pie) y VFX Performance Budgets and Culling (pocas partículas
	vivas: tasa baja y vida larga).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local AT = Config.Mapa.Atmosfera
local HUMO = "rbxasset://textures/particles/smoke_main.dds"
local GOTAS = "rbxasset://textures/particles/sparkles_main.dds"

local Atmosfera = {}

local function ancla(padre: Instance, nombre: string, cf: CFrame, tam: Vector3): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.CFrame = cf
	p.Size = tam
	p.Parent = padre
	return p
end

local function sonido(padre: Instance, s: { id: number, volumen: number }, minimo: number, maximo: number)
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://" .. s.id
	snd.Volume = s.volumen
	snd.Looped = true
	snd.RollOffMinDistance = minimo
	snd.RollOffMaxDistance = maximo
	snd.Parent = padre
	snd:Play()
end

-- Banco de niebla pegado al suelo o al agua. `espesa` para el templo.
function Atmosfera.niebla(padre: Instance, centro: Vector3, ancho: number, espesa: boolean?)
	local caja = ancla(padre, "Niebla", CFrame.new(centro + Vector3.yAxis * 3), Vector3.new(ancho, 6, ancho))
	local e = Instance.new("ParticleEmitter")
	e.Texture = HUMO
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = ColorSequence.new(Color3.fromRGB(150, 164, 172))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, if espesa then 0.72 else 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new(if espesa then 30 else 22, if espesa then 48 else 36)
	e.Lifetime = NumberRange.new(10, 16)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-3, 3)
	e.LightInfluence = 1
	e.Rate = math.clamp(ancho * ancho / (if espesa then 1800 else 4200), 1, 6)
	e.Parent = caja
end

-- Haz de luna fría que baja por un hueco del dosel hasta el suelo.
function Atmosfera.haz(padre: Instance, suelo: Vector3, rng: Random)
	local arriba = suelo + Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(95, 125), rng:NextNumber(-25, 25))
	local p = ancla(padre, "HazLuna", CFrame.new(suelo), Vector3.one)
	local a0 = Instance.new("Attachment")
	a0.WorldPosition = arriba
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.WorldPosition = suelo + Vector3.yAxis * 2
	a1.Parent = p
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Width0 = rng:NextNumber(10, 16)
	b.Width1 = rng:NextNumber(18, 28)
	b.Color = ColorSequence.new(AT.LUNA)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 0.6
	b.Texture = HUMO
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureSpeed = 0.02
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.94),
		NumberSequenceKeypoint.new(0.6, 0.86),
		NumberSequenceKeypoint.new(1, 0.97),
	})
	b.Segments = 2
	b.Parent = p
	-- polvo suspendido dentro del haz
	local motas = Instance.new("ParticleEmitter")
	motas.Texture = GOTAS
	motas.Shape = Enum.ParticleEmitterShape.Box
	motas.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motas.Color = ColorSequence.new(AT.LUNA)
	motas.LightEmission = 0.6
	motas.Size = NumberSequence.new(0.12)
	motas.Transparency = NumberSequence.new(0.4)
	motas.Lifetime = NumberRange.new(6, 9)
	motas.Speed = NumberRange.new(0.2, 0.5)
	motas.SpreadAngle = Vector2.new(180, 180)
	motas.Rate = 3
	local caja = ancla(p, "Motas", CFrame.new(suelo + Vector3.yAxis * 12), Vector3.new(10, 20, 10))
	motas.Parent = caja
end

-- Cascada: lámina escalonada, dos haces de agua que bajan, espuma y niebla al pie, sonido.
-- `pie` es el punto en la superficie del lago junto a la pared; `fuera` mira hacia la pared.
function Atmosfera.cascada(padre: Instance, pie: Vector3, fuera: Vector3, alto: number, rng: Random)
	local m = Kit.modelo("Cascada", padre)
	local frente = -fuera
	local cf = CFrame.lookAt(pie, pie + frente)
	local agua = Color3.fromRGB(150, 176, 186)
	-- lámina en tres tramos, cada uno un poco más adelante y más ancho (rebota en la roca)
	for k = 0, 2 do
		local y0, y1 = alto * (1 - (k + 1) / 3), alto * (1 - k / 3)
		Kit.parte(
			m,
			cf * CFrame.new(0, (y0 + y1) / 2, -0.6 - k * 0.9) * CFrame.Angles(-0.06, 0, 0),
			Vector3.new(6 + k * 1.5, y1 - y0 + 0.6, 0.4),
			agua,
			Enum.Material.Glass,
			{ colision = false, consulta = false, sombra = false, transparencia = 0.45, reflejo = 0.1 }
		)
	end
	-- labio de piedra arriba
	Kit.parte(
		m,
		cf * CFrame.new(0, alto + 0.6, 0.4),
		Vector3.new(9, 1.6, 3.2),
		Kit.variar(Config.Mapa.Culto.PIEDRA, rng, 0.05),
		Enum.Material.Slate
	)
	local raiz = ancla(m, "Agua", cf, Vector3.one)
	for _, x in { -1.6, 1.6 } do
		local a0 = Instance.new("Attachment")
		a0.WorldPosition = cf:PointToWorldSpace(Vector3.new(x, alto + 0.4, -1.4))
		a0.Parent = raiz
		local a1 = Instance.new("Attachment")
		a1.WorldPosition = cf:PointToWorldSpace(Vector3.new(x * 1.3, 0.2, -3))
		a1.Parent = raiz
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera = true
		b.Width0, b.Width1 = 3.2, 4.4
		b.Texture = HUMO
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 6
		b.TextureSpeed = -1.4 -- hacia abajo; si en Play el agua sube, cambiar el signo
		b.Color = ColorSequence.new(Color3.fromRGB(205, 222, 228))
		b.LightEmission = 0.25
		b.Transparency = NumberSequence.new(0.35)
		b.Parent = raiz
	end
	-- espuma y rociones al pie
	local pozo = ancla(m, "Espuma", cf * CFrame.new(0, 0.5, -4), Vector3.new(9, 1, 6))
	local espuma = Instance.new("ParticleEmitter")
	espuma.Texture = HUMO
	espuma.Shape = Enum.ParticleEmitterShape.Box
	espuma.Color = ColorSequence.new(Color3.fromRGB(220, 228, 232))
	espuma.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	espuma.Size = NumberSequence.new(4, 12)
	espuma.Lifetime = NumberRange.new(1.5, 3)
	espuma.Speed = NumberRange.new(3, 7)
	espuma.SpreadAngle = Vector2.new(60, 60)
	espuma.Acceleration = Vector3.new(0, -4, 0)
	espuma.Rate = 14
	espuma.Parent = pozo
	Atmosfera.niebla(m, pie + frente * 8, 30)
	sonido(pozo, Config.Mapa.Agua.Sonidos.Cascada, 30, 300)
	return m
end

-- Sonido en bucle anclado a un punto (arroyos, pantano).
function Atmosfera.sonido(
	padre: Instance,
	pos: Vector3,
	s: { id: number, volumen: number },
	minimo: number,
	maximo: number
)
	local p = ancla(padre, "Sonido", CFrame.new(pos), Vector3.one)
	sonido(p, s, minimo, maximo)
end

return Atmosfera
