--!strict
--[[
	Cinemática del lobby (Config.Lobby.CINEMATICA ≈ 14.5 s), en dos actos:

	  Embarque (6.5 s): un doble local del primer jugador del grupo camina a cámara lenta hacia
	  el helicóptero, desliza la puerta (la luz del interior se derrama fuera) y sube; la puerta
	  se cierra de golpe.
	  Despegue (8 s): los rotores aceleran, el helicóptero sube en vertical y se pierde entre las
	  nubes del atardecer. Fundido a blanco y a negro; el servidor nos lleva a la cabina.

	El servidor ancla a los jugadores dentro del helicóptero real; aquí se clona localmente, se
	oculta el original y se anima el clon. Baúl: Camera Systems (cámara Scriptable, Focus cada
	frame, sin roll), Motion Sensitivity (temblor reducido con ReducedMotionEnabled).
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Audio)
local Doble = require(script.Parent.Doble)
local Config = require(ReplicatedStorage.Shared.Config)

local CREMA = Color3.fromRGB(244, 232, 206)
local AMBAR = Color3.fromRGB(255, 176, 70)
local ARRIBA = Vector3.yAxis
local EMBARQUE = 6.5

local Cinematica = {}

type Pieza = { parte: BasePart, offset: CFrame, tipo: number } -- 0 casco, 1 rotor, 2 cola, 3 puerta

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function tramo(t: number, a: number, b: number): number
	return suave((t - a) / (b - a))
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

-- Franjas de cine, rótulo y fundidos.
local function interfaz(jugador: Player)
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

	local rotulo = Instance.new("Frame")
	rotulo.BackgroundTransparency = 1
	rotulo.AnchorPoint = Vector2.new(0, 1)
	rotulo.Position = UDim2.new(0, 56, 0.86, -14)
	rotulo.Size = UDim2.fromOffset(560, 96)
	rotulo.Parent = gui
	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Size = UDim2.new(1, 0, 0, 56)
	titulo.Font = Enum.Font.Merriweather
	titulo.TextSize = 50
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.TextColor3 = CREMA
	titulo.TextTransparency = 1
	titulo.Parent = rotulo
	local subtitulo = Instance.new("TextLabel")
	subtitulo.BackgroundTransparency = 1
	subtitulo.Position = UDim2.fromOffset(3, 60)
	subtitulo.Size = UDim2.new(1, 0, 0, 22)
	subtitulo.Font = Enum.Font.GothamMedium
	subtitulo.TextSize = 16
	subtitulo.TextXAlignment = Enum.TextXAlignment.Left
	subtitulo.TextColor3 = AMBAR
	subtitulo.TextTransparency = 1
	subtitulo.Text = "EXPEDICIONES AMAZONAS  ·  RUMBO A LA SELVA"
	subtitulo.Parent = rotulo

	local function velo(color: Color3, z: number): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 1
		f.ZIndex = z
		f.Parent = gui
		return f
	end
	local blanco = velo(Color3.fromRGB(255, 246, 236), 4)
	local negro = velo(Color3.new(0, 0, 0), 5)

	gui.Parent = jugador:WaitForChild("PlayerGui")
	return {
		gui = gui,
		arriba = barra(false),
		abajo = barra(true),
		titulo = titulo,
		subtitulo = subtitulo,
		blanco = blanco,
		negro = negro,
	}
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

function Cinematica.reproducir(helipuerto: Model?, protagonista: Player?)
	if reproduciendo then
		return
	end
	reproduciendo = true
	local jugador = Players.LocalPlayer
	local cam = workspace.CurrentCamera
	local duracion = Config.Lobby.CINEMATICA
	local escala = duracion / 14.5
	local temblor = if GuiService.ReducedMotionEnabled then 0.2 else 1

	local ui = interfaz(jugador)
	local function tween(o: Instance, segundos: number, props: { [string]: any })
		TweenService:Create(o, TweenInfo.new(segundos, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
	end
	tween(ui.arriba, 0.8, { Size = UDim2.fromScale(1, 0.12) })
	tween(ui.abajo, 0.8, { Size = UDim2.fromScale(1, 0.12) })
	Audio.musica("Vuelo", 2)

	local limpiar: (() -> ())? = nil
	local original = helipuerto and helipuerto:FindFirstChild("Helicoptero")
	local interior = original and original:FindFirstChild("Interior")
	if not (helipuerto and original and original:IsA("Model") and interior and interior:IsA("BasePart")) then
		tween(ui.negro, 0.8, { BackgroundTransparency = 0 })
	else
		local indice = tonumber(string.match(helipuerto.Name, "%d+")) or 1
		ui.titulo.Text = ("VUELO %d"):format(indice)

		local base = interior.CFrame
		local P = base.Position
		local suelo = P.Y - 4.6
		local plaza = Vector3.new(Config.Lobby.CENTRO.X, suelo + 1.6, Config.Lobby.CENTRO.Z)
		local fuera = Vector3.new(P.X - plaza.X, 0, P.Z - plaza.Z).Unit
		local lado = base.RightVector -- costado de la puerta
		local cola = -base.LookVector

		-- clon local del helicóptero; el original se saca del mundo solo en este cliente
		local clon = original:Clone()
		for _, d in clon:GetDescendants() do
			CollectionService:RemoveTag(d, "RotorLobby")
			CollectionService:RemoveTag(d, "RotorColaLobby")
		end
		clon.Parent = cam
		original.Parent = nil
		local ocultos = ocultarPasajeros(P)

		local rotor = clon:FindFirstChild("Rotor") :: Model?
		local colaRotor = clon:FindFirstChild("RotorCola") :: Model?
		local puerta = clon:FindFirstChild("Puerta") :: Model?
		local ejeRotor = if rotor and rotor.PrimaryPart
			then base:ToObjectSpace(rotor.PrimaryPart.CFrame)
			else CFrame.identity
		local ejeCola = if colaRotor and colaRotor.PrimaryPart
			then base:ToObjectSpace(colaRotor.PrimaryPart.CFrame)
			else CFrame.identity
		local piezas: { Pieza } = {}
		for _, d in clon:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				local tipo, ref = 0, base
				if rotor and rotor.PrimaryPart and d:IsDescendantOf(rotor) then
					tipo, ref = 1, rotor.PrimaryPart.CFrame
				elseif colaRotor and colaRotor.PrimaryPart and d:IsDescendantOf(colaRotor) then
					tipo, ref = 2, colaRotor.PrimaryPart.CFrame
				elseif puerta and d:IsDescendantOf(puerta) then
					tipo = 3
				end
				table.insert(piezas, { parte = d, offset = ref:ToObjectSpace(d.CFrame), tipo = tipo })
			end
		end
		local partes: { BasePart } = {}
		local cframes: { CFrame } = {}
		for i, p in piezas do
			partes[i] = p.parte
		end
		local interiorClon = clon:FindFirstChild("Interior") :: BasePart?
		local luzInterior = Instance.new("SpotLight")
		luzInterior.Face = Enum.NormalId.Right
		luzInterior.Angle = 75
		luzInterior.Range = 22
		luzInterior.Brightness = 0
		luzInterior.Color = Color3.fromRGB(255, 214, 160)
		luzInterior.Shadows = true
		luzInterior.Parent = interiorClon

		-- protagonista
		local actor, pistas, altura = Doble.crear(protagonista, { andar = "walk", quieto = "idle" })
		local andar, quieto = pistas.andar, pistas.quieto
		local puertaSuelo = P + lado * 3.9 + cola * 0.4 - ARRIBA * 4.6
		local inicio = puertaSuelo + lado * 10 + cola * 1.5
		local parada = puertaSuelo + lado * 2.4
		local subida = puertaSuelo + lado * 0.3 + ARRIBA * 1.6
		local dentro = P - ARRIBA * 2 + cola * 0.4
		if andar then
			andar:Play(0.2, 1, 0.7)
		end

		-- despegue: sube en vertical, deriva hacia delante y se mete en las nubes
		local function posicion(tb: number): Vector3
			if tb < 2.2 then
				return P + ARRIBA * (1.5 * suave((tb - 1.1) / 1.1))
			end
			local u = tb - 2.2
			return P + ARRIBA * (1.5 + 12 * u + 9 * u * u) + base.LookVector * (5 * u + 1.6 * u * u)
		end

		local nubes = Instance.new("Folder")
		nubes.Name = "NubesDespegue"
		nubes.Parent = cam
		local rng = Random.new()
		for _ = 1, 34 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, 150)
			local nube = Instance.new("Part")
			nube.Anchored = true
			nube.CanCollide = false
			nube.CanQuery = false
			nube.CanTouch = false
			nube.CastShadow = false
			nube.Material = Enum.Material.SmoothPlastic
			nube.Color = Color3.fromRGB(255, 232, 214)
			nube.Transparency = rng:NextNumber(0.05, 0.3)
			nube.Size = Vector3.new(rng:NextNumber(60, 140), rng:NextNumber(22, 44), rng:NextNumber(60, 140))
			nube.Position = P
				+ base.LookVector * 50
				+ Vector3.new(math.cos(a) * r, rng:NextNumber(280, 330), math.sin(a) * r)
			local malla = Instance.new("SpecialMesh")
			malla.MeshType = Enum.MeshType.Sphere
			malla.Parent = nube
			nube.Parent = nubes
		end

		local polvo, emisorPolvo = emisorLocal("PolvoDespegue", Color3.fromRGB(196, 176, 140))
		polvo.CFrame = CFrame.new(P - ARRIBA * 4)
		emisorPolvo.Size = NumberSequence.new(4, 16)
		emisorPolvo.Transparency = NumberSequence.new(0.5, 1)
		emisorPolvo.Lifetime = NumberRange.new(1.5, 2.8)
		emisorPolvo.Speed = NumberRange.new(18, 32)
		emisorPolvo.SpreadAngle = Vector2.new(180, 6)
		emisorPolvo.EmissionDirection = Enum.NormalId.Right
		emisorPolvo.RotSpeed = NumberRange.new(-60, 60)

		local profundidad = Instance.new("DepthOfFieldEffect")
		profundidad.Name = "CinematicaDOF"
		profundidad.FarIntensity = 0.35
		profundidad.NearIntensity = 0.25
		profundidad.InFocusRadius = 8
		profundidad.Parent = Lighting

		local look = base.LookVector
		local rumbo = math.atan2(-look.X, -look.Z)
		local cabeceo = 0
		local anguloRotor, anguloCola, velRotor = 0, 0, 0.8
		local despegueSonando = false
		local camPos = cam.CFrame.Position
		local plano = 0
		local t0 = os.clock()

		cam.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep("SelvaCinematica", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
			local t = math.min((os.clock() - t0) / escala, 14.5)
			local tb = t - EMBARQUE

			-- helicóptero
			local pos = if tb > 0 then posicion(tb) else P
			local vel = if tb > 0 then (posicion(tb + 0.08) - pos) / 0.08 else Vector3.zero
			local horizontal = Vector3.new(vel.X, 0, vel.Z)
			cabeceo += (-math.clamp(horizontal.Magnitude / 90 * 0.22, 0, 0.22) - cabeceo) * math.min(1, dt * 2)
			local giroLento = if tb > 2.2 then (tb - 2.2) * 0.07 else 0
			local cfHeli = CFrame.new(pos) * CFrame.fromEulerAnglesYXZ(cabeceo, rumbo + giroLento, 0)

			local objetivoRotor = if tb < 0 then 3 + tramo(t, 4.6, 6.5) * 6 elseif tb < 2.2 then 9 + tb * 9 else 32
			velRotor += (objetivoRotor - velRotor) * math.min(1, dt * 1.4)
			anguloRotor += velRotor * dt
			anguloCola += velRotor * 2.4 * dt
			-- puerta: se desliza despacio (3.2–4.6) y se cierra de golpe (5.8–6.05)
			local abierta = tramo(t, 3.2, 4.6) * (1 - tramo(t, 5.8, 6.05))
			local deslizar = CFrame.new(0.3 * math.min(1, abierta * 4), 0, 4.2 * abierta)
			local giroRotor = cfHeli * ejeRotor * CFrame.Angles(0, anguloRotor, 0)
			local giroCola = cfHeli * ejeCola * CFrame.Angles(anguloCola, 0, 0)
			for i, p in piezas do
				local marco = if p.tipo == 1
					then giroRotor
					elseif p.tipo == 2 then giroCola
					elseif p.tipo == 3 then cfHeli * deslizar
					else cfHeli
				cframes[i] = marco * p.offset
			end
			workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			luzInterior.Brightness = 3.5
				* tramo(t, 3.3, 4.2)
				* (1 - 0.6 * tramo(t, 4.6, 5.6))
				* (1 - tramo(t, 5.8, 6.05))

			-- protagonista
			if actor and actor.Parent then
				local donde: Vector3
				if t < 2.8 then
					donde = inicio:Lerp(parada, t / 2.8)
				elseif t < 4.6 then
					donde = parada
					if andar and andar.IsPlaying then
						andar:Stop(0.3)
						if quieto then
							quieto:Play(0.3)
						end
					end
				elseif t < 5.1 then
					donde = parada:Lerp(subida, (t - 4.6) / 0.5)
					if andar and not andar.IsPlaying then
						if quieto then
							quieto:Stop(0.2)
						end
						andar:Play(0.2, 1, 1.1)
					end
				else
					donde = subida:Lerp(dentro, math.min(1, (t - 5.1) / 0.6))
				end
				actor:PivotTo(CFrame.lookAt(donde + ARRIBA * altura, donde + ARRIBA * altura - lado))
				if t > 5.75 then
					actor:Destroy()
				end
			end

			if tb > 0.4 and not despegueSonando then
				despegueSonando = true
				Audio.efecto("Despegue")
			end
			emisorPolvo.Rate = if tb > 0.6 and tb < 5 then 80 * (1 - math.abs(tb - 2.6) / 2.4) else 0

			-- cámara: planos con cortes secos
			local nuevoPlano = if t < 2.8
				then 1
				elseif t < 4.6 then 2
				elseif t < EMBARQUE then 3
				elseif tb < 2.2 then 4
				elseif tb < 4.4 then 5
				elseif tb < 6.2 then 6
				else 7
			local corte = nuevoPlano ~= plano
			plano = nuevoPlano
			local mirar = pos
			local foco = pos
			local fov = 60
			local objetivo: Vector3
			if plano == 1 then
				-- contrapicado a la espalda del protagonista, caminando a cámara lenta
				local donde = inicio:Lerp(parada, math.min(1, t / 2.8))
				local avance = (parada - inicio).Unit
				local derecha = avance:Cross(ARRIBA)
				objetivo = donde - avance * (6.8 - t * 0.5) + derecha * 1.8 + ARRIBA * 0.9
				mirar = puertaSuelo + ARRIBA * 4.2
				foco = donde + ARRIBA * 2.5
				fov = 46
			elseif plano == 2 then
				-- la mano en la manija; la puerta se desliza y sale la luz
				objetivo = puertaSuelo + ARRIBA * 4.6 + lado * (4.4 - (t - 2.8) * 0.4) - cola * 3.4
				mirar = puertaSuelo + ARRIBA * 4.4 + cola * 0.8
				foco = puertaSuelo + ARRIBA * 4.4
				fov = 36
			elseif plano == 3 then
				-- plano heroico: sube y la puerta se cierra de golpe
				objetivo = puertaSuelo + lado * (12.5 - (t - 4.6) * 0.8) - cola * 6 + ARRIBA * 0.7
				mirar = puertaSuelo + ARRIBA * 4
				foco = puertaSuelo + ARRIBA * 3
				fov = 50
			elseif plano == 4 then
				-- junto al patín mientras aceleran los rotores
				objetivo = P + lado * (16 - tb * 0.9) - base.LookVector * 9 - ARRIBA * 2.8
				mirar = pos + ARRIBA * 3
				fov = 48
			elseif plano == 5 then
				-- desde la plaza, mirando cómo sube
				objetivo = plaza + ARRIBA * 3 + fuera:Cross(ARRIBA) * 16 - fuera * 14
				fov = 58 - (tb - 2.2) * 4
			elseif plano == 6 then
				-- desde el suelo, justo debajo: el helicóptero se hace pequeño contra el cielo
				objetivo = P - ARRIBA * 3.4 - lado * 7 - base.LookVector * 4
				fov = 74
			else
				-- teleobjetivo lejano: entra en las nubes y desaparece
				objetivo = plaza - fuera * 150 + ARRIBA * 34
				fov = 16
			end
			if corte or plano ~= 7 then
				camPos = objetivo
			end
			local golpe = if t > 5.95 and t < 6.4 then (1 - (t - 5.95) / 0.45) * 0.25 else 0
			local vibracion = (if plano == 4 then 0.06 * tb else 0) + golpe
			local ruido = Vector3.new(math.noise(t * 11, 3), math.noise(t * 11, 4), 0) * vibracion * temblor
			cam.FieldOfView = fov
			cam.CFrame = CFrame.lookAt(camPos + ruido, mirar)
			cam.Focus = CFrame.new(foco)
			profundidad.FocusDistance = (camPos - foco).Magnitude
		end)

		task.delay(4.9 * escala, function()
			tween(ui.titulo, 0.9, { TextTransparency = 0 })
			tween(ui.subtitulo, 0.9, { TextTransparency = 0.1 })
		end)
		task.delay(8.6 * escala, function()
			tween(ui.titulo, 0.9, { TextTransparency = 1 })
			tween(ui.subtitulo, 0.9, { TextTransparency = 1 })
		end)
		task.delay(13.4 * escala, function()
			tween(ui.blanco, 0.6, { BackgroundTransparency = 0 })
		end)
		task.delay(14 * escala, function()
			tween(ui.negro, 0.5, { BackgroundTransparency = 0 })
		end)

		limpiar = function()
			RunService:UnbindFromRenderStep("SelvaCinematica")
			clon:Destroy()
			nubes:Destroy()
			polvo:Destroy()
			profundidad:Destroy()
			if actor then
				actor:Destroy()
			end
			original.Parent = helipuerto
			for _, d in ocultos do
				(d :: any).LocalTransparencyModifier = 0
			end
		end
	end

	-- al llegar a la cabina (o si se cancela) se devuelve la cámara y se quita el negro
	task.spawn(function()
		local limite = os.clock() + duracion + 10
		repeat
			task.wait(0.1)
			local zona = jugador:GetAttribute("Zona")
		until zona == "Helicoptero" or zona == "Partida" or zona == "Lobby" or os.clock() > limite
		ui.negro.BackgroundTransparency = 0
		if limpiar then
			limpiar()
		end
		if jugador:GetAttribute("Zona") ~= "Helicoptero" then
			-- la cabina pone su propia cámara; en otro caso volvemos a la normal
			local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			if hum then
				cam.CameraSubject = hum
			end
			cam.FieldOfView = 70
		end
		ui.blanco.BackgroundTransparency = 1
		task.wait(0.6)
		tween(ui.negro, 1.4, { BackgroundTransparency = 1 })
		tween(ui.arriba, 1, { Size = UDim2.fromScale(1, 0) })
		tween(ui.abajo, 1, { Size = UDim2.fromScale(1, 0) })
		task.wait(1.6)
		ui.gui:Destroy()
		reproduciendo = false
	end)
end

function Cinematica.iniciar()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local evento = remotes:WaitForChild("Cinematica") :: RemoteEvent
	evento.OnClientEvent:Connect(function(helipuerto: Model?, protagonista: Player?)
		Cinematica.reproducir(helipuerto, protagonista)
	end)
end

return Cinematica
