--!strict
--[[
	Agua viva, parte del cliente. Lee `Selva.Agua` (lo publica server/Agua.luau) y hace que el
	agua de terreno reaccione:
	  · Corriente: nadando en el río, te arrastra río abajo.
	  · Salpicadura al caer al agua y ondas al nadar.
	  · Bajo el agua: tinte verdoso y desenfoque.
	  · Restos (hojas y ramas) que flotan río abajo.
	  · Delfines rosados que nadan por el río y saltan de vez en cuando (solo visuales).
	  · Pirañas: el agua hierve y saltan peces en sus tramos, para que se vean venir.
	  · Anaconda: dibuja su cuerpo siguiendo la cabeza que mueve el servidor.

	Todo es local y no cambia el juego; el daño lo decide el servidor. Las piezas se mueven con
	BulkMoveTo. Baúl: Terrain Deep Dive - Materials Water and Performance.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local A = Config.Agua
local ANCHO = Config.Mapa.ANCHO_RIO
local ROSA = Color3.fromRGB(236, 150, 168)
local ROSA_CLARO = Color3.fromRGB(250, 196, 204)
local ESCAMA = Color3.fromRGB(58, 66, 38)
local ESCAMA_OSCURA = Color3.fromRGB(32, 36, 22)

type Datos = {
	cfg: Configuration,
	rio: { Vector3 },
	piranas: { Vector3 },
	radioPirana: number,
}

-- Una pieza con su sitio relativo al centro del animal.
type Pieza = { parte: BasePart, rel: CFrame }

type Resto = { parte: BasePart, i: number, t: number, lado: number, fase: number }
type Delfin = {
	piezas: { Pieza },
	i: number,
	t: number,
	sentido: number,
	vel: number,
	lado: number,
	saltoEn: number,
	saltoDesde: number?,
}
type Cardumen = { centro: Vector3, emisor: BasePart, siguiente: number }
type Anaconda = { cfg: Configuration, segmentos: { BasePart }, cabeza: Vector3, rastro: { Vector3 } }

local Agua = {}

local jugador = Players.LocalPlayer
local rng = Random.new()

local datos: Datos? = nil
local carpeta: Folder? = nil
local restos: { Resto } = {}
local delfines: { Delfin } = {}
local cardumenes: { Cardumen } = {}
local anaconda: Anaconda? = nil
local partes: { BasePart } = {}
local cframes: { CFrame } = {}

local tinte: ColorCorrectionEffect? = nil
local desenfoque: BlurEffect? = nil
local siguienteDebajo = 0
local siguienteOnda = 0

-- Piezas -------------------------------------------------------------------------------------

local function pieza(padre: Instance, tam: Vector3, color: Color3, ovalo: boolean, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tam
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if ovalo then
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.Sphere
		malla.Parent = p
	end
	p.Parent = padre
	return p
end

local function mover(p: BasePart, cf: CFrame)
	table.insert(partes, p)
	table.insert(cframes, cf)
end

-- Río ----------------------------------------------------------------------------------------

local function leer(cfg: Configuration): Datos
	local rio = {}
	for i = 1, (cfg:GetAttribute("RioN") or 0) :: number do
		local p = cfg:GetAttribute("Rio" .. i)
		if typeof(p) == "Vector3" then
			table.insert(rio, p)
		end
	end
	local piranas = {}
	for i = 1, (cfg:GetAttribute("PiranaN") or 0) :: number do
		local p = cfg:GetAttribute("Pirana" .. i)
		if typeof(p) == "Vector3" then
			table.insert(piranas, p)
		end
	end
	return {
		cfg = cfg,
		rio = rio,
		piranas = piranas,
		radioPirana = (cfg:GetAttribute("PiranaRadio") or 20) :: number,
	}
end

-- Distancia horizontal al río, sentido de la corriente y tramo (i, t) más cercano.
local function cercaRio(d: Datos, pos: Vector3): (number, Vector3, number, number)
	local mejor, dir, idx, tt = math.huge, Vector3.zAxis, 1, 0
	local p = Vector2.new(pos.X, pos.Z)
	for i = 1, #d.rio - 1 do
		local a = Vector2.new(d.rio[i].X, d.rio[i].Z)
		local ab = Vector2.new(d.rio[i + 1].X, d.rio[i + 1].Z) - a
		local l2 = ab:Dot(ab)
		local t = if l2 > 0 then math.clamp((p - a):Dot(ab) / l2, 0, 1) else 0
		local dist = (p - (a + ab * t)).Magnitude
		if dist < mejor and l2 > 0 then
			mejor, idx, tt = dist, i, t
			dir = Vector3.new(ab.X, 0, ab.Y).Unit
		end
	end
	return mejor, dir, idx, tt
end

-- Punto del río en el tramo i, fracción t, desplazado `lado` studs hacia un costado.
local function enRio(d: Datos, i: number, t: number, lado: number): (Vector3, Vector3)
	local a, b = d.rio[i], d.rio[i + 1]
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	dir = if dir.Magnitude > 0 then dir.Unit else Vector3.zAxis
	local costado = Vector3.new(-dir.Z, 0, dir.X)
	return a:Lerp(b, t) + costado * lado, dir
end

-- Avanza (i, t) una distancia por el río; devuelve nil al salirse de los extremos.
local function avanzar(d: Datos, i: number, t: number, distancia: number): (number?, number)
	local largo = (d.rio[i + 1] - d.rio[i]).Magnitude
	t += distancia / math.max(largo, 0.1)
	while t > 1 do
		i += 1
		if i >= #d.rio then
			return nil, 0
		end
		t -= 1
	end
	while t < 0 do
		i -= 1
		if i < 1 then
			return nil, 0
		end
		t += 1
	end
	return i, t
end

-- Efectos al nadar ---------------------------------------------------------------------------

local function salpicar(pos: Vector3, fuerza: number)
	local padre = carpeta
	if not padre then
		return
	end
	local p = pieza(padre, Vector3.one, Color3.new(1, 1, 1), false)
	p.Transparency = 1
	p.CFrame = CFrame.new(pos)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(210, 230, 225))
	e.LightEmission = 0.2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(8 * fuerza, 16 * fuerza)
	e.SpreadAngle = Vector2.new(45, 45)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	e:Emit(math.floor(25 * fuerza))
	task.delay(2, function()
		p:Destroy()
	end)
end

local function onda(pos: Vector3)
	local padre = carpeta
	if not padre then
		return
	end
	local p = pieza(padre, Vector3.new(0.05, 2, 2), Color3.fromRGB(200, 220, 215), false)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.55
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	TweenService:Create(p, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 11, 11),
		Transparency = 1,
	}):Play()
	task.delay(1.4, function()
		p:Destroy()
	end)
