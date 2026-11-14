--!strict
--[[
	Intro del helicóptero en el cliente. Sigue las fases que publica el servidor en el modelo
	IntroCabina (Fase, Linea, Fin) y monta lo que se ve y se oye:

	  charla   → cinemática: planos de cabina con travellings, subtítulos del piloto, música
	             de aventura atenuada bajo las voces, nubes pasando por las ventanillas.
	  posesion → la música se corta, el cielo se cierra en tormenta, llueve, las luces fallan y
	             se apagan; cae un rayo y su destello revela la cara del piloto girada hacia la
	             bodega con los ojos rojos. Susurros.
	  cuenta   → la cámara vuelve al jugador: alarma, rampa abierta, 30 s en pantalla, botín y
	             paracaídas; relámpagos cada pocos segundos.
	  salto    → (evento del servidor) caída libre, se abre el paracaídas y aterriza en la selva.
	  choque   → (evento) quien no saltó: destello, golpe y negro.

	Baúl: Camera Systems, Motion Sensitivity and Camera Comfort (temblores escalados con
	ReducedMotionEnabled), Captions and Audio Accessibility (subtítulos con nombre y tiempo
	de lectura), Music and Adaptive Audio.
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ambiente = require(script.Parent.Ambiente)
local Audio = require(script.Parent.Audio)
local Config = require(ReplicatedStorage.Shared.Config)
local Doble = require(script.Parent.Doble)

local I = Config.Intro
local ARRIBA = Vector3.yAxis
local CREMA = Color3.fromRGB(244, 232, 206)
local AMBAR = Color3.fromRGB(255, 176, 70)
local ROJO = Color3.fromRGB(255, 60, 48)

local Intro = {}

local jugador = Players.LocalPlayer
local temblor = if GuiService.ReducedMotionEnabled then 0.2 else 1

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function tween(o: Instance, segundos: number, props: { [string]: any }, estilo: Enum.EasingStyle?)
	TweenService:Create(o, TweenInfo.new(segundos, estilo or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
		:Play()
end

local function parteLocal(padre: Instance, tam: Vector3, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tam
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

local function ovoideLocal(padre: Instance, tam: Vector3, color: Color3): BasePart
	local p = parteLocal(padre, tam, color, Enum.Material.SmoothPlastic)
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = p
	return p
end

---------------------------------------------------------------------------------------------
-- Interfaz: franjas, subtítulos, cuenta atrás, botín y destellos
---------------------------------------------------------------------------------------------

type UI = {
	gui: ScreenGui,
	arriba: Frame,
	abajo: Frame,
	quien: TextLabel,
	texto: TextLabel,
	cuenta: Frame,
	numero: TextLabel,
	instruccion: TextLabel,
	botin: TextLabel,
	destello: Frame,
	negro: Frame,
	final: TextLabel,
}

local function crearUI(): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Intro"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9

	local function barra(abajo: boolean): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, if abajo then 1 else 0)
		f.Position = UDim2.fromScale(0, if abajo then 1 else 0)
		f.Size = UDim2.fromScale(1, 0.12)
		f.ZIndex = 2
		f.Parent = gui
		return f
	end
	local function etiqueta(padre: Instance, fuente: Enum.Font, tam: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = fuente
		l.TextSize = tam
		l.TextColor3 = color
		l.TextWrapped = true
		l.TextStrokeTransparency = 0.5
		l.Text = ""
		l.ZIndex = 3
		l.Parent = padre
		return l
	end

	-- subtítulos sobre la franja inferior (baúl: 2 líneas, nombre del hablante)
	local quien = etiqueta(gui, Enum.Font.GothamBold, 16, AMBAR)
	quien.AnchorPoint = Vector2.new(0.5, 1)
	quien.Position = UDim2.new(0.5, 0, 0.88, -52)
	quien.Size = UDim2.fromOffset(700, 20)
	local texto = etiqueta(gui, Enum.Font.GothamMedium, 24, CREMA)
	texto.AnchorPoint = Vector2.new(0.5, 1)
	texto.Position = UDim2.new(0.5, 0, 0.88, -6)
	texto.Size = UDim2.new(0.8, 0, 0, 60)
	texto.TextYAlignment = Enum.TextYAlignment.Bottom
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize = Vector2.new(820, 60)
	limite.Parent = texto

	-- cuenta atrás
	local cuenta = Instance.new("Frame")
	cuenta.BackgroundTransparency = 1
	cuenta.AnchorPoint = Vector2.new(0.5, 0)
	cuenta.Position = UDim2.new(0.5, 0, 0, 24)
	cuenta.Size = UDim2.fromOffset(560, 130)
	cuenta.Visible = false
	cuenta.Parent = gui
	local numero = etiqueta(cuenta, Enum.Font.GothamBlack, 72, ROJO)
	numero.Size = UDim2.new(1, 0, 0, 78)
	numero.TextStrokeTransparency = 0.2
	local instruccion = etiqueta(cuenta, Enum.Font.GothamBold, 18, CREMA)
	instruccion.Position = UDim2.fromOffset(0, 80)
	instruccion.Size = UDim2.new(1, 0, 0, 44)
	instruccion.Text = "Recoge lo que puedas, ponte un PARACAÍDAS y salta por la rampa"

	local botin = etiqueta(gui, Enum.Font.GothamMedium, 16, CREMA)
	botin.AnchorPoint = Vector2.new(1, 0.5)
	botin.Position = UDim2.new(1, -24, 0.5, 0)
	botin.Size = UDim2.fromOffset(240, 220)
	botin.TextXAlignment = Enum.TextXAlignment.Right
	botin.TextYAlignment = Enum.TextYAlignment.Center
	botin.RichText = true
	botin.Visible = false

	local destello = Instance.new("Frame")
	destello.BorderSizePixel = 0
	destello.Size = UDim2.fromScale(1, 1)
	destello.BackgroundColor3 = Color3.fromRGB(226, 236, 255)
	destello.BackgroundTransparency = 1
	destello.ZIndex = 5
	destello.Parent = gui
	local negro = Instance.new("Frame")
	negro.BorderSizePixel = 0
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.ZIndex = 6
	negro.Parent = gui
	local final = etiqueta(negro, Enum.Font.Merriweather, 30, CREMA)
	final.Size = UDim2.fromScale(1, 1)
	final.ZIndex = 7
	final.TextTransparency = 1

	gui.Parent = jugador:WaitForChild("PlayerGui")
	return {
		gui = gui,
		arriba = barra(false),
		abajo = barra(true),
		quien = quien,
		texto = texto,
		cuenta = cuenta,
		numero = numero,
		instruccion = instruccion,
		botin = botin,
		destello = destello,
		negro = negro,
		final = final,
	}
end

local function franjas(ui: UI, visibles: boolean, segundos: number)
	local alto = if visibles then 0.12 else 0
	tween(ui.arriba, segundos, { Size = UDim2.fromScale(1, alto) })
	tween(ui.abajo, segundos, { Size = UDim2.fromScale(1, alto) })
end

local function destellar(ui: UI, intensidad: number)
	ui.destello.BackgroundTransparency = 1 - intensidad
	tween(ui.destello, 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
end

---------------------------------------------------------------------------------------------
-- Cielo: nubes que pasan, tormenta, lluvia y rayos
---------------------------------------------------------------------------------------------

type Cielo = {
	carpeta: Folder,
	nubes: { BasePart },
	lluvia: { ParticleEmitter },
	avanzar: (dt: number) -> (),
	tormenta: (segundos: number) -> (),
	rayo: () -> (),
}

local function crearCielo(base: CFrame): Cielo
	local carpeta = Instance.new("Folder")
	carpeta.Name = "CieloIntro"
	carpeta.Parent = workspace.CurrentCamera
	local rng = Random.new()
	local nubes: { BasePart } = {}
	local offsets: { Vector3 } = {}
	local CALIDA = Color3.fromRGB(255, 226, 206)
	for i = 1, 70 do
		-- nadie dentro del fuselaje: |x| > 30 o muy arriba/abajo
		local x = rng:NextNumber(40, 420) * (if rng:NextNumber() < 0.5 then -1 else 1)
		local y = rng:NextNumber(-160, 40)
		if i % 4 == 0 then
			x = rng:NextNumber(-300, 300)
			y = rng:NextNumber(-170, -60)
		end
		local o = Vector3.new(x, y, rng:NextNumber(-700, 500))
		local nube = ovoideLocal(
			carpeta,
			Vector3.new(rng:NextNumber(50, 130), rng:NextNumber(20, 42), rng:NextNumber(60, 150)),
			CALIDA
		)
		nube.Transparency = rng:NextNumber(0.05, 0.35)
		table.insert(nubes, nube)
		table.insert(offsets, o)
	end
	-- mar de nubes bajo el helicóptero
	local mar = parteLocal(carpeta, Vector3.new(3000, 2, 3000), CALIDA, Enum.Material.SmoothPlastic)
	mar.CFrame = base * CFrame.new(0, -190, 0)
	mar.Transparency = 0.15
	table.insert(nubes, mar)

	-- lluvia fuera del fuselaje
	local lluvia: { ParticleEmitter } = {}
	for _, cf in { CFrame.new(-17, 14, -4), CFrame.new(17, 14, -4), CFrame.new(0, 14, -42) } do
		local caja = parteLocal(
			carpeta,
			Vector3.new(if cf.X == 0 then 40 else 18, 1, if cf.X == 0 then 26 else 80),
			Color3.new(),
			Enum.Material.SmoothPlastic
		)
		caja.Transparency = 1
		caja.CFrame = base * cf
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Size = NumberSequence.new(0.18)
		e.Squash = NumberSequence.new(3)
		e.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
		e.Transparency = NumberSequence.new(0.35)
		e.LightEmission = 0.4
		e.Speed = NumberRange.new(110, 140)
		e.Acceleration = Vector3.new(0, 0, 90)
		e.Lifetime = NumberRange.new(0.25, 0.4)
		e.Rate = 0
		e.Parent = caja
		table.insert(lluvia, e)
	end

	local velocidad = 130
	local function avanzar(dt: number)
		local cframes = table.create(#offsets)
		local partes = table.create(#offsets)
		for i, o in offsets do
			local z = o.Z + velocidad * dt
			if z > 500 then
				z -= 1200
			end
			offsets[i] = Vector3.new(o.X, o.Y, z)
			partes[i] = nubes[i]
			cframes[i] = base * CFrame.new(offsets[i])
		end
		workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local function tormenta(segundos: number)
		for _, n in nubes do
			tween(n, segundos, { Color = Color3.fromRGB(58, 62, 74) })
		end
		for _, e in lluvia do
			e.Rate = 900
		end
	end

	-- rayo en zigzag delante del parabrisas o por un costado
	local function rayo()
		local bolt = Instance.new("Folder")
		bolt.Name = "Rayo"
		bolt.Parent = carpeta
		local x = rng:NextNumber(-140, 140)
		local desde = (base * CFrame.new(x, 240, rng:NextNumber(-320, -180))).Position
		local hasta = (base * CFrame.new(x + rng:NextNumber(-60, 60), -180, rng:NextNumber(-300, -160))).Position
		local function tramo(a: Vector3, b: Vector3, grosor: number, ramas: number)
			local prev = a
			local n = 9
			for k = 1, n do
				local p = a:Lerp(b, k / n)
				if k < n then
					p += Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-10, 10))
				end
				local seg = parteLocal(
					bolt,
					Vector3.new(grosor, grosor, (p - prev).Magnitude),
					Color3.fromRGB(220, 232, 255),
					Enum.Material.Neon
				)
				seg.CFrame = CFrame.lookAt((prev + p) / 2, p)
				if ramas > 0 and rng:NextNumber() < 0.3 then
					tramo(
						p,
						p + Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(-90, -40), rng:NextNumber(-30, 30)),
						grosor * 0.5,
						ramas - 1
					)
				end
				prev = p
			end
		end
		tramo(desde, hasta, 2.2, 1)
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(200, 220, 255)
		luz.Range = 60
		luz.Brightness = 10
		luz.Parent = bolt:FindFirstChildWhichIsA("BasePart")
		task.delay(0.09, function()
			for _, d in bolt:GetChildren() do
				if d:IsA("BasePart") then
					d.Transparency = 1
				end
			end
		end)
		task.delay(0.16, function()
			for _, d in bolt:GetChildren() do
				if d:IsA("BasePart") then
					d.Transparency = 0
				end
			end
		end)
		task.delay(0.26, function()
			bolt:Destroy()
		end)
	end

	return {
		carpeta = carpeta,
		nubes = nubes,
		lluvia = lluvia,
		avanzar = avanzar,
		tormenta = tormenta,
		rayo = rayo,
	}
end

---------------------------------------------------------------------------------------------
-- Cabina
---------------------------------------------------------------------------------------------

local enCabina = false

local function entrarCabina()
	if enCabina then
		return
	end
	local modelo = workspace:WaitForChild("IntroCabina", 15) :: Model?
	if not modelo or jugador:GetAttribute("Zona") ~= "Helicoptero" then
		return
	end
	enCabina = true
	local cam = workspace.CurrentCamera
	local base = CFrame.new(I.CABINA)
	local function c(x: number, y: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end

	local ui = crearUI()
	local cielo = crearCielo(base)
	local profundidad = Instance.new("DepthOfFieldEffect")
	profundidad.Name = "IntroDOF"
	profundidad.FarIntensity = 0.3
	profundidad.NearIntensity = 0.3
	profundidad.InFocusRadius = 4
	profundidad.Parent = Lighting
	local tinte = Instance.new("ColorCorrectionEffect")
	tinte.Name = "IntroTinte"
	tinte.Parent = Lighting

	-- piloto
	local piloto = modelo:WaitForChild("Piloto", 5) :: Model?
	local cabeza = piloto and piloto:FindFirstChild("Head") :: BasePart?
	local cuello = cabeza and cabeza:FindFirstChild("Neck") :: Motor6D?
	local ojos: { BasePart } = {}
	local luzOjos: PointLight? = nil
	if piloto then
		for _, d in piloto:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Ojo" then
				table.insert(ojos, d)
			elseif d:IsA("PointLight") and d.Name == "LuzOjos" then
				luzOjos = d
			end
		end
	end
	local relampago = Instance.new("PointLight")
	relampago.Color = Color3.fromRGB(205, 222, 255)
	relampago.Range = 22
	relampago.Brightness = 0
	relampago.Shadows = true
	local anclaRelampago = parteLocal(cielo.carpeta, Vector3.one, Color3.new(), Enum.Material.SmoothPlastic)
	anclaRelampago.Transparency = 1
	relampago.Parent = anclaRelampago

	-- luces de la cabina y alarmas (efectos locales)
	local luces: { BasePart } = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "LuzCabina") then
			table.insert(luces, d)
		end
	end
	local alarmas: { BasePart } = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "Alarma") then
			table.insert(alarmas, d)
		end
	end
	local function lucesCabina(on: boolean, color: Color3?)
		for _, p in luces do
			p.Transparency = if on then 0 else 0.85
			if color then
				p.Color = color
			end
			local l = p:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = on
				if color then
					l.Color = color
				end
			end
		end
	end

	-- subtítulos con máquina de escribir; el tiempo de lectura lo da la duración de la línea
	local escribiendo = 0
	local function decir(linea: { quien: string, texto: string, poseido: boolean? }?)
		escribiendo += 1
		local id = escribiendo
		if not linea then
			ui.quien.Text = ""
			ui.texto.Text = ""
			return
		end
		ui.quien.Text = string.upper(linea.quien)
		ui.quien.TextColor3 = if linea.poseido then ROJO else AMBAR
		ui.texto.TextColor3 = if linea.poseido then Color3.fromRGB(255, 200, 196) else CREMA
		ui.texto.Font = if linea.poseido then Enum.Font.GothamBlack else Enum.Font.GothamMedium
		local completo = linea.texto
		task.spawn(function()
			local n = utf8.len(completo) or #completo
			for k = 1, n do
				if id ~= escribiendo then
					return
				end
				local corte = utf8.offset(completo, k + 1)
				ui.texto.Text = if corte then string.sub(completo, 1, corte - 1) else completo
				task.wait(if linea.poseido then 0.045 else 0.022)
			end
		end)
	end

	-- estado de la intro
	local fase = ""
	local tFase = os.clock()
	local linea = 0
	local tLinea = os.clock()
	local rayoHecho = false
	local proximoRayo = 0
	local cuelloGiro = 0

	local function lineaActual()
		return I.LINEAS[linea]
	end

	-- planos: { desde, hasta, mirar, fov } en coordenadas de la cabina
	local function plano(nombre: string, u: number): (Vector3, Vector3, number, number)
		local h = if cabeza then cabeza.Position else c(-2.9, 6.2, -19.3)
		if nombre == "general" then
			return c(3.4, 8.3, 14):Lerp(c(2.4, 7.6, 9), u), c(-1.4, 4.8, -19), 58, 26
		elseif nombre == "piloto" then
			local mira = if cabeza then cabeza.CFrame.LookVector else Vector3.new(0.6, 0, -0.8)
			local derecha = if cabeza then cabeza.CFrame.RightVector else Vector3.xAxis
			local desde = h + mira * (3.4 - u * 0.7) + derecha * 0.7 + ARRIBA * 0.25
			return desde, h, 40, (desde - h).Magnitude
		elseif nombre == "pasajeros" then
			return c(0.6, 6.4, -15.2):Lerp(c(-0.2, 6, -13.8), u), c(0, 3.6, -6), 62, 9
		elseif nombre == "parabrisas" then
			return c(-1.1, 6.5, -16.6):Lerp(c(-1.6, 6.3, -17.6), u), c(-3, 5.4, -60), 56, 6
		elseif nombre == "nuca" then
			-- detrás del piloto, casi a oscuras
			return c(-1.6, 6.3, -15.8):Lerp(c(-2.4, 6.2, -17.2), u), h, 44, 3
		else -- "ojos": primerísimo plano de la cara poseída
			local mira = if cabeza then cabeza.CFrame.LookVector else Vector3.zAxis
			local desde = h + mira * (2.6 - u * 0.9) + ARRIBA * 0.1
			return desde, h, 32, (desde - h).Magnitude
		end
	end
	local PLANOS_CHARLA = { "general", "piloto", "pasajeros", "piloto", "parabrisas", "piloto" }

	local camaraCine = true
	cam.CameraType = Enum.CameraType.Scriptable
	Ambiente.aplicar("Vuelo", 0)
	Audio.atenuar(0.55, 1)

	local function alCambiarFase()
		local nueva = modelo:GetAttribute("Fase") :: string?
		if nueva == fase or not nueva then
			return
		end
		fase = nueva
		tFase = os.clock()
		if fase == "posesion" then
			decir(nil)
			Audio.musica(nil, 0.15)
			Audio.atenuar(1, 0.1)
			Audio.efecto("Posesion")
			Audio.capas({ "Rotor", "Lluvia" }, 1.5)
			Ambiente.aplicar("Tormenta", 2.5)
			cielo.tormenta(2.5)
			tween(tinte, 3, { Saturation = -0.25, Contrast = 0.15 })
		elseif fase == "cuenta" then
			decir(nil)
			camaraCine = false
			cam.CameraType = Enum.CameraType.Custom
			local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
			cam.FieldOfView = 70
			profundidad.Enabled = false
			franjas(ui, false, 0.6)
			ui.cuenta.Visible = true
			ui.botin.Visible = true
			lucesCabina(true, Color3.fromRGB(255, 70, 50))
			for _, a in alarmas do
				local l = a:FindFirstChildOfClass("SpotLight")
				if l then
					l.Enabled = true
				end
				a.Color = Color3.fromRGB(255, 40, 30)
			end
			Audio.musica("Cuenta", 0.3)
			Audio.capas({ "Rotor", "Lluvia", "Alarma", "Tictac", "Viento" }, 0.6)
			proximoRayo = os.clock() + 3
		end
	end

	local function alCambiarLinea()
		local nueva = (modelo:GetAttribute("Linea") or 0) :: number
		if nueva == linea then
			return
		end
		linea = nueva
		tLinea = os.clock()
		local l = lineaActual()
		if l then
			decir(l)
			if l.poseido and linea == #I.LINEAS then
				Audio.efecto("Prueba")
				destellar(ui, 0.35)
			end
		end
	end

	local conexiones: { RBXScriptConnection } = {}
	table.insert(conexiones, modelo:GetAttributeChangedSignal("Fase"):Connect(alCambiarFase))
	table.insert(conexiones, modelo:GetAttributeChangedSignal("Linea"):Connect(alCambiarLinea))
	alCambiarFase()
	alCambiarLinea()

	local botin = jugador:WaitForChild("Botin", 5)
	local function pintarBotin()
		local nombres = {}
		if botin then
			for _, v in botin:GetChildren() do
				table.insert(nombres, v.Name)
			end
		end
		table.sort(nombres)
		local paracaidas = if jugador:GetAttribute("Paracaidas")
			then '<font color="#7CFF8C">PARACAÍDAS ✔</font>'
			else '<font color="#FF5A4A">SIN PARACAÍDAS</font>'
		ui.botin.Text = ("<b>BOTÍN</b>\n%s\n\n%s"):format(
			if #nombres > 0 then table.concat(nombres, "\n") else "—",
			paracaidas
		)
	end
	if botin then
		table.insert(conexiones, botin.ChildAdded:Connect(pintarBotin))
	end
	table.insert(conexiones, jugador:GetAttributeChangedSignal("Paracaidas"):Connect(pintarBotin))
	pintarBotin()

	local camPos = cam.CFrame.Position
	local planoAnterior = ""
	RunService:BindToRenderStep("SelvaIntro", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local ahora = os.clock()
		local tf = ahora - tFase
		cielo.avanzar(dt)

		-- posesión: parpadeo, apagón, rayo y cabeza girada
		if fase == "posesion" then
			if tf < 2.2 then
				local on = math.noise(tf * 9, 7) > (tf / 2.2) * 0.6 - 0.2
				lucesCabina(on)
			elseif not rayoHecho and tf < 3.1 then
				lucesCabina(false)
			end
			if tf >= 3.1 and not rayoHecho then
				rayoHecho = true
				cielo.rayo()
				Audio.efecto("Rayo")
				Audio.efecto("Trueno")
				Audio.capas({ "Rotor", "Lluvia", "Susurros" }, 2)
				destellar(ui, 0.7)
				for _, o in ojos do
					o.Transparency = 0
				end
				if luzOjos then
					luzOjos.Enabled = true
				end
				cuelloGiro = math.rad(-110)
				if cabeza then
					anclaRelampago.Position = cabeza.Position + cabeza.CFrame.LookVector * 3 + ARRIBA * 1.5
				end
				relampago.Brightness = 14
				task.delay(0.12, function()
					relampago.Brightness = 0
				end)
				task.delay(0.24, function()
					relampago.Brightness = 10
					destellar(ui, 0.4)
				end)
				task.delay(0.4, function()
					tween(relampago, 0.5, { Brightness = 0 })
				end)
				tween(tinte, 0.4, { TintColor = Color3.fromRGB(255, 196, 196) })
			end
		elseif fase == "cuenta" then
			-- relámpagos sueltos durante la cuenta
			if ahora > proximoRayo then
				proximoRayo = ahora + math.random(40, 70) / 10
				cielo.rayo()
				Audio.efecto("Trueno", 0.6, 0.9 + math.random() * 0.2)
				destellar(ui, 0.25)
			end
			for i, a in alarmas do
				a.CFrame *= CFrame.Angles(0, dt * 7 * (if i % 2 == 0 then 1 else -1), 0)
			end
			local fin = (modelo:GetAttribute("Fin") or 0) :: number
			local resto = math.max(0, fin - workspace:GetServerTimeNow())
			ui.numero.Text = ("%02d"):format(math.ceil(resto))
			local pulso = 1 - (resto % 1)
			ui.numero.TextSize = 72 + 10 * (1 - pulso) * (if resto < 10 then 1.6 else 1)
			-- turbulencia suave sin quitar el control de la cámara
			local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				local a = (0.12 + (1 - resto / I.CUENTA) * 0.25) * temblor
				hum.CameraOffset = Vector3.new(math.noise(ahora * 4, 1) * a, math.noise(ahora * 4, 2) * a, 0)
			end
		end

		-- cabeza del piloto poseído: gira hacia la bodega y tiembla
		if cuello and cuelloGiro ~= 0 then
			local tic = math.noise(ahora * 14, 5) * 0.12 + (if math.noise(ahora * 2, 6) > 0.35 then 0.25 else 0)
			cuello.Transform =
				CFrame.Angles(math.noise(ahora * 9, 8) * 0.1, cuelloGiro + tic, math.noise(ahora * 7, 9) * 0.15)
		end
		for _, o in ojos do
			if cuelloGiro ~= 0 then
				o.Transparency = if math.noise(ahora * 3, 10) > 0.45 then 0.6 else 0
			end
		end

		if not camaraCine then
			return
		end
		-- cámara de cine
		local nombre: string
		local u: number
		if fase == "charla" then
			local l = lineaActual()
			nombre = PLANOS_CHARLA[math.max(1, linea)] or "general"
			u = if l then math.min(1, (ahora - tLinea) / l.segundos) else 0
		elseif fase == "posesion" then
			if tf < 3.1 then
				nombre, u = "nuca", tf / 3.1
			else
				nombre, u = "ojos", (tf - 3.1) / (I.PAUSA_POSESION - 3.1)
			end
		else
			local l = lineaActual()
			nombre = if linea == #I.LINEAS then "general" else "ojos"
			u = if l then math.min(1, (ahora - tLinea) / l.segundos) else 0
		end
		local desde, mirar, fov, foco = plano(nombre, suave(u))
		if nombre ~= planoAnterior then
			planoAnterior = nombre
			camPos = desde
		else
			camPos = camPos:Lerp(desde, math.min(1, dt * 6))
		end
		-- respiración de cámara en mano y sacudida al caer el rayo
		local mano = 0.03 + (if fase == "posesion" and tf > 3.1 and tf < 3.8 then 0.35 else 0)
		if fase ~= "charla" then
			mano += 0.04
		end
		local ruido = Vector3.new(math.noise(ahora * 1.3, 11), math.noise(ahora * 1.1, 12), 0) * mano * temblor
		cam.CFrame = CFrame.lookAt(camPos + ruido, mirar)
		cam.FieldOfView = fov
		cam.Focus = CFrame.new(mirar)
		profundidad.FocusDistance = foco
	end)

	-- salida de la cabina (salto, choque o vuelta al lobby)
	task.spawn(function()
		repeat
			task.wait(0.1)
		until jugador:GetAttribute("Zona") ~= "Helicoptero" or not modelo.Parent
		RunService:UnbindFromRenderStep("SelvaIntro")
		for _, cx in conexiones do
			cx:Disconnect()
		end
		local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = Vector3.zero
		end
		cielo.carpeta:Destroy()
		profundidad:Destroy()
		tinte:Destroy()
		if cuello then
			cuello.Transform = CFrame.identity
		end
		if jugador:GetAttribute("Zona") ~= "Saltando" then
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = 70
		end
		task.delay(if jugador:GetAttribute("Zona") == "Lobby" then 2.5 else 0, function()
			ui.gui:Destroy()
		end)
		enCabina = false
	end)
end

---------------------------------------------------------------------------------------------
-- Salto en paracaídas
---------------------------------------------------------------------------------------------

local function velaParacaidas(padre: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Paracaidas"
	local naranja = Color3.fromRGB(232, 104, 32)
	local blanco = Color3.fromRGB(240, 236, 228)
	local raiz = parteLocal(m, Vector3.one * 0.2, Color3.new(), Enum.Material.SmoothPlastic)
	raiz.Transparency = 1
	m.PrimaryPart = raiz
	-- 7 celdas en arco a 12 studs sobre el arnés
	for k = -3, 3 do
		local a = k * 0.2
		local celda = ovoideLocal(m, Vector3.new(3.3, 1.7, 7), if k % 2 == 0 then naranja else blanco)
		celda.CFrame = CFrame.new(math.sin(a) * 11, 12 + (math.cos(a) - 1) * 11, 0) * CFrame.Angles(0, 0, -a)
		for _, z in { -2.8, 2.8 } do
			local desde = (celda.CFrame * CFrame.new(0, -0.6, z)).Position
			local hasta = Vector3.new(if desde.X > 0 then 0.6 else -0.6, 1.2, 0)
			local cuerda = parteLocal(
				m,
				Vector3.new(0.05, 0.05, (hasta - desde).Magnitude),
				Color3.fromRGB(30, 30, 30),
				Enum.Material.SmoothPlastic
			)
			cuerda.CFrame = CFrame.lookAt((desde + hasta) / 2, hasta)
		end
	end
	m.Parent = padre
	return m
end

local function caida(destino: Vector3, mirar: Vector3)
	local cam = workspace.CurrentCamera
	local duracion = I.SALTO
	local ui = crearUI()
	franjas(ui, true, 0)
	ui.negro.BackgroundTransparency = 0
	tween(ui.negro, 0.5, { BackgroundTransparency = 1 })

	local adelante = Vector3.new(mirar.X, 0, mirar.Z)
	adelante = if adelante.Magnitude > 0.01 then adelante.Unit else Vector3.new(0, 0, -1)
	local derecha = adelante:Cross(ARRIBA)
	local inicio = destino - adelante * 150 + ARRIBA * 430
	local apertura = destino - adelante * 36 + ARRIBA * 150
	local T_APERTURA, T_SUELO = 4.2, 8.3

	-- ocultar los personajes reales que esperan anclados en el suelo
	local ocultos: { Instance } = {}
	for _, pl in Players:GetPlayers() do
		if pl == jugador or pl:GetAttribute("Zona") == "Saltando" then
			local char = pl.Character
			if char then
				for _, d in char:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						(d :: any).LocalTransparencyModifier = 1
						table.insert(ocultos, d)
					end
				end
			end
		end
	end

	local actor, pistas, altura = Doble.crear(jugador, { caer = "fall", quieto = "idle" })
	if actor then
		local mochila = actor:FindFirstChild("MochilaParacaidas")
		if mochila then
			mochila:Destroy()
		end
	end
	if pistas.caer then
		pistas.caer:Play(0.1)
	end
	local vela: Model? = nil
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Caida"
	carpeta.Parent = cam

	-- estelas de viento alrededor de la cámara durante la caída libre
	local zonaViento = parteLocal(carpeta, Vector3.new(30, 30, 30), Color3.new(), Enum.Material.SmoothPlastic)
	zonaViento.Transparency = 1
	local viento = Instance.new("ParticleEmitter")
	viento.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	viento.Shape = Enum.ParticleEmitterShape.Box
	viento.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	viento.Orientation = Enum.ParticleOrientation.VelocityParallel
	viento.Squash = NumberSequence.new(4)
	viento.Size = NumberSequence.new(0.12)
	viento.Transparency = NumberSequence.new(0.5)
	viento.LightEmission = 0.5
	viento.Speed = NumberRange.new(120)
	viento.EmissionDirection = Enum.NormalId.Top
	viento.Lifetime = NumberRange.new(0.2, 0.35)
	viento.Rate = 160
	viento.Parent = zonaViento

	local profundidad = Instance.new("DepthOfFieldEffect")
	profundidad.Name = "CaidaDOF"
	profundidad.FarIntensity = 0.3
	profundidad.NearIntensity = 0.1
	profundidad.InFocusRadius = 10
	profundidad.Parent = Lighting

	local function posicion(t: number): Vector3
		if t < T_APERTURA then
			local u = t / T_APERTURA
			return inicio:Lerp(apertura, u ^ 1.25)
		end
		local u = math.min(1, (t - T_APERTURA) / (T_SUELO - T_APERTURA))
		local balanceo = derecha * math.sin(t * 1.7) * 3 * (1 - u)
		return apertura:Lerp(destino + ARRIBA * altura, 1 - (1 - u) ^ 1.6) + balanceo
	end

	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local abierto = false
	local camPos = cam.CFrame.Position
	local planoAnterior = 0
	RunService:BindToRenderStep("SelvaCaida", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local t = math.min(os.clock() - t0, duracion + 2)
		local pos = posicion(t)
		local vel = (posicion(t + 0.05) - pos) / 0.05

		if t >= T_APERTURA and not abierto then
			abierto = true
			Audio.efecto("Paracaidas")
			Audio.capas({ "Viento" }, 1.5)
			viento.Rate = 0
			destellar(ui, 0.15)
			if pistas.caer then
				pistas.caer:Stop(0.3)
			end
			if pistas.quieto then
				pistas.quieto:Play(0.3)
			end
			vela = velaParacaidas(carpeta)
		end

		local cfActor: CFrame
		if not abierto then
			-- boca abajo, girando despacio
			cfActor = CFrame.lookAt(pos, pos + adelante) * CFrame.Angles(math.rad(-75), 0, math.sin(t * 1.5) * 0.25)
		else
			local inclinacion = math.sin(t * 1.7) * 0.12
			cfActor = CFrame.lookAt(pos, pos + adelante) * CFrame.Angles(0, 0, inclinacion)
		end
		if actor and actor.Parent then
			actor:PivotTo(cfActor)
		end
		if vela then
			local abre = suave((t - T_APERTURA) / 0.6)
			vela:PivotTo(cfActor * CFrame.new(0, 1.2, 0))
			if abre < 1 then
				pcall(function()
					(vela :: Model):ScaleTo(math.max(0.05, abre))
				end)
			elseif vela:GetScale() < 1 then
				vela:ScaleTo(1)
			end
		end

		-- planos
		local planoActual = if t < T_APERTURA then 1 elseif t < 6.2 then 2 else 3
		local objetivo: Vector3
		local mirarA: Vector3
		local fov: number
		if planoActual == 1 then
			objetivo = pos - vel.Unit * 13 + ARRIBA * 4 + derecha * 3
			mirarA = pos + vel * 0.15
			fov = 82
		elseif planoActual == 2 then
			-- contrapicado: la vela abierta contra el cielo de tormenta
			objetivo = apertura + derecha * 16 - ARRIBA * 12 + adelante * 6
			mirarA = pos + ARRIBA * 6
			fov = 52
		else
			-- desde el suelo de la selva, viéndolo bajar entre los árboles
			objetivo = destino + derecha * 17 + adelante * 11 + ARRIBA * 2.5
			mirarA = pos + ARRIBA * 3
			fov = 46
		end
		if planoActual ~= planoAnterior then
			planoAnterior = planoActual
			camPos = objetivo
		else
			camPos = camPos:Lerp(objetivo, math.min(1, dt * (if planoActual == 1 then 10 else 3)))
		end
		zonaViento.CFrame = CFrame.lookAt(camPos, camPos + vel)
		local agitar = (if planoActual == 1 then 0.25 else 0.04) * temblor
		local ruido = Vector3.new(math.noise(t * 8, 21), math.noise(t * 8, 22), 0) * agitar
		cam.CFrame = CFrame.lookAt(camPos + ruido, mirarA)
		cam.FieldOfView = fov
		cam.Focus = CFrame.new(pos)
		profundidad.FocusDistance = (camPos - pos).Magnitude
	end)

	-- aterrizaje: el servidor nos suelta y pone la zona Partida
	task.spawn(function()
		local limite = os.clock() + duracion + 6
		repeat
			task.wait(0.1)
		until jugador:GetAttribute("Zona") ~= "Saltando" or os.clock() > limite
		RunService:UnbindFromRenderStep("SelvaCaida")
		carpeta:Destroy()
		profundidad:Destroy()
		if actor then
			actor:Destroy()
		end
		for _, d in ocultos do
			(d :: any).LocalTransparencyModifier = 0
		end
		local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
		cam.FieldOfView = 70
		franjas(ui, false, 1.2)
		task.wait(1.4)
		ui.gui:Destroy()
	end)
end

-- Quien sigue dentro cuando se acaba el tiempo.
local function choque()
	Audio.efecto("Choque")
	Audio.musica(nil, 0.2)
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	RunService:BindToRenderStep("SelvaChoque", Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - t0
		local a = math.max(0, 1.2 - t) * 0.8 * temblor
		cam.CFrame *= CFrame.Angles(math.noise(t * 20, 31) * a * 0.1, math.noise(t * 20, 32) * a * 0.1, 0)
	end)
	local velo = Instance.new("ScreenGui")
	velo.Name = "Choque"
	velo.IgnoreGuiInset = true
	velo.DisplayOrder = 12
	velo.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	f.Parent = velo
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.fromScale(1, 1)
	texto.Font = Enum.Font.Merriweather
	texto.TextSize = 30
	texto.TextColor3 = CREMA
	texto.TextTransparency = 1
	texto.Text = "No saltaste a tiempo…"
	texto.Parent = f
	velo.Parent = jugador:WaitForChild("PlayerGui")
	tween(f, 1, { BackgroundColor3 = Color3.new(0, 0, 0) })
	task.delay(0.6, function()
		tween(texto, 0.8, { TextTransparency = 0 })
	end)
	task.delay(4, function()
		RunService:UnbindFromRenderStep("SelvaChoque")
		tween(f, 1.2, { BackgroundTransparency = 1 })
		tween(texto, 1, { TextTransparency = 1 })
		task.wait(1.4)
		velo:Destroy()
	end)
end

function Intro.iniciar()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local evento = remotes:WaitForChild("Intro") :: RemoteEvent
	evento.OnClientEvent:Connect(function(tipo: string, destino: Vector3?, mirar: Vector3?)
		if tipo == "salto" and destino and mirar then
			caida(destino, mirar)
		elseif tipo == "choque" then
			choque()
		end
	end)
	local function zona()
		if jugador:GetAttribute("Zona") == "Helicoptero" then
			task.spawn(entrarCabina)
		end
	end
	jugador:GetAttributeChangedSignal("Zona"):Connect(zona)
	zona()
end

return Intro
