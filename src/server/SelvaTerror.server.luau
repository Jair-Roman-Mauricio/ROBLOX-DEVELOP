--[[
	SELVA DE TERROR — demo de mapa para juego de terror

	Genera por código una selva nocturna: terreno con pantanos, árboles, lianas, niebla,
	linterna en primera persona y ojos rojos que acechan al jugador.

	ESTÁ APAGADA POR DEFECTO, porque borra el terreno y el Baseplate del place.
	Para verla:
	  1. Usa un place nuevo (o una copia), conectado con Rojo.
	  2. En el Explorer selecciona Workspace > Properties > Attributes > "+" y crea
	     un atributo booleano llamado DemoSelva marcado en true.
	  3. Dale Play.

	Para que la selva quede guardada en el place (y editarla a mano): con el atributo puesto,
	pega este archivo en la Command Bar (View > Command Bar) en modo edición y pulsa Enter.
	Al jugar ya no se regenera; solo se activan linterna, ojos y sonidos.
]]

if workspace:GetAttribute("DemoSelva") ~= true then
	return
end

local CONFIG = {
	SEMILLA = 1337,        -- cambia el número para otra selva distinta
	TAMANO = 512,          -- lado del mapa en studs
	CELDA = 8,             -- resolución del terreno (más bajo = más detalle, más lento)
	ARBOLES = 260,
	ARBUSTOS = 450,
	TRONCOS_CAIDOS = 25,
	PARES_DE_OJOS = 12,
	RADIO_CLARO = 28,      -- claro sin árboles donde aparece el jugador
	NIVEL_AGUA = 4,        -- altura del agua de los pantanos
	PRIMERA_PERSONA = true,
	LINTERNA = true,
	SONIDOS = {
		-- Pega aquí IDs de audio del Creator Store, por ejemplo "rbxassetid://123456789"
		Ambiente = "",     -- selva de noche / grillos (en bucle)
		Viento = "",       -- viento o zumbido grave (en bucle)
	},
}

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Terrain = workspace.Terrain

local rng = Random.new(CONFIG.SEMILLA)
local MITAD = CONFIG.TAMANO / 2
local BASE_Y = -20

local COLOR_TRONCO = {
	Color3.fromRGB(52, 40, 30),
	Color3.fromRGB(40, 33, 27),
	Color3.fromRGB(60, 48, 36),
}
local COLOR_HOJAS = {
	Color3.fromRGB(28, 45, 25),
	Color3.fromRGB(22, 38, 22),
	Color3.fromRGB(35, 50, 28),
}

local function elegir(t)
	return t[rng:NextInteger(1, #t)]
end

-- ===================== TERRENO =====================

local function altura(x, z)
	local s = CONFIG.SEMILLA * 0.01
	local h = 10
		+ math.noise(x / 140, z / 140, s) * 18
		+ math.noise(x / 45, z / 45, s + 5.3) * 6
		+ math.noise(x / 15, z / 15, s + 9.7) * 1.5
	-- aplanar el claro central donde aparece el jugador
	local d = math.sqrt(x * x + z * z)
	local t = math.clamp((d - CONFIG.RADIO_CLARO) / 40, 0, 1)
	return 12 + (h - 12) * t
end

local function generarTerreno()
	Terrain:Clear()
	local c = CONFIG.CELDA
	local fila = 0
	for x = -MITAD, MITAD - c, c do
		for z = -MITAD, MITAD - c, c do
			local cx, cz = x + c / 2, z + c / 2
			local h = altura(cx, cz)
			local material
			if h < CONFIG.NIVEL_AGUA + 1 then
				material = Enum.Material.Mud
			elseif math.noise(cx / 30, cz / 30, 3.1) > 0.25 then
				material = Enum.Material.Ground
			else
				material = Enum.Material.LeafyGrass
			end
			local alto = h - BASE_Y
			Terrain:FillBlock(CFrame.new(cx, BASE_Y + alto / 2, cz), Vector3.new(c, alto, c), material)
			if h < CONFIG.NIVEL_AGUA then
				local prof = CONFIG.NIVEL_AGUA - h
				Terrain:FillBlock(CFrame.new(cx, h + prof / 2, cz), Vector3.new(c, prof, c), Enum.Material.Water)
			end
		end
		fila += 1
		if fila % 8 == 0 then
			task.wait()
		end
	end

	pcall(function()
		Terrain.Decoration = true -- pasto animado
	end)
	Terrain.WaterColor = Color3.fromRGB(35, 45, 30)
	Terrain.WaterTransparency = 0.15
	Terrain.WaterReflectance = 0.05
	Terrain.WaterWaveSize = 0.05
	Terrain.WaterWaveSpeed = 4
	pcall(function()
		Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(45, 60, 35))
		Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(55, 45, 35))
		Terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(45, 38, 30))
	end)