end

-- ¿La cámara está bajo el agua? (celda de 4 studs, receta del baúl)
local function camaraDebajo(cam: Camera): boolean
	local p = cam.CFrame.Position
	local region = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, canales = pcall(function()
		return workspace.Terrain:ReadVoxelChannels(region, 4, { "LiquidOccupancy" })
	end)
	return ok and canales ~= nil and (canales :: any).LiquidOccupancy[1][1][1] > 0.5
end

local function efectosDebajo(cam: Camera, debajo: boolean)
	if not tinte or tinte.Parent ~= cam then
		local t = Instance.new("ColorCorrectionEffect")
		t.Name = "AguaDebajo"
		t.TintColor = Color3.fromRGB(120, 170, 150)
		t.Brightness = -0.05
		t.Saturation = -0.3
		t.Contrast = -0.1
		t.Parent = cam
		tinte = t
		local b = Instance.new("BlurEffect")
		b.Name = "AguaDesenfoque"
		b.Size = 10
		b.Parent = cam
		desenfoque = b
	end
	local t, b = tinte, desenfoque
	if t and b then
		t.Enabled = debajo
		b.Enabled = debajo
	end
end

-- Restos flotando ----------------------------------------------------------------------------

local function nuevoResto(d: Datos, padre: Instance, cerca: number)
	local i = math.clamp(cerca + rng:NextInteger(-6, 3), 1, #d.rio - 1)
	local hoja = rng:NextNumber() < 0.6
	local p = if hoja
		then pieza(
			padre,
			Vector3.new(rng:NextNumber(1, 2.2), 0.2, rng:NextNumber(1.4, 3)),
			Color3.fromRGB(56, 92, 44),
			true
		)
		else pieza(
			padre,
			Vector3.new(rng:NextNumber(0.3, 0.6), rng:NextNumber(0.3, 0.6), rng:NextNumber(3, 7)),
			Color3.fromRGB(78, 62, 46),
			false,
			Enum.Material.Wood
		)
	table.insert(restos, {
		parte = p,
		i = i,
		t = rng:NextNumber(),
		lado = rng:NextNumber(-ANCHO * 0.7, ANCHO * 0.7),
		fase = rng:NextNumber(0, math.pi * 2),
	})
end

-- Delfín rosado (boto) -----------------------------------------------------------------------

local function nuevoDelfin(d: Datos, padre: Instance, cerca: number)
	local piezas: { Pieza } = {}
	local function agregar(tam: Vector3, rel: CFrame, color: Color3, ovalo: boolean)
		table.insert(piezas, { parte = pieza(padre, tam, color, ovalo), rel = rel })
	end
	local escala = rng:NextNumber(0.9, 1.15)
	agregar(Vector3.new(1.7, 1.5, 5.2) * escala, CFrame.new(), ROSA, true) -- cuerpo
	agregar(Vector3.new(1.4, 1.4, 1.7) * escala, CFrame.new(0, 0.15, -2.6 * escala), ROSA_CLARO, true) -- melón
	agregar(Vector3.new(0.35, 0.3, 1.9) * escala, CFrame.new(0, -0.1, -4 * escala), ROSA_CLARO, true) -- hocico
	agregar(Vector3.new(0.25, 0.5, 1.2) * escala, CFrame.new(0, 0.75, 0.3 * escala), ROSA, true) -- lomo
	agregar(
		Vector3.new(1.1, 0.12, 0.6) * escala,
		CFrame.new(-0.95, -0.4, -1 * escala) * CFrame.Angles(0, 0, 0.5),
		ROSA,
		true
	)
	agregar(
		Vector3.new(1.1, 0.12, 0.6) * escala,
		CFrame.new(0.95, -0.4, -1 * escala) * CFrame.Angles(0, 0, -0.5),
		ROSA,
		true
	)
	agregar(Vector3.new(2.6, 0.15, 0.9) * escala, CFrame.new(0, 0, 3 * escala), ROSA, true) -- cola
	table.insert(delfines, {
		piezas = piezas,
		i = math.clamp(cerca + rng:NextInteger(-8, 8), 1, #d.rio - 1),
		t = rng:NextNumber(),
		sentido = if rng:NextNumber() < 0.5 then 1 else -1,
		vel = rng:NextNumber(8, 12),
		lado = rng:NextNumber(-ANCHO * 0.5, ANCHO * 0.5),
		saltoEn = os.clock() + rng:NextNumber(2, 8),
		saltoDesde = nil,
	})
end

local function destruirDelfin(f: Delfin)
	for _, p in f.piezas do
		p.parte:Destroy()
	end
end

-- Pirañas ------------------------------------------------------------------------------------

local function nuevoCardumen(padre: Instance, centro: Vector3): Cardumen
	-- el agua "hierve": burbujas y salpicones constantes en la superficie
	local p = pieza(padre, Vector3.new(4, 0.2, 4), Color3.new(1, 1, 1), false)
	p.Transparency = 1
	p.CFrame = CFrame.new(centro + Vector3.new(0, 0.3, 0))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(220, 230, 220))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(30, 30)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 30
	e.Parent = p
	-- reparte el hervor por todo el tramo
	p.Size = Vector3.new(A.PIRANAS.RADIO * 1.4, 0.2, A.PIRANAS.RADIO * 1.4)
	return { centro = centro, emisor = p, siguiente = os.clock() }
end

local function saltoPirana(padre: Instance, centro: Vector3, radio: number)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, radio * 0.7)
	local inicio = centro + Vector3.new(math.cos(a) * r, -0.3, math.sin(a) * r)
	local dir = Vector3.new(math.cos(a + 1.6), 0, math.sin(a + 1.6))
	local pez = pieza(padre, Vector3.new(0.35, 0.7, 1), Color3.fromRGB(150, 150, 140), true, Enum.Material.Metal)
	local vientre = pieza(padre, Vector3.new(0.3, 0.35, 0.8), Color3.fromRGB(190, 60, 40), true)
	local dur = rng:NextNumber(0.45, 0.7)
	local desde = os.clock()
	local conexion: RBXScriptConnection? = nil
	conexion = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - desde) / dur
		if u >= 1 or not pez.Parent then
			pez:Destroy()
			vientre:Destroy()
			if conexion then
				conexion:Disconnect()
			end
			return
		end
		local pos = inicio + dir * (u * 3) + Vector3.new(0, math.sin(math.pi * u) * 1.8, 0)
		local cf = CFrame.lookAt(pos, pos + dir + Vector3.new(0, math.cos(math.pi * u) * 1.5, 0))
		pez.CFrame = cf
		vientre.CFrame = cf * CFrame.new(0, -0.15, 0)
	end)
