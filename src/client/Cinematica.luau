--!strict
--[[
	Cinemática del despegue. El servidor ancla a los jugadores en la cabina y envía
	`Remotes.Cinematica(helipuerto)`; cada cliente clona el helicóptero localmente, oculta el
	original y lo hace volar: arranque en la plataforma, ascenso, pasada sobre la plaza, giro
	alrededor de la base al atardecer y salida hacia la selva, hasta que pierde el control.
	La teletransportación la hace el servidor al terminar (Config.Lobby.CINEMATICA).

	Baúl: Camera Systems (cámara Scriptable, Focus cada frame, sin roll en la cámara) y
	Motion Sensitivity (el temblor se reduce con ReducedMotionEnabled).
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local CREMA = Color3.fromRGB(244, 232, 206)
local AMBAR = Color3.fromRGB(255, 176, 70)
local ARRIBA = Vector3.yAxis

local Cinematica = {}

type Pieza = { parte: BasePart, offset: CFrame, tipo: number } -- tipo: 0 casco, 1 rotor, 2 rotor de cola

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local function diferenciaAngulo(a: number, b: number): number
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

local function emisorLocal(nombre: string, color: Color3): (BasePart, ParticleEmitter)
	local parte = Instance.new("Part")
	parte.Name = nombre
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Transparency = 1
	parte.Size = Vector3.new(14, 1, 14)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Rate = 0
	e.Parent = parte
	parte.Parent = workspace.CurrentCamera
	return parte, e
end

local function interfaz(jugador: Player): (ScreenGui, Frame, Frame, Frame, TextLabel, TextLabel, Frame, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Cinematica"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local function barra(abajo: boolean): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, if abajo then 1 else 0)
		f.Position = UDim2.fromScale(0, if abajo then 1 else 0)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local arriba, abajo = barra(false), barra(true)

	local rotulo = Instance.new("Frame")
	rotulo.BackgroundTransparency = 1
	rotulo.AnchorPoint = Vector2.new(0, 1)
	rotulo.Position = UDim2.new(0, 48, 0.86, -12)
	rotulo.Size = UDim2.fromOffset(520, 90)
	rotulo.Parent = gui
	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Size = UDim2.new(1, 0, 0, 52)
	titulo.Font = Enum.Font.Merriweather
	titulo.TextSize = 46
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.TextColor3 = CREMA
	titulo.TextTransparency = 1
	titulo.Parent = rotulo
	local subtitulo = Instance.new("TextLabel")
	subtitulo.BackgroundTransparency = 1
	subtitulo.Position = UDim2.fromOffset(2, 56)
	subtitulo.Size = UDim2.new(1, 0, 0, 22)
	subtitulo.Font = Enum.Font.GothamMedium
	subtitulo.TextSize = 17
	subtitulo.TextXAlignment = Enum.TextXAlignment.Left
	subtitulo.TextColor3 = AMBAR
	subtitulo.TextTransparency = 1
	subtitulo.Text = "EXPEDICIONES AMAZONAS · RUMBO A LA SELVA"
	subtitulo.Parent = rotulo

	local negro = Instance.new("Frame")
	negro.BorderSizePixel = 0
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.ZIndex = 5
	negro.Parent = gui
	local final = Instance.new("TextLabel")
	final.BackgroundTransparency = 1
	final.Size = UDim2.fromScale(1, 1)
	final.Font = Enum.Font.Merriweather
	final.TextSize = 30
	final.TextColor3 = CREMA
	final.TextTransparency = 1
	final.Text = "El helicóptero pierde el control…"
	final.ZIndex = 6
	final.Parent = negro

	gui.Parent = jugador:WaitForChild("PlayerGui")
	return gui, arriba, abajo, rotulo, titulo, subtitulo, negro, final
end

-- Oculta (localmente) los personajes que están dentro de la cabina.
local function ocultarPasajeros(centro: Vector3): { Instance }
	local ocultos = {}
	for _, pl in Players:GetPlayers() do
		local char = pl.Character
		if char and (char:GetPivot().Position - centro).Magnitude < 14 then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = 1
					table.insert(ocultos, d)
				end
			end
		end
	end
	return ocultos
end

local reproduciendo = false

function Cinematica.reproducir(helipuerto: Model?)
	if reproduciendo then
		return
	end
	reproduciendo = true
	local jugador = Players.LocalPlayer
	local cam = workspace.CurrentCamera
	local duracion = Config.Lobby.CINEMATICA
	local escala = duracion / 12 -- los tiempos de abajo están pensados para 12 s
	local temblor = if GuiService.ReducedMotionEnabled then 0.2 else 1

	local limpiarHeli: (() -> ())? = nil
	local gui, barraArriba, barraAbajo, _rotulo, titulo, subtitulo, negro, final = interfaz(jugador)
	local function tween(o: Instance, segundos: number, props: { [string]: any })
		TweenService:Create(o, TweenInfo.new(segundos, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
	end
	tween(barraArriba, 0.6, { Size = UDim2.fromScale(1, 0.11) })
	tween(barraAbajo, 0.6, { Size = UDim2.fromScale(1, 0.11) })

	local original = helipuerto and helipuerto:FindFirstChild("Helicoptero")
	local interior = original and original:FindFirstChild("Interior")
	if not (helipuerto and original and original:IsA("Model") and interior and interior:IsA("BasePart")) then
		-- sin helicóptero que mostrar: solo fundido
		tween(negro, 0.8, { BackgroundTransparency = 0 })
		tween(final, 0.8, { TextTransparency = 0 })
	else
		local indice = tonumber(string.match(helipuerto.Name, "%d+")) or 1
		titulo.Text = ("VUELO %d"):format(indice)

		local base = interior.CFrame
		local P = base.Position
		-- dirección "hacia fuera" del lobby (de la plaza al helipuerto) y su perpendicular
		local plaza = Vector3.new(Config.Lobby.CENTRO.X, P.Y - 3, Config.Lobby.CENTRO.Z)
		local fuera = Vector3.new(P.X - plaza.X, 0, P.Z - plaza.Z).Unit
		local derecha = fuera:Cross(ARRIBA)

		-- clon local; el original se saca del mundo solo en este cliente
		local clon = original:Clone()
		for _, d in clon:GetDescendants() do
			CollectionService:RemoveTag(d, "RotorLobby")
			CollectionService:RemoveTag(d, "RotorColaLobby")
		end
		clon.Parent = cam
		original.Parent = nil
		local ocultos = ocultarPasajeros(P)

		local rotor = clon:FindFirstChild("Rotor") :: Model?
		local cola = clon:FindFirstChild("RotorCola") :: Model?
		local ejeRotor = if rotor and rotor.PrimaryPart
			then base:ToObjectSpace(rotor.PrimaryPart.CFrame)
			else CFrame.identity
		local ejeCola = if cola and cola.PrimaryPart
			then base:ToObjectSpace(cola.PrimaryPart.CFrame)
			else CFrame.identity
		local piezas: { Pieza } = {}
		for _, d in clon:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				local tipo, ref = 0, base
				if rotor and d:IsDescendantOf(rotor) and rotor.PrimaryPart then
					tipo, ref = 1, rotor.PrimaryPart.CFrame
				elseif cola and d:IsDescendantOf(cola) and cola.PrimaryPart then
					tipo, ref = 2, cola.PrimaryPart.CFrame
				end
				table.insert(piezas, { parte = d, offset = ref:ToObjectSpace(d.CFrame), tipo = tipo })
			end
		end
		local partes: { BasePart } = {}
		local cframes: { CFrame } = {}
		for i, p in piezas do
			partes[i] = p.parte
		end

		-- ruta: puntos de control cada 1.6 s desde t=2.5
		local T0, SEG = 2.5, 1.6
		local puntos = {
			P + ARRIBA * 1.5,
			P + ARRIBA * 16,
			P + ARRIBA * 34 - fuera * 40,
			plaza + ARRIBA * 52 - fuera * 45 + derecha * 35,
			plaza + ARRIBA * 72 + derecha * 100,
			plaza + ARRIBA * 92 + fuera * 120 + derecha * 50,
			plaza + ARRIBA * 115 + fuera * 330,
		}
		local function posicion(t: number): Vector3
			if t < T0 then
				-- en la plataforma: los patines se despegan al final
				return P + ARRIBA * (1.5 * suave((t - 1.4) / 1.1))
			end
			local k = math.clamp(math.floor((t - T0) / SEG), 0, #puntos - 2)
			local u = math.clamp((t - T0 - k * SEG) / SEG, 0, 1.4)
			if k == 0 then
				u = u * u * (2 - u) -- arranca desde parado
			end
			return catmull(puntos[math.max(1, k)], puntos[k + 1], puntos[k + 2], puntos[math.min(#puntos, k + 3)], u)
		end

		local look = base.LookVector
		local rumbo = math.atan2(-look.X, -look.Z)
		local cabeceo, alabeo, giroExtra = 0, 0, 0
		local anguloRotor, anguloCola, velRotor = 0, 0, 1.5

		local polvo, emisorPolvo = emisorLocal("PolvoDespegue", Color3.fromRGB(196, 176, 140))
		polvo.CFrame = CFrame.new(P - ARRIBA * 4)
		emisorPolvo.Size = NumberSequence.new(4, 14)
		emisorPolvo.Transparency = NumberSequence.new(0.55, 1)
		emisorPolvo.Lifetime = NumberRange.new(1.5, 2.6)
		emisorPolvo.Speed = NumberRange.new(18, 30)
		emisorPolvo.SpreadAngle = Vector2.new(180, 6)
		emisorPolvo.EmissionDirection = Enum.NormalId.Right
		emisorPolvo.RotSpeed = NumberRange.new(-60, 60)
		local humo, emisorHumo = emisorLocal("HumoMotor", Color3.fromRGB(40, 38, 36))
		humo.Size = Vector3.new(1.5, 1.5, 1.5)
		emisorHumo.Size = NumberSequence.new(2, 9)
		emisorHumo.Transparency = NumberSequence.new(0.2, 1)
		emisorHumo.Lifetime = NumberRange.new(1.2, 2)
		emisorHumo.Speed = NumberRange.new(2, 4)

		cam.CameraType = Enum.CameraType.Scriptable
		local camPos = cam.CFrame.Position
		local plano = 0
		local inicio = os.clock()

		RunService:BindToRenderStep("SelvaCinematica", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
			local t = math.min((os.clock() - inicio) / escala, 12.5)

			-- helicóptero
			local pos = posicion(t)
			local vel = (posicion(t + 0.08) - pos) / 0.08
			local horizontal = Vector3.new(vel.X, 0, vel.Z)
			local rumboAnterior = rumbo
			if horizontal.Magnitude > 6 then
				local objetivo = math.atan2(-horizontal.X, -horizontal.Z)
				rumbo += diferenciaAngulo(objetivo, rumbo) * math.min(1, dt * 2.2)
			end
			local giro = diferenciaAngulo(rumbo, rumboAnterior) / math.max(dt, 1e-3)
			alabeo += (math.clamp(giro * 0.45, -0.6, 0.6) - alabeo) * math.min(1, dt * 3)
			cabeceo += (-math.clamp(horizontal.Magnitude / 110 * 0.3, 0, 0.3) - cabeceo) * math.min(1, dt * 2)
			local averia = math.max(0, t - 10.2)
			giroExtra += dt * averia * 1.6
			local sacudida = averia * 0.05
			local cfHeli = CFrame.new(pos + Vector3.new(0, -averia * averia * 4, 0))
				* CFrame.fromEulerAnglesYXZ(
					cabeceo + math.noise(t * 6, 1) * sacudida,
					rumbo + giroExtra,
					alabeo + math.noise(t * 6, 2) * sacudida * 2
				)

			velRotor += ((if t < 2.5 then 4 + t * 9 else 30) - velRotor) * math.min(1, dt * 1.5)
			anguloRotor += velRotor * dt
			anguloCola += velRotor * 2.4 * dt
			local giroRotor = cfHeli * ejeRotor * CFrame.Angles(0, anguloRotor, 0)
			local giroCola = cfHeli * ejeCola * CFrame.Angles(anguloCola, 0, 0)
			for i, p in piezas do
				cframes[i] = (if p.tipo == 1 then giroRotor elseif p.tipo == 2 then giroCola else cfHeli) * p.offset
			end
			workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)

			emisorPolvo.Rate = if t > 0.8 and t < 5 then 70 * (1 - math.abs(t - 2.8) / 2.2) else 0
			humo.CFrame = cfHeli * CFrame.new(0, 5, 4)
			emisorHumo.Rate = if t > 9.8 then 60 else 0

			-- cámara: planos con cortes secos
			local nuevoPlano = if t < 2.5 then 1 elseif t < 5.4 then 2 elseif t < 8.4 then 3 elseif t < 10.4 then 4 else 5
			local corte = nuevoPlano ~= plano
			plano = nuevoPlano
			local mirar = pos
			local fov = 60
			local objetivo: Vector3
			if plano == 1 then
				-- plano bajo junto al patín, travelling lento
				objetivo = P + base.RightVector * (17 - t * 0.9) - base.LookVector * 9 - ARRIBA * 2.6
				mirar = pos + ARRIBA * 3
				fov = 48
			elseif plano == 2 then
				-- desde la plaza, mirando cómo sube y pasa por encima
				objetivo = plaza + ARRIBA * 4 + derecha * 16 - fuera * 18
				fov = 58 - (t - 2.5) * 3
			elseif plano == 3 then
				-- persecución
				objetivo = (cfHeli * CFrame.new(11, 6, 32)).Position
				mirar = pos + cfHeli.LookVector * 25
				fov = 66
			elseif plano == 4 then
				-- general desde abajo, teleobjetivo contra el cielo del atardecer
				objetivo = plaza + ARRIBA * 18 - fuera * 70 - derecha * 40
				fov = 34
			else
				-- de cerca mientras falla el motor
				objetivo = (CFrame.new(pos) * CFrame.fromEulerAnglesYXZ(0, rumbo, 0) * CFrame.new(-6, 4, 20)).Position
				fov = 72
			end
			if corte or plano ~= 3 and plano ~= 5 then
				camPos = objetivo
			else
				camPos = camPos:Lerp(objetivo, math.min(1, dt * 4))
			end
			local temblorCam = (if plano == 5 then 0.6 + averia * 0.8 elseif plano == 1 and t > 1 then 0.15 else 0)
				* temblor
			local ruido = Vector3.new(math.noise(t * 9, 3), math.noise(t * 9, 4), 0) * temblorCam
			cam.FieldOfView = fov
			cam.CFrame = CFrame.lookAt(camPos + ruido, mirar)
			cam.Focus = CFrame.new(pos)
		end)

		-- rótulo del vuelo y final a negro
		task.delay(3 * escala, function()
			tween(titulo, 0.8, { TextTransparency = 0 })
			tween(subtitulo, 0.8, { TextTransparency = 0.1 })
		end)
		task.delay(6.6 * escala, function()
			tween(titulo, 0.8, { TextTransparency = 1 })
			tween(subtitulo, 0.8, { TextTransparency = 1 })
		end)
		task.delay(11.1 * escala, function()
			tween(negro, 0.6, { BackgroundTransparency = 0 })
			tween(final, 0.9, { TextTransparency = 0 })
		end)

		limpiarHeli = function()
			RunService:UnbindFromRenderStep("SelvaCinematica")
			clon:Destroy()
			polvo:Destroy()
			humo:Destroy()
			original.Parent = helipuerto
			for _, d in ocultos do
				(d :: any).LocalTransparencyModifier = 0
			end
		end
	end

	-- devolver la cámara y quitar el negro cuando el jugador ya está en la selva
	task.spawn(function()
		-- hasta que el servidor nos lleva a la selva, o nos devuelve al lobby si se cancela
		local limite = os.clock() + duracion + 8
		repeat
			task.wait(0.1)
			local zona = jugador:GetAttribute("Zona")
		until zona == "Partida" or zona == "Lobby" or os.clock() > limite
		negro.BackgroundTransparency = 0
		if limpiarHeli then
			limpiarHeli()
		end
		local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
		cam.FieldOfView = 70
		task.wait(0.8)
		tween(final, 0.8, { TextTransparency = 1 })
		tween(negro, 1.6, { BackgroundTransparency = 1 })
		tween(barraArriba, 1, { Size = UDim2.fromScale(1, 0) })
		tween(barraAbajo, 1, { Size = UDim2.fromScale(1, 0) })
		task.wait(1.8)
		gui:Destroy()
		reproduciendo = false
	end)
end

function Cinematica.iniciar()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local evento = remotes:WaitForChild("Cinematica") :: RemoteEvent
	evento.OnClientEvent:Connect(function(helipuerto: Model?)
		Cinematica.reproducir(helipuerto)
	end)
end

return Cinematica