end

local paramsSuelo = RaycastParams.new()
paramsSuelo.FilterType = Enum.RaycastFilterType.Include
paramsSuelo.FilterDescendantsInstances = { Terrain }
paramsSuelo.IgnoreWater = false

-- Devuelve el punto del suelo en (x, z), o nil si cae en agua
local function suelo(x, z)
	local r = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), paramsSuelo)
	if r and r.Material ~= Enum.Material.Water then
		return r.Position
	end
	return nil
end

local function puntoAleatorio(margen)
	return rng:NextNumber(-MITAD + margen, MITAD - margen), rng:NextNumber(-MITAD + margen, MITAD - margen)
end

-- ===================== PIEZAS =====================

local function parte(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

-- Cilindro que nace en cf y crece hacia el eje Y de cf
local function cilindro(cf, largo, grosor, color, padre)
	local p = parte({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(largo, grosor, grosor),
		CFrame = cf * CFrame.new(0, largo / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Wood,
	})
	p.Parent = padre
	return p
end

local function crearArbol(pos, padre)
	local modelo = Instance.new("Model")
	modelo.Name = "Arbol"
	local muerto = rng:NextNumber() < 0.25
	local alto = rng:NextNumber(30, 65)
	local grosor = rng:NextNumber(2.5, 5)
	local base = CFrame.new(pos - Vector3.new(0, 2, 0))
		* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.08, 0.08))
	local colorTronco = muerto and Color3.fromRGB(45, 42, 40) or elegir(COLOR_TRONCO)

	cilindro(base, alto, grosor, colorTronco, modelo)

	-- raíces que bajan hacia el suelo
	local nRaices = rng:NextInteger(3, 5)
	for i = 1, nRaices do
		local ang = (i / nRaices) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local cf = base
			* CFrame.Angles(0, ang, 0)
			* CFrame.new(0, 3, 0)
			* CFrame.Angles(math.rad(rng:NextNumber(105, 125)), 0, 0)
		cilindro(cf, rng:NextNumber(6, 10), grosor * 0.45, colorTronco, modelo).CanCollide = false
	end

	local cima = base * CFrame.new(0, alto, 0)
	if muerto then
		-- ramas secas
		for _ = 1, rng:NextInteger(2, 4) do
			local h = alto * rng:NextNumber(0.55, 0.95)
			local cf = base
				* CFrame.new(0, h, 0)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				* CFrame.Angles(math.rad(rng:NextNumber(40, 75)), 0, 0)
			cilindro(cf, rng:NextNumber(8, 16), grosor * 0.35, colorTronco, modelo).CanCollide = false
		end
	else
		-- copa
		for _ = 1, rng:NextInteger(4, 7) do
			local d = rng:NextNumber(14, 26)
			local off = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-4, 5), rng:NextNumber(-10, 10))
			parte({
				Name = "Hojas",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(d, d, d),
				Position = cima.Position + off,
				Color = elegir(COLOR_HOJAS),
				Material = Enum.Material.Grass,
				CanCollide = false,
			}).Parent = modelo
		end
		-- lianas colgando
		for _ = 1, rng:NextInteger(2, 6) do
			local largo = rng:NextNumber(10, alto * 0.6)
			local p0 = cima.Position + Vector3.new(rng:NextNumber(-9, 9), -4, rng:NextNumber(-9, 9))
			parte({
				Name = "Liana",
				Size = Vector3.new(0.3, largo, 0.3),
				Position = p0 - Vector3.new(0, largo / 2, 0),
				Color = Color3.fromRGB(40, 55, 30),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CastShadow = false,
			}).Parent = modelo
		end
	end

	modelo.Parent = padre
end

local function crearArbusto(pos, padre)
	local d = rng:NextNumber(3, 8)
	parte({
		Name = "Arbusto",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(d, d, d),
		Position = pos + Vector3.new(0, d * 0.2, 0),
		Color = elegir(COLOR_HOJAS),
		Material = Enum.Material.Grass,
		CanCollide = false,
		CastShadow = false,
	}).Parent = padre
end

local function crearTroncoCaido(pos, padre)
	local largo = rng:NextNumber(14, 28)
	local g = rng:NextNumber(2, 3.5)
	parte({
		Name = "TroncoCaido",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(largo, g, g),
		CFrame = CFrame.new(pos + Vector3.new(0, g * 0.3, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.1, 0.1)),
		Color = Color3.fromRGB(48, 40, 32),
		Material = Enum.Material.Wood,
	}).Parent = padre
end

