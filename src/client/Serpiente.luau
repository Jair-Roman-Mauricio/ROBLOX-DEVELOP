--!strict
--[[
	Serpiente (cliente): dibuja y mueve la serpiente con el recorrido y la hora que manda el
	servidor, levanta sobre su lomo lo que encuentra en el camino y hace la cinemática de la
	primera aparición.

	Primera aparición, sin enseñarla de frente:
	  -AVISO .. 0 s   tiembla el suelo cada vez más, ruido de tierra, la pantalla se apaga
	   0 .. 14 s      cámara de película desde el testigo: la tierra se abre, asoma el lomo con
	                  los árboles encima y cruza de lado; la cabeza va enterrada
	   14 s           la cámara vuelve a la primera persona

	Filtro de miedo: mientras está cerca, la pantalla pierde color y gana contraste, y la
	serpiente tiene un borde rojo oscuro y ojos que brillan, para que se lea como una silueta
	en la oscuridad.

	Lo que rompe (árboles, rocas, plantas) se rompe solo en este cliente y vuelve a crecer en
	su sitio cuando el suelo se regenera. El terreno lo abre y lo cierra el servidor.
	Baúl: Camera Systems, Motion Sensitivity and Camera Comfort (temblor reducido con
	ReducedMotionEnabled), Spatial Audio and Mixing, Boss and Set-Piece Encounters.
]]

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Forma = require(ReplicatedStorage.Shared.Serpiente)

local S = Config.Serpiente
local F = S.Filtro
local MIEDO = S.Miedo
local CARPETAS_ARRASTRE = {
	"Arboles",
	"Rocas",
	"RocasGrandes",
	"Troncos",
	"Arbustos",
	"HojasGrandes",
	"Helechos",
	"HelechosSueltos",
}

local Serpiente = {}

local jugador = Players.LocalPlayer
local temblor = if GuiService.ReducedMotionEnabled then 0.2 else 1

type Arrastrado = {
	modelo: Model,
	original: CFrame,
	escala: number,
	s: number, -- en qué punto del recorrido lo alcanza la cabeza
	roto: boolean,
	vuelve: number, -- hora del servidor en que vuelve a crecer en su sitio
	devuelto: boolean,
}

local activa: { fin: () -> () }? = nil

---------------------------------------------------------------------------------------------
-- utilidades
---------------------------------------------------------------------------------------------