end

-- Anaconda -----------------------------------------------------------------------------------

local function nuevaAnaconda(padre: Instance, cfg: Configuration): Anaconda
	local segmentos = {}
	local n = 20
	for k = 1, n do
		local f = 1 - (k - 1) / n
		local grosor = if k == 1 then 1.5 else 0.6 + 1.3 * math.sin(math.pi * math.min(1, f * 1.15))
		local tam = if k == 1 then Vector3.new(1.5, 1.1, 2.4) else Vector3.one * grosor
		table.insert(segmentos, pieza(padre, tam, if k % 3 == 0 then ESCAMA_OSCURA else ESCAMA, true))
	end
	-- ojos en la cabeza: se ven cuando sube a morder
	for _, s in { -1, 1 } do
		local ojo = pieza(padre, Vector3.new(0.18, 0.18, 0.18), Color3.fromRGB(230, 200, 60), true, Enum.Material.Neon)
		ojo.Name = if s < 0 then "OjoI" else "OjoD"
	end
	local pos = (cfg:GetAttribute("Pos") or Vector3.zero) :: Vector3
	return { cfg = cfg, segmentos = segmentos, cabeza = pos, rastro = { pos } }
end

local function moverAnaconda(a: Anaconda, dt: number, padre: Instance)
	local meta = (a.cfg:GetAttribute("Pos") or a.cabeza) :: Vector3
	local rumbo = (a.cfg:GetAttribute("Rumbo") or Vector3.zAxis) :: Vector3
	a.cabeza = a.cabeza:Lerp(meta, math.min(1, dt * 8))
	-- el cuerpo sigue el camino que dejó la cabeza
	if (a.cabeza - a.rastro[1]).Magnitude > 0.6 then
		table.insert(a.rastro, 1, a.cabeza)
		if #a.rastro > 80 then
			table.remove(a.rastro)
		end
	end
	local separacion = 1.3
	local anterior = a.cabeza
	local adelante = if rumbo.Magnitude > 0.1 then rumbo.Unit else Vector3.zAxis
	mover(a.segmentos[1], CFrame.lookAt(a.cabeza, a.cabeza + adelante))
	local k, recorrido, idx = 2, 0, 1
	while k <= #a.segmentos and idx < #a.rastro do
		local p, q = a.rastro[idx], a.rastro[idx + 1]
		local largo = (q - p).Magnitude
		if recorrido + largo >= separacion then
			local punto = p:Lerp(q, (separacion - recorrido) / math.max(largo, 0.01))
			local mira = if (anterior - punto).Magnitude > 0.01 then anterior else punto + adelante
			mover(a.segmentos[k], CFrame.lookAt(punto, mira))
			anterior = punto
			k += 1
			recorrido = 0
			a.rastro[idx] = punto
		else
			recorrido += largo
			idx += 1
		end
	end
	-- los segmentos que aún no tienen rastro, apilados bajo la cabeza
	while k <= #a.segmentos do
		mover(a.segmentos[k], CFrame.new(a.cabeza - adelante * (k * 0.3)))
		k += 1
	end
	local cabeza = CFrame.lookAt(a.cabeza, a.cabeza + adelante)
	local ojoI, ojoD = padre:FindFirstChild("OjoI"), padre:FindFirstChild("OjoD")
	if ojoI and ojoI:IsA("BasePart") and ojoD and ojoD:IsA("BasePart") then
		mover(ojoI, cabeza * CFrame.new(-0.5, 0.35, -0.7))
		mover(ojoD, cabeza * CFrame.new(0.5, 0.35, -0.7))
	end
