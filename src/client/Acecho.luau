--!strict
--[[
	Sensación de estar observado entre pasadas de la serpiente.

	Cuando termina la primera cinemática, y mientras el jugador siga en la selva, cada pocos
	segundos (al azar) pasa algo pequeño: un susurro pegado al oído, unos ojos al borde de la
	vista que desaparecen si los miras, un arbusto que se mueve a tu espalda, una rama que se
	parte detrás o una respiración muy cerca. Todo es local: cada jugador vive su propio acecho.
	Por qué estos eventos: docs/SERPIENTE-MIEDO.md.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local A = Config.Acecho
local PESOS = A.Pesos :: { [string]: number }
local OJOS = Config.Serpiente.Filtro.OJOS
local PLANTAS = { "Arbustos", "Helechos", "HelechosSueltos", "HojasGrandes" }

local jugador = Players.LocalPlayer

local Acecho = {}

local generacion = 0
local despierto = false
local anterior = ""

local function camara(): CFrame?
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame
end

local function plano(v: Vector3): Vector3
	local p = Vector3.new(v.X, 0, v.Z)
	return if p.Magnitude > 1e-3 then p.Unit else Vector3.zAxis
end

local function suelo(p: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { jugador.Character :: Instance }
	local r = workspace:Raycast(p + Vector3.yAxis * 60, Vector3.yAxis * -200, params)
	return if r then r.Position else p
end

-- Un punto invisible con un sonido 3D. `seguir` lo recoloca cada fotograma (para el oído).
local function emisor(ids: { number }, volumen: number, donde: () -> Vector3?, tono: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(donde() or Vector3.zero)
	p.Parent = workspace
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. ids[math.random(1, #ids)]
	s.Volume = volumen
	s.PlaybackSpeed = tono or (0.88 + math.random() * 0.18)
	s.RollOffMinDistance = 2
	s.RollOffMaxDistance = 90
	s.Parent = p
	local con = RunService.RenderStepped:Connect(function()
		local d = donde()
		if d then
			p.CFrame = CFrame.new(d)
		end
	end)
	s.Ended:Once(function()
		con:Disconnect()
		p:Destroy()
	end)
	s:Play()
	task.delay(20, function()
		if p.Parent then
			con:Disconnect()
			p:Destroy()
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------------------------

-- Pegado a un oído, un poco por detrás: el paneo lo pone dentro de la cabeza.
local function susurro(): boolean
	local lado = if math.random() < 0.5 then -1 else 1
	emisor(A.Sonidos.Susurros, A.VOLUMEN.Susurro, function()
		local c = camara()
		return c and c.Position + c.RightVector * 1.4 * lado - c.LookVector * 0.7
	end)
	return true
end

local function respiracion(): boolean
	emisor(A.Sonidos.Respiracion, A.VOLUMEN.Respiracion, function()
		local c = camara()
		return c and c.Position - plano(c.LookVector) * 3 + Vector3.yAxis * 0.4
	end, 0.8)
	return true
end

local function rama(): boolean
	local c = camara()
	if not c then
		return false
	end
	local atras = -plano(c.LookVector)
	local giro = math.rad(math.random(-50, 50))
	local dir = CFrame.Angles(0, giro, 0):VectorToWorldSpace(atras)
	local p = suelo(c.Position + dir * math.random(10, 24))
	emisor(A.Sonidos.Rama, A.VOLUMEN.Rama, function()
		return p
	end)
	return true
end

-- Un arbusto o helecho a tu espalda o a un lado se sacude como si algo pasara rozándolo.
local function arbusto(): boolean
	local c = camara()
	local selva = workspace:FindFirstChild("Selva")
	local veg = selva and selva:FindFirstChild("Vegetacion")
	if not c or not veg then
		return false
	end
	local delante = plano(c.LookVector)
	local mejor: Model? = nil
	local mejorD = math.huge
	for _, nombre in PLANTAS do
		local carpeta = veg:FindFirstChild(nombre)
		if carpeta then
			for _, m in carpeta:GetChildren() do
				if m:IsA("Model") then
					local hacia = m:GetPivot().Position - c.Position
					local d = Vector3.new(hacia.X, 0, hacia.Z).Magnitude
					-- entre 12 y 45 studs, fuera de la vista (detrás o muy a un lado)
					if d > 12 and d < 45 and plano(hacia):Dot(delante) < 0.25 and d < mejorD then
						mejor, mejorD = m, d
					end
				end
			end
		end
	end
	local m = mejor
	if not m then
		return false
	end
	local base = m:GetPivot()
	emisor(A.Sonidos.Arbusto, A.VOLUMEN.Arbusto, function()
		return base.Position
	end)
	task.spawn(function()
		local inicio = os.clock()
		while m.Parent and os.clock() - inicio < 1.4 do
			local t = os.clock() - inicio
			local f = (1 - t / 1.4) * 0.12
			m:PivotTo(base * CFrame.Angles(math.sin(t * 31) * f, 0, math.sin(t * 23) * f))
			RunService.Heartbeat:Wait()
		end
		if m.Parent then
			m:PivotTo(base)
		end
	end)
	return true
end

-- Dos ojos al borde de la vista, entre los árboles. Si los miras de frente, ya no están.
local function ojos(): boolean
	local c = camara()
	if not c then
		return false
	end
	local lado = if math.random() < 0.5 then -1 else 1
	local giro = math.rad(math.random(A.OJOS_ANGULO[1], A.OJOS_ANGULO[2])) * lado
	local dir = CFrame.Angles(0, giro, 0):VectorToWorldSpace(plano(c.LookVector))
	local centro = suelo(c.Position + dir * math.random(A.OJOS_DISTANCIA[1], A.OJOS_DISTANCIA[2]))
		+ Vector3.yAxis * (2.5 + math.random() * 2)
	local mira = CFrame.lookAt(centro, Vector3.new(c.Position.X, centro.Y, c.Position.Z))
	local modelo = Instance.new("Model")
	modelo.Name = "Ojos"
	local partes: { BasePart } = {}
	for l = -1, 1, 2 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.45, 0.3, 0.3)
		p.Material = Enum.Material.Neon
		p.Color = OJOS
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = mira * CFrame.new(l * 0.55, 0, 0)
		p.Transparency = 1
		p.Parent = modelo
		table.insert(partes, p)
	end
	local luz = Instance.new("PointLight")
	luz.Color = OJOS
	luz.Range = 3
	luz.Brightness = 0.6
	luz.Parent = partes[1]
	modelo.Parent = workspace
	for _, p in partes do
		TweenService:Create(p, TweenInfo.new(1.2), { Transparency = 0.15 }):Play()
	end
	local inicio = os.clock()
	local fuera = false
	local con: RBXScriptConnection
	con = RunService.RenderStepped:Connect(function()
		local cc = camara()
		if not cc or fuera then
			return
		end
		local hacia = (centro - cc.Position).Unit
		local angulo = math.deg(math.acos(math.clamp(hacia:Dot(cc.LookVector), -1, 1)))
		-- parpadeo cada pocos segundos
		local cerrado = (os.clock() - inicio) % 3.1 < 0.12
		for _, p in partes do
			p.LocalTransparencyModifier = if cerrado then 1 else 0
		end
		if angulo < A.OJOS_MIRADA or os.clock() - inicio > A.OJOS_DURA then
			-- lo has visto (o eso crees): se apagan de golpe
			fuera = true
			con:Disconnect()
			modelo:Destroy()
		end
	end)
	return true
end

local EVENTOS: { [string]: () -> boolean } = {
	Susurro = susurro,
	Ojos = ojos,
	Arbusto = arbusto,
	Rama = rama,
	Respiracion = respiracion,
}

-- Elige un evento por peso, sin repetir el anterior.
local function elegir(): string
	local total = 0
	for nombre, peso in PESOS do
		if nombre ~= anterior then
			total += peso
		end
	end
	local r = math.random() * total
	for nombre, peso in PESOS do
		if nombre ~= anterior then
			r -= peso
			if r <= 0 then
				return nombre
			end
		end
	end
	return "Susurro"
end

local function enSelva(): boolean
	return jugador:GetAttribute("Zona") == "Partida"
end

-- Empieza el acecho a partir de la hora del servidor `desde`. Si ya está despierto no hace nada.
function Acecho.despertar(desde: number)
	if despierto then
		return
	end
	despierto = true
	generacion += 1
	local gen = generacion
	task.spawn(function()
		while gen == generacion and workspace:GetServerTimeNow() < desde do
			task.wait(1)
		end
		while gen == generacion and enSelva() do
			-- de día no hay anomalías (CONTEXT.md): espera a que anochezca
			while gen == generacion and workspace:GetAttribute("SelvaDia") == true do
				task.wait(2)
			end
			local nombre = elegir()
			anterior = nombre
			if EVENTOS[nombre]() == false then
				anterior = "" -- no había dónde (p. ej. ningún arbusto cerca): no cuenta
			end
			task.wait(math.random(A.ENTRE[1] * 10, A.ENTRE[2] * 10) / 10)
		end
		if gen == generacion then
			despierto = false
		end
	end)
end

function Acecho.dormir()
	despierto = false
	generacion += 1
end

return Acecho