-- Coloca n objetos en puntos válidos fuera del claro central
local function poblar(n, fn, padre, radioLibre)
	local puestos, intentos = 0, 0
	while puestos < n and intentos < n * 4 do
		intentos += 1
		local x, z = puntoAleatorio(6)
		if math.sqrt(x * x + z * z) > radioLibre then
			local p = suelo(x, z)
			if p then
				fn(p, padre)
				puestos += 1
				if puestos % 25 == 0 then
					task.wait()
				end
			end
		end
	end
end

-- ===================== OJOS EN LA OSCURIDAD =====================

local function colocarOjos(m, pos, mirarA)
	local cf
	if mirarA then
		cf = CFrame.lookAt(pos, Vector3.new(mirarA.X, pos.Y, mirarA.Z))
	else
		cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	m.Izq.CFrame = cf * CFrame.new(-0.4, 0, 0)
	m.Der.CFrame = cf * CFrame.new(0.4, 0, 0)
	m:SetAttribute("Pos", pos)
end

-- Mueve los ojos a un punto nuevo; si se da "acecharA", aparecen a 50-90 studs de esa posición
local function moverOjos(m, acecharA)
	for _ = 1, 25 do
		local x, z
		if acecharA then
			local ang = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(50, 90)
			x = math.clamp(acecharA.X + math.cos(ang) * dist, -MITAD + 10, MITAD - 10)
			z = math.clamp(acecharA.Z + math.sin(ang) * dist, -MITAD + 10, MITAD - 10)
		else
			x, z = puntoAleatorio(20)
		end
		local p = suelo(x, z)
		if p and math.sqrt(p.X * p.X + p.Z * p.Z) > CONFIG.RADIO_CLARO + 15 then
			colocarOjos(m, p + Vector3.new(0, rng:NextNumber(3, 6), 0), acecharA)
			return
		end
	end
end

local function crearOjos(carpeta)
	local carpetaOjos = Instance.new("Folder")
	carpetaOjos.Name = "Ojos"
	carpetaOjos.Parent = carpeta
	for _ = 1, CONFIG.PARES_DE_OJOS do
		local m = Instance.new("Model")
		m.Name = "ParDeOjos"
		for _, nombre in ipairs({ "Izq", "Der" }) do
			parte({
				Name = nombre,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.35, 0.35, 0.35),
				Color = Color3.fromRGB(255, 30, 20),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			}).Parent = m
		end
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 40, 30)
		luz.Range = 4
		luz.Brightness = 1
		luz.Parent = m.Izq
		m.Parent = carpetaOjos
		moverOjos(m)
	end
end

-- Los ojos te miran; si te acercas a menos de 25 studs desaparecen y reaparecen en otro lado, acechándote
local function animarOjos(carpetaOjos)
	while true do
		for _, m in ipairs(carpetaOjos:GetChildren()) do
			local pos = m:GetAttribute("Pos")
			if pos then
				local cercano, dist = nil, math.huge
				for _, pl in ipairs(Players:GetPlayers()) do
					local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						local d = (hrp.Position - pos).Magnitude
						if d < dist then
							cercano, dist = hrp.Position, d
						end
					end
				end

				if cercano and dist < 25 then
					moverOjos(m, cercano)
				elseif cercano and dist < 120 then
					colocarOjos(m, pos, cercano)
				end

				-- parpadeo
				if rng:NextNumber() < 0.04 then
					m.Izq.Transparency, m.Der.Transparency = 1, 1
					task.delay(0.12, function()
						m.Izq.Transparency, m.Der.Transparency = 0, 0
					end)
				end
			end
		end
		task.wait(0.25)
	end
end

-- ===================== AMBIENTE =====================

local function configurarAmbiente()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(10, 14, 10)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 36, 28)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.Technology = Enum.Technology.Future -- solo funciona en modo edición
	end)

	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("Atmosphere") or e.Name:sub(1, 5) == "Selva" then
			e:Destroy()
		end
	end

	local atm = Instance.new("Atmosphere")
	atm.Density = 0.5
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(70, 85, 70)
	atm.Decay = Color3.fromRGB(25, 35, 25)
	atm.Glare = 0
	atm.Haze = 2.5
	atm.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SelvaColor"
	cc.Saturation = -0.35
	cc.Contrast = 0.15
	cc.Brightness = -0.03
	cc.TintColor = Color3.fromRGB(205, 225, 205)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SelvaBloom"
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	if CONFIG.PRIMERA_PERSONA then
		StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