end

-- Bucle ----------------------------------------------------------------------------------------

local function limpiar()
	for _, r in restos do
		r.parte:Destroy()
	end
	for _, f in delfines do
		destruirDelfin(f)
	end
	table.clear(restos)
	table.clear(delfines)
	table.clear(cardumenes)
	anaconda = nil
	datos = nil
	if carpeta then
		carpeta:Destroy()
		carpeta = nil
	end
	local t, b = tinte, desenfoque
	if t then
		t.Enabled = false
	end
	if b then
		b.Enabled = false
	end
end

local function paso(dt: number)
	local cam = workspace.CurrentCamera
	local selva = workspace:FindFirstChild("Selva")
	local cfg = selva and selva:FindFirstChild("Agua")
	if jugador:GetAttribute("Zona") ~= "Partida" or not cam or not (cfg and cfg:IsA("Configuration")) then
		if carpeta or datos then
			limpiar()
		end
		return
	end
	local d = datos
	if not d or d.cfg ~= cfg then
		limpiar()
		d = leer(cfg)
		datos = d
	end
	if #d.rio < 2 then
		return
	end
	local padre = carpeta
	if not padre then
		local f = Instance.new("Folder")
		f.Name = "AguaLocal"
		f.Parent = workspace
		carpeta = f
		padre = f
		for _, centro in d.piranas do
			table.insert(cardumenes, nuevoCardumen(f, centro))
		end
	end
	local ahora = os.clock()
	local ojo = cam.CFrame.Position
	local distRio, _, idxCerca = cercaRio(d, ojo)

	-- corriente y ondas del jugador
	local char = jugador.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if raiz and raiz:IsA("BasePart") and hum and hum:GetState() == Enum.HumanoidStateType.Swimming then
		local dist, dir = cercaRio(d, raiz.Position)
		if dist < ANCHO + 1 then
			raiz.CFrame += dir * A.CORRIENTE * dt
		end
		local v = raiz.AssemblyLinearVelocity
		if ahora >= siguienteOnda and Vector3.new(v.X, 0, v.Z).Magnitude > 2 then
			siguienteOnda = ahora + 0.35
			onda(raiz.Position + Vector3.new(0, 1, 0))
		end
	end

	-- bajo el agua
	if ahora >= siguienteDebajo then
		siguienteDebajo = ahora + 0.1
		efectosDebajo(cam, camaraDebajo(cam))
	end

	table.clear(partes)
	table.clear(cframes)

	-- restos: solo si el río está cerca
	if distRio < 220 and #restos < A.RESTOS then
		nuevoResto(d, padre, idxCerca)
	end
	for k = #restos, 1, -1 do
		local r = restos[k]
		local i, t = avanzar(d, r.i, r.t, A.CORRIENTE * dt)
		local pos = if i then (enRio(d, i, t, r.lado)) else nil
		if not i or not pos or (pos - ojo).Magnitude > 260 then
			r.parte:Destroy()
			table.remove(restos, k)
		else
			r.i, r.t = i, t
			r.fase += dt
			local cf = CFrame.new(pos + Vector3.new(0, 0.1 + math.sin(r.fase * 1.7) * 0.08, 0))
				* CFrame.Angles(0, r.fase * 0.3, math.sin(r.fase) * 0.05)
			mover(r.parte, cf)
		end
	end

	-- delfines rosados
	if distRio < 200 and #delfines < A.DELFINES then
		nuevoDelfin(d, padre, idxCerca)
	end
	for k = #delfines, 1, -1 do
		local f = delfines[k]
		local i, t = avanzar(d, f.i, f.t, f.vel * f.sentido * dt)
		local pos, dir = ojo, Vector3.zAxis
		if i then
			pos, dir = enRio(d, i, t, f.lado)
		end
		if not i or (pos - ojo).Magnitude > 230 then
			destruirDelfin(f)
			table.remove(delfines, k)
		else
			f.i, f.t = i, t
			local adelante = dir * f.sentido
			local alto, cabeceo = -2.6, 0
			local desde = f.saltoDesde
			if desde then
				local u = (ahora - desde) / 1.6
				if u >= 1 then
					f.saltoDesde = nil
					f.saltoEn = ahora + rng:NextNumber(5, 11)
					salpicar(pos, 0.6)
				else
					alto = -2.6 + math.sin(math.pi * u) * 4
					cabeceo = math.cos(math.pi * u) * 0.8
				end
			elseif ahora >= f.saltoEn then
				f.saltoDesde = ahora
				salpicar(pos, 0.6)
			end
			local centro = CFrame.lookAt(pos + Vector3.new(0, alto, 0), pos + Vector3.new(0, alto, 0) + adelante)
				* CFrame.Angles(cabeceo, 0, 0)
			for _, p in f.piezas do
				mover(p.parte, centro * p.rel)
			end
		end
	end

	-- pirañas: peces que saltan cuando estás cerca
	for _, c in cardumenes do
		if (c.centro - ojo).Magnitude < 160 and ahora >= c.siguiente then
			c.siguiente = ahora + rng:NextNumber(0.4, 1.4)
			saltoPirana(padre, c.centro, d.radioPirana)
		end
	end

	-- anaconda
	local cfgAnaconda = cfg:FindFirstChild("Anaconda")
	if cfgAnaconda and cfgAnaconda:IsA("Configuration") then
		local a = anaconda
		if not a then
			a = nuevaAnaconda(padre, cfgAnaconda)
			anaconda = a
		end
		moverAnaconda(a, dt, padre)
	end

	if #partes > 0 then
		workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function vigilar(char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not hum:IsA("Humanoid") then
		return
	end
	hum.StateChanged:Connect(function(antes: Enum.HumanoidStateType, ahora: Enum.HumanoidStateType)
		if ahora == Enum.HumanoidStateType.Swimming and antes ~= Enum.HumanoidStateType.Swimming then
			local raiz = char:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") then
				local caida = math.clamp(-raiz.AssemblyLinearVelocity.Y / 40, 0.6, 2)
				salpicar(raiz.Position + Vector3.new(0, 1, 0), caida)
			end
		end
	end)
end

function Agua.iniciar()
	RunService.RenderStepped:Connect(paso)
	jugador.CharacterAdded:Connect(vigilar)
	if jugador.Character then
		task.spawn(vigilar, jugador.Character)
	end
end

return Agua