local function sonido(def: { id: number, volumen: number }, padre: Instance, bucle: boolean, alcance: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = ("rbxassetid://%d"):format(def.id)
	s.Volume = def.volumen
	s.Looped = bucle
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 40
	s.RollOffMaxDistance = alcance or 900
	s.Parent = padre
	return s
end

local function filtro(): (ColorCorrectionEffect, BlurEffect)
	local cc = Lighting:FindFirstChild("FiltroSerpiente") :: ColorCorrectionEffect?
	if not cc then
		local nuevo = Instance.new("ColorCorrectionEffect")
		nuevo.Name = "FiltroSerpiente"
		nuevo.Parent = Lighting
		cc = nuevo
	end
	local blur = Lighting:FindFirstChild("DesenfoqueSerpiente") :: BlurEffect?
	if not blur then
		local nuevo = Instance.new("BlurEffect")
		nuevo.Name = "DesenfoqueSerpiente"
		nuevo.Size = 0
		nuevo.Parent = Lighting
		blur = nuevo
	end
	return cc :: ColorCorrectionEffect, blur :: BlurEffect
end

local function aplicarFiltro(k: number, desenfoque: number)
	local cc, blur = filtro()
	cc.Saturation = F.SATURACION * k
	cc.Contrast = F.CONTRASTE * k
	cc.TintColor = Color3.new(1, 1, 1):Lerp(F.TINTE, k)
	cc.Brightness = -0.04 * k
	blur.Size = desenfoque
end

-- marco de película: franjas negras arriba y abajo
local function franjas(): (ScreenGui, (boolean, number) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "CineSerpiente"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	local barras = {}
	for i, ancla in { Vector2.new(0, 0), Vector2.new(0, 1) } do
		local f = Instance.new("Frame")
		f.AnchorPoint = ancla
		f.Position = UDim2.fromScale(0, ancla.Y)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = gui
		barras[i] = f
	end
	gui.Parent = jugador:WaitForChild("PlayerGui")
	return gui,
		function(ver: boolean, segundos: number)
			for _, f in barras do
				TweenService:Create(
					f,
					TweenInfo.new(segundos, Enum.EasingStyle.Sine),
					{ Size = UDim2.fromScale(1, if ver then 0.12 else 0) }
				):Play()
			end
		end
end

---------------------------------------------------------------------------------------------
-- Lo que arrastra
---------------------------------------------------------------------------------------------

-- Plantas, árboles y rocas que la serpiente rompe: los que están a menos de un radio y medio
-- del recorrido, y todo lo que hay en el cráter por donde sale y por donde se hunde.
local function buscarArrastrables(ruta: Forma.Ruta, puntos: { Vector3 }, radio: number): { Arrastrado }
	local selva = workspace:FindFirstChild("Selva")
	local veg = selva and selva:FindFirstChild("Vegetacion")
	if not veg then
		return {}
	end
	-- rejilla de puntos del recorrido para buscar el más cercano rápido
	local CELDA = 32
	local rejilla: { [number]: { number } } = {}
	local function clave(x: number, z: number): number
		return (x // CELDA) * 4096 + (z // CELDA)
	end
	for i, p in puntos do
		local k = clave(p.X, p.Z)
		rejilla[k] = rejilla[k] or {}
		table.insert(rejilla[k], i)
	end
	local alcance = radio * 1.5
	local lista: { Arrastrado } = {}
	for _, nombre in CARPETAS_ARRASTRE do
		local carpeta = veg:FindFirstChild(nombre)
		if carpeta then
			for _, m in carpeta:GetChildren() do
				if m:IsA("Model") then
					local pos = m:GetPivot().Position
					local mejor, mejorI = math.huge, 0
					local cx, cz = pos.X // CELDA, pos.Z // CELDA
					for dx = -1, 1 do
						for dz = -1, 1 do
							local l = rejilla[(cx + dx) * 4096 + (cz + dz)]
							if l then
								for _, i in l do
									local d = Vector2.new(puntos[i].X - pos.X, puntos[i].Z - pos.Z).Magnitude
									if d < mejor then
										mejor, mejorI = d, i
									end
								end
							end
						end
					end
					local s = (mejorI - 1) * Forma.PASO
					local plano = Vector2.new(pos.X, pos.Z)
					local entrada = ruta.superficie(S.RAMPA * 0.5)
					local salida = ruta.superficie(ruta.total - S.RAMPA * 0.5)
					local crater = radio * S.CRATER
					if (plano - Vector2.new(entrada.X, entrada.Z)).Magnitude < crater then
						s = S.RAMPA * 0.5 -- revientan todos a la vez cuando asoma
					elseif (plano - Vector2.new(salida.X, salida.Z)).Magnitude < crater then
						s = ruta.total - S.RAMPA * 0.5
					elseif mejor >= alcance then
						s = -1
					end
					if s >= 0 then
						table.insert(lista, {
							modelo = m,
							original = m:GetPivot(),
							escala = m:GetScale(),
							s = s,
							roto = false,
							vuelve = math.huge,
							devuelto = false,
						})
					end
				end
			end
		end
	end
	table.sort(lista, function(a, b)
		return a.s < b.s
	end)
	while #lista > S.MAX_ARRASTRADOS do
		table.remove(lista, math.random(1, #lista))
	end
	return lista
end

-- Rompe un árbol, una roca o una planta: el original se esconde y una copia se parte en sus
-- piezas, que saltan hacia fuera y hacia arriba, giran y desaparecen.
local function romper(a: Arrastrado, desde: Vector3)
	local m = a.modelo
	local copia = m:Clone()
	-- el original se guarda bajo tierra hasta que vuelva a crecer
	m:PivotTo(a.original - Vector3.yAxis * 2000)
	local piezas: { BasePart } = {}
	for _, d in copia:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(piezas, d)
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- como mucho 14 trozos por objeto; el resto se pierde en el polvo
	while #piezas > 14 do
		local i = math.random(1, #piezas)
		piezas[i]:Destroy()
		table.remove(piezas, i)
	end
	copia.Parent = workspace
	for _, p in piezas do
		p.Anchored = false
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = false
		local fuera = Vector3.new(p.Position.X - desde.X, 0, p.Position.Z - desde.Z)
		fuera = if fuera.Magnitude > 0.1
			then fuera.Unit
			else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
		p.AssemblyLinearVelocity = fuera * math.random(18, 40) + Vector3.yAxis * math.random(30, 60)
		p.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
	end
	task.delay(2.5, function()
		for _, p in piezas do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			end
		end
		task.wait(1.6)
		copia:Destroy()
	end)
	a.roto = true
end

---------------------------------------------------------------------------------------------
-- Una pasada
---------------------------------------------------------------------------------------------

local function pasada(datos: Forma.Pasada)
	if activa then
		activa.fin()
	end
	local forma = Forma.forma()
	local modelo = forma.modelo
	local radio = forma.radio
	local ruta = Forma.ruta(datos.puntos, radio)
	local t0, v = datos.t0, datos.velocidad
	local terminada = false
	local conexiones: { RBXScriptConnection } = {}

	-- el modelo vive bajo tierra hasta que asoma; ojos que brillan y borde de silueta
	modelo.Name = "Serpiente"
	local ojos = modelo:FindFirstChild("Ojos", true)
	local partesOjos: { BasePart } = {}
	if ojos then
		for _, p in (if ojos:IsA("BasePart") then { ojos } else ojos:GetDescendants()) :: { Instance } do
			if p:IsA("BasePart") then
				table.insert(partesOjos, p)
				p.Material = Enum.Material.Neon
				p.Color = F.OJOS
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
			end
		end
		local luz = Instance.new("PointLight")
		luz.Color = F.OJOS
		luz.Range = 26
		luz.Brightness = 1.6
		luz.Shadows = false
		luz.Parent = if ojos:IsA("BasePart") then ojos else ojos:FindFirstChildWhichIsA("BasePart", true)
	end
	local silueta = Instance.new("Highlight")
	silueta.FillTransparency = 1
	silueta.OutlineColor = F.SILUETA
	silueta.OutlineTransparency = F.SILUETA_TRANSPARENCIA
	silueta.DepthMode = Enum.HighlightDepthMode.Occluded
	silueta.Parent = modelo
	modelo.Parent = workspace

	-- sonidos que viajan con la cabeza
	local ancla = Instance.new("Part")
	ancla.Name = "SonidoSerpiente"
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.Transparency = 1
	ancla.Size = Vector3.one
	ancla.Parent = modelo
	local derrumbe = sonido(S.Sonidos.Derrumbe, ancla, true, 1100)
	local rocas = sonido(S.Sonidos.Rocas, ancla, true, 500)
	local raices = sonido(S.Sonidos.Raices, ancla, false, 500)
	local rugido = sonido(S.Sonidos.Rugido, ancla, false, 1400)
	rugido.PlaybackSpeed = 0.55 -- más grave: algo enorme, no un cangrejo
	local siseo = sonido(S.Sonidos.Siseo, ancla, false, 260)
	siseo.PlaybackSpeed = 0.7
	-- infrasonido: un retumbar muy grave que se siente más que se oye
	local infra = sonido(S.Sonidos.Infrasonido, ancla, true, 1400)
	infra.PlaybackSpeed = 0.6
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 8
	eq.MidGain = -10
	eq.HighGain = -40
	eq.Parent = infra
	-- polvo y tierra que salta en la zanja, delante de la cabeza
	local polvo = Instance.new("ParticleEmitter")
	polvo.Texture = "rbxasset://textures/particles/smoke_main.dds"
	polvo.Color = ColorSequence.new(Color3.fromRGB(70, 56, 40))
	polvo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 22) })
	polvo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	polvo.Lifetime = NumberRange.new(2.5, 4)
	polvo.Speed = NumberRange.new(6, 14)
	polvo.SpreadAngle = Vector2.new(70, 70)
	polvo.Rate = 0
	polvo.LightInfluence = 1
	polvo.Parent = ancla
	local terrones = Instance.new("ParticleEmitter")
	terrones.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	terrones.Color = ColorSequence.new(Color3.fromRGB(46, 34, 22))
	terrones.Size = NumberSequence.new(1.2)
	terrones.Lifetime = NumberRange.new(1, 1.8)
	terrones.Speed = NumberRange.new(18, 34)
	terrones.SpreadAngle = Vector2.new(35, 35)
	terrones.Acceleration = Vector3.new(0, -60, 0)
	terrones.EmissionDirection = Enum.NormalId.Top
	terrones.Rate = 0
	terrones.LightInfluence = 1
	terrones.Parent = ancla

	local arrastrados = buscarArrastrables(ruta, datos.puntos, radio)
	local siguiente = 1
	local largoCuerpo = forma.largo

	-- piezas a mover cada frame
	local partes: { BasePart } = {}
	local destinos: { CFrame } = {}

	local function colocar(ahora: number)
		local rel = ahora - t0
		local fase = rel % MIEDO.TIRON_CADA
		if rel > 16 and fase < MIEDO.TIRON_DURA then
			-- se mueve a tirones, como si le faltaran fotogramas
			ahora = t0 + math.floor(rel * MIEDO.TIRON_FPS) / MIEDO.TIRON_FPS
		end
		local sCabeza = (ahora - t0) * v
		table.clear(partes)
		table.clear(destinos)
		local hondo = radio * (S.HUNDIDO_CABEZA - S.HUNDIDO)
		local asoma = (ahora - t0) % MIEDO.ASOMAR_CADA
		local k = 0
		if ahora - t0 > 16 and asoma < MIEDO.ASOMAR_DURA then
			-- asoma solo hasta los ojos y vuelve a hundirse
			k = math.sin(asoma / MIEDO.ASOMAR_DURA * math.pi)
			hondo -= radio * 0.85 * k
		end
		local mc = ruta.marco(sCabeza, hondo)
		local cam = workspace.CurrentCamera
		if k > 0 and cam then
			-- mientras asoma gira la cabeza hacia quien mira, como una persona, no como una serpiente
			local a = mc:PointToObjectSpace(cam.CFrame.Position)
			local giro = math.clamp(math.atan2(-a.X, -a.Z), -1.1, 1.1) * k
			mc *= CFrame.Angles(0, giro, 0)
		end
		for _, p in forma.cabeza.piezas do
			table.insert(partes, p.parte)
			table.insert(destinos, mc * p.desplazamiento)
		end
		for _, seg in forma.segmentos do
			local m = ruta.marco(sCabeza - seg.atras)
			for _, p in seg.piezas do
				table.insert(partes, p.parte)
				table.insert(destinos, m * p.desplazamiento)
			end
		end
		workspace:BulkMoveTo(partes, destinos, Enum.BulkMoveMode.FireCFrameChanged)
		ancla.CFrame = CFrame.new(ruta.superficie(sCabeza))

		-- romper lo que la cabeza alcanza
		while siguiente <= #arrastrados and arrastrados[siguiente].s <= sCabeza do
			local a = arrastrados[siguiente]
			siguiente += 1
			if a.modelo.Parent then
				romper(a, ruta.superficie(a.s))
				a.vuelve = t0 + (a.s + largoCuerpo) / v + S.REGENERA
				raices.TimePosition = 0
				raices:Play()
			end
		end
		for _, a in arrastrados do
			if a.roto and not a.devuelto and ahora >= a.vuelve then
				-- el suelo ya se cerró: vuelve a crecer en su sitio
				a.devuelto = true
				local m = a.modelo
				if m.Parent then
					m:PivotTo(a.original)
					m:ScaleTo(a.escala * 0.05)
					local inicio = os.clock()
					task.spawn(function()
						while m.Parent and os.clock() - inicio < 2.5 do
							local f = (os.clock() - inicio) / 2.5
							m:ScaleTo(a.escala * (0.05 + 0.95 * (1 - (1 - f) ^ 3)))
							RunService.Heartbeat:Wait()
						end
						if m.Parent then
							m:ScaleTo(a.escala)
						end
					end)
				end
			end
		end
	end

	-- antes de nada huyen los pájaros y la selva se calla
	local pantalla = jugador:WaitForChild("PlayerGui")
	local pajaros = sonido(S.Sonidos.Pajaros, ancla, false, 1200)
	ancla.CFrame = CFrame.new(ruta.superficie(S.RAMPA))
	pajaros:Play()
	local grupos: { SoundGroup } = {}
	for _, nombre in { "SelvaAmbiente", "SelvaMusica" } do
		local g = game:GetService("SoundService"):FindFirstChild(nombre)
		if g and g:IsA("SoundGroup") then
			table.insert(grupos, g)
		end
	end
	local volumenes: { number } = {}
	for i, g in grupos do
		volumenes[i] = g.Volume
	end
	local inicioSilencio = os.clock()
	local presencia = sonido(S.Sonidos.Presencia, pantalla, true)
	presencia.Volume = 0
	presencia:Play()
	infra.Volume = 0
	infra:Play()
	local proximoSiseo = os.clock() + 4
	local rumor = sonido(S.Sonidos.Temblor, pantalla, true)
	-- susurros casi humanos bajo el siseo: algo que no debería sonar así
	local susurros = sonido(Config.Audio.Ambiente.Susurros, pantalla, true)
	susurros.PlaybackSpeed = 0.82
	susurros.Volume = 0
	susurros:Play()
	local function fin()
		if terminada then
			return
		end
		terminada = true
		for _, c in conexiones do
			c:Disconnect()
		end
		-- devolver a su sitio lo que quedara roto
		for _, a in arrastrados do
			if a.roto and not a.devuelto and a.modelo.Parent then
				a.modelo:PivotTo(a.original)
				a.modelo:ScaleTo(a.escala)
			end
		end
		RunService:UnbindFromRenderStep("TemblorSerpiente")
		aplicarFiltro(0, 0)
		jugador:SetAttribute("MiedoSerpiente", 0)
		for i, g in grupos do
			TweenService:Create(g, TweenInfo.new(4), { Volume = volumenes[i] }):Play()
		end
		presencia:Destroy()
		rumor:Destroy()
		susurros:Destroy()
		modelo:Destroy()
		if activa and activa.fin == fin then
			activa = nil
		end
	end
	activa = { fin = fin }

	table.insert(
		conexiones,
		RunService.Heartbeat:Connect(function()
			colocar(workspace:GetServerTimeNow())
		end)
	)
	colocar(workspace:GetServerTimeNow())

	---------------------------------------------------------------------------------------
	-- Temblor, sonido y filtro: dependen de la distancia a la cabeza
	---------------------------------------------------------------------------------------
	rumor.Volume = 0
	rumor:Play()
	derrumbe:Play()
	rocas:Play()
	derrumbe.Volume = 0
	rocas.Volume = 0
	local rugio = false
	local cinematica = false

	RunService:BindToRenderStep("TemblorSerpiente", Enum.RenderPriority.Camera.Value + 3, function()
		local ahora = workspace:GetServerTimeNow()
		local sCabeza = (ahora - t0) * v
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local cabeza = ruta.superficie(math.clamp(sCabeza, 0, ruta.total))
		local d = (cam.CFrame.Position - cabeza).Magnitude
		local cerca = math.clamp(1 - d / F.DISTANCIA, 0, 1)
		-- antes de asomar el temblor crece con el tiempo; después, con la cercanía
		local antes = math.clamp(1 + (ahora - t0) / S.AVISO, 0, 1)
		local fuera = sCabeza > S.RAMPA * 0.5 and sCabeza < ruta.total
		local fuerza = math.max(
			antes * (if sCabeza < S.RAMPA then 1 else 0),
			cerca * (if sCabeza < ruta.total + largoCuerpo then 1 else 0)
		)
		if datos.primera and ahora < t0 + 14 then
			fuerza = math.max(fuerza, antes)
		end
		rumor.Volume = S.Sonidos.Temblor.volumen * math.max(fuerza, cerca * 0.6)
		derrumbe.Volume = if fuera then S.Sonidos.Derrumbe.volumen else 0
		rocas.Volume = if fuera then S.Sonidos.Rocas.volumen else 0
		polvo.Rate = if fuera then 40 else 0
		terrones.Rate = if fuera then 60 else 0
		if fuera and not rugio and sCabeza > S.RAMPA * 2 then
			rugio = true
			rugido:Play()
		end
		aplicarFiltro(math.max(fuerza, cerca), if cinematica then 0 else fuerza * 2.5)
		-- la selva se calla: primero de golpe al huir los pájaros, luego según la cercanía
		local calla = math.max(
			math.clamp((os.clock() - inicioSilencio) / MIEDO.SILENCIO, 0, 1) * (if ahora < t0 + 20 then 1 else 0),
			cerca
		)
		for i, g in grupos do
			g.Volume = volumenes[i] * (1 - calla)
		end
		presencia.Volume = S.Sonidos.Presencia.volumen * cerca * cerca
		-- solo muy cerca, y sin poder decir de dónde salen
		susurros.Volume = Config.Audio.Ambiente.Susurros.volumen * math.clamp((cerca - 0.6) / 0.4, 0, 1)
		infra.Volume = S.Sonidos.Infrasonido.volumen * math.max(cerca, fuerza)
		if d < 140 and os.clock() > proximoSiseo and sCabeza > 0 and sCabeza < ruta.total then
			proximoSiseo = os.clock() + math.random(MIEDO.SISEO[1], MIEDO.SISEO[2])
			siseo:Play()
		end
		-- la linterna lee esta cercanía y falla
		jugador:SetAttribute("MiedoSerpiente", if d < MIEDO.LINTERNA then 1 - d / MIEDO.LINTERNA else 0)
		-- ojos que parpadean de vez en cuando
		local cerrado = (os.clock() % 4.3) < 0.14
		for _, p in partesOjos do
			p.Transparency = if cerrado then 1 else 0
		end
		-- sacudida de cámara: más rápida y menos amplia cuanto más lejos
		local a = fuerza * 0.9 * temblor
		if a > 0.01 then
			local t = os.clock()
			cam.CFrame *= CFrame.new(math.noise(t * 13, 1.7) * a * 0.35, math.noise(t * 13, 5.3) * a * 0.35, 0) * CFrame.Angles(
				math.noise(t * 9, 2.1) * a * 0.012,
				math.noise(t * 9, 8.4) * a * 0.012,
				math.noise(t * 7, 4.4) * a * 0.008
			)
		end
	end)

	-- cuando todo lo arrastrado volvió a su sitio y la cola ya se hundió, se recoge
	task.spawn(function()
		local final = t0 + (ruta.total + largoCuerpo) / v + S.REGENERA + 4
		while not terminada and workspace:GetServerTimeNow() < final do
			task.wait(1)
		end
		fin()
	end)

	---------------------------------------------------------------------------------------
	-- Cinemática de la primera aparición
	---------------------------------------------------------------------------------------
	if datos.primera and jugador:GetAttribute("Zona") == "Partida" then
		task.spawn(function()
			local gui, ver = franjas()
			local espera = t0 - 1.5 - workspace:GetServerTimeNow()
			if espera > 0 then
				task.wait(espera)
			end
			if terminada then
				gui:Destroy()
				return
			end
			local cam = workspace.CurrentCamera
			local char = jugador.Character
			local cabezaJ = char and char:FindFirstChild("Head")
			local ojo = if cabezaJ and cabezaJ:IsA("BasePart") then cabezaJ.Position else cam.CFrame.Position
			local salida = ruta.superficie(S.RAMPA)
			local hacia = Vector3.new(salida.X - ojo.X, 0, salida.Z - ojo.Z).Unit
			-- la cámara se aparta un poco del jugador, a la altura de los arbustos
			local base = ojo - hacia * 6 + Vector3.yAxis * 3
			local fov = cam.FieldOfView
			cinematica = true
			ver(true, 1)
			cam.CameraType = Enum.CameraType.Scriptable
			local inicio = os.clock()
			local mirar = salida
			while not terminada and os.clock() - inicio < 15.5 do
				local dt = RunService.RenderStepped:Wait()
				local t = os.clock() - inicio
				local sCabeza = (workspace:GetServerTimeNow() - t0) * v
				-- mira a la tierra que se abre y luego acompaña el lomo, con retraso
				local objetivo = ruta.superficie(math.clamp(sCabeza - radio * 3, S.RAMPA * 0.5, ruta.total))
					+ Vector3.yAxis * radio * 0.6
				mirar = mirar:Lerp(objetivo, math.min(1, dt * 1.2))
				local acercar = math.clamp((t - 2) / 10, 0, 1)
				local pos = base:Lerp(base + hacia * 18 + Vector3.yAxis * 4, acercar * acercar * (3 - 2 * acercar))
				cam.CFrame = CFrame.lookAt(pos, mirar)
				cam.FieldOfView = fov + (52 - fov) * math.clamp(t / 4, 0, 1)
			end
			ver(false, 1.2)
			cam.FieldOfView = fov
			cam.CameraType = Enum.CameraType.Custom
			cinematica = false
			task.delay(1.5, function()
				gui:Destroy()
			end)
		end)
	end
end

function Serpiente.iniciar()
	local remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Serpiente") :: RemoteEvent
	remoto.OnClientEvent:Connect(function(tipo: string, datos: any)
		if tipo == "pasada" and typeof(datos) == "table" then
			pasada(datos :: Forma.Pasada)
		elseif tipo == "fin" and activa then
			activa.fin()
		end
	end)
	-- si el jugador sale de la selva (muere o vuelve al lobby), se quita la serpiente
	jugador:GetAttributeChangedSignal("Zona"):Connect(function()
		if jugador:GetAttribute("Zona") ~= "Partida" and activa then
			activa.fin()
		end
	end)
end

return Serpiente