local function crearSpawnYLimites(carpeta)
	-- desactivar otros spawns para que siempre aparezcas en el claro
	for _, s in ipairs(workspace:GetDescendants()) do
		if s:IsA("SpawnLocation") then
			s.Enabled = false
		end
	end

	local centro = suelo(0, 0) or Vector3.new(0, 12, 0)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "SpawnSelva"
	sp.Anchored = true
	sp.Size = Vector3.new(6, 1, 6)
	sp.Position = centro + Vector3.new(0, 1, 0)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Neutral = true
	sp.Duration = 0
	sp.Parent = carpeta

	-- paredes invisibles en el borde del mapa
	local limites = Instance.new("Folder")
	limites.Name = "Limites"
	limites.Parent = carpeta
	local alto, grosor = 300, 4
	for _, d in ipairs({
		{ Vector3.new(MITAD, 0, 0), Vector3.new(grosor, alto, CONFIG.TAMANO) },
		{ Vector3.new(-MITAD, 0, 0), Vector3.new(grosor, alto, CONFIG.TAMANO) },
		{ Vector3.new(0, 0, MITAD), Vector3.new(CONFIG.TAMANO, alto, grosor) },
		{ Vector3.new(0, 0, -MITAD), Vector3.new(CONFIG.TAMANO, alto, grosor) },
	}) do
		parte({ Name = "Pared", Position = d[1], Size = d[2], Transparency = 1, CastShadow = false }).Parent = limites
	end
end

local function crearSonidos(carpeta)
	for nombre, id in pairs(CONFIG.SONIDOS) do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "Sonido" .. nombre
			s.SoundId = id
			s.Looped = true
			s.Volume = 0.5
			s.Parent = carpeta
			if RunService:IsRunning() then
				s:Play()
			end
		end
	end
end

-- ===================== JUGADORES =====================

local function alAparecerPersonaje(char)
	if not CONFIG.LINTERNA then
		return
	end
	local head = char:WaitForChild("Head", 10)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not head or not hrp then
		return
	end
	local linterna = Instance.new("SpotLight")
	linterna.Name = "Linterna"
	linterna.Brightness = 4
	linterna.Range = 45
	linterna.Angle = 45
	linterna.Face = Enum.NormalId.Front
	linterna.Shadows = true
	linterna.Color = Color3.fromRGB(255, 240, 210)
	linterna.Parent = head

	-- un brillo muy tenue alrededor para no quedar a ciegas
	local halo = Instance.new("PointLight")
	halo.Brightness = 0.3
	halo.Range = 10
	halo.Parent = hrp
end

local function alEntrarJugador(pl)
	if CONFIG.PRIMERA_PERSONA then
		pl.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	pl.CharacterAdded:Connect(alAparecerPersonaje)
	if pl.Character then
		task.spawn(alAparecerPersonaje, pl.Character)
	end
end

-- ===================== GENERAR =====================

local function generar()
	local vieja = workspace:FindFirstChild("SelvaTerror")
	if vieja then
		vieja:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local carpeta = Instance.new("Folder")
	carpeta.Name = "SelvaTerror"
	carpeta.Parent = workspace

	configurarAmbiente()
	generarTerreno()

	local arboles = Instance.new("Folder")
	arboles.Name = "Arboles"
	arboles.Parent = carpeta
	poblar(CONFIG.ARBOLES, crearArbol, arboles, CONFIG.RADIO_CLARO)

	local maleza = Instance.new("Folder")
	maleza.Name = "Maleza"
	maleza.Parent = carpeta
	poblar(CONFIG.ARBUSTOS, crearArbusto, maleza, CONFIG.RADIO_CLARO * 0.6)
	poblar(CONFIG.TRONCOS_CAIDOS, crearTroncoCaido, maleza, CONFIG.RADIO_CLARO)

	crearSpawnYLimites(carpeta)
	crearOjos(carpeta)
	crearSonidos(carpeta)
	print("[SelvaTerror] Selva generada.")
	return carpeta
end

if RunService:IsRunning() then
	-- Durante el juego: genera la selva si no existe, luego activa linterna, ojos y sonidos
	local carpeta = workspace:FindFirstChild("SelvaTerror")
	if not carpeta then
		Players.CharacterAutoLoads = false -- que nadie aparezca antes de que exista el suelo
		carpeta = generar()
		Players.CharacterAutoLoads = true
		for _, pl in ipairs(Players:GetPlayers()) do
			if not pl.Character then
				pl:LoadCharacter()
			end
		end
	else
		for _, s in ipairs(carpeta:GetChildren()) do
			if s:IsA("Sound") then
				s:Play()
			end
		end
	end

	Players.PlayerAdded:Connect(alEntrarJugador)
	for _, pl in ipairs(Players:GetPlayers()) do
		alEntrarJugador(pl)
	end

	local carpetaOjos = carpeta:FindFirstChild("Ojos")
	if carpetaOjos then
		task.spawn(animarOjos, carpetaOjos)
	end
else
	-- Desde la Command Bar en modo edición: solo genera y queda guardada en el lugar
	generar()
end
