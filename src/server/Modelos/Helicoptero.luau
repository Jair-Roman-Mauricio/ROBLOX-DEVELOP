--!strict
--[[
	Helicóptero turístico de la expedición (librea blanca, naranja y turquesa).
	Casco curvo hecho con elipsoides, cabina de cristal con asientos, carenado del motor con
	escapes, rotor de cuatro palas con puntas amarillas, botalón cónico, deriva, estabilizador,
	rotor de cola, patines y luces de navegación.

	Convención: `cf` en el suelo, morro hacia -Z. Hijos con nombre fijo que usa la cinemática:
	  Rotor (Model, eje vertical) · RotorCola (Model, eje X) · Cabina (Attachment para embarcar)
	`estrellado` lo ensucia, lo inclina, rompe palas y cola, y añade humo, fuego y restos.
]]

local Kit = require(script.Parent.Kit)

local M = Enum.Material

local Helicoptero = {}

local SIN = { colision = false } :: Kit.Opciones

function Helicoptero.construir(rng: Random, cf: CFrame, padre: Instance, estrellado: boolean): Model
	local m = Kit.modelo(if estrellado then "HelicopteroEstrellado" else "Helicoptero", padre)
	local sucio = Color3.fromRGB(46, 42, 36)
	local function tono(c: Color3): Color3
		return if estrellado then c:Lerp(sucio, 0.35) else c
	end
	local BLANCO = tono(Color3.fromRGB(238, 236, 228))
	local NARANJA = tono(Color3.fromRGB(228, 108, 36))
	local TURQUESA = tono(Color3.fromRGB(24, 124, 132))
	local GRIS = tono(Color3.fromRGB(64, 68, 70))
	local NEGRO = Color3.fromRGB(24, 26, 28)
	local CROMO = Color3.fromRGB(176, 178, 176)
	local VIDRIO = Color3.fromRGB(36, 58, 70)
	local LISO = M.SmoothPlastic

	local base = cf
	if estrellado then
		base = cf * CFrame.new(0, -1.4, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(17))
	end
	local function c(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local function p(x: number, y: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end

	-- colisión simple del fuselaje (los elipsoides no colisionan)
	Kit.parte(m, c(0, 4.6, -0.4), Vector3.new(6.6, 6.2, 13.5), Color3.new(), LISO, {
		transparencia = 1,
		sombra = false,
		nombre = "Colision",
	})

	-- casco: blanco arriba, panza naranja, franja turquesa
	Kit.ovoide(m, c(0, 5.0, -0.5), Vector3.new(7.4, 7.2, 15.6), BLANCO, LISO, SIN)
	Kit.ovoide(m, c(0, 3.2, -0.3), Vector3.new(7.55, 4.6, 15.2), NARANJA, LISO, SIN)
	Kit.ovoide(m, c(0, 4.35, -0.6), Vector3.new(7.62, 0.55, 14.8), TURQUESA, LISO, SIN)
	-- carenado bajo el rotor
	Kit.ovoide(m, c(0, 8.3, 1.4), Vector3.new(4.8, 3, 9.4), BLANCO, LISO, SIN)
	Kit.ovoide(m, c(0, 5.7, 6.4), Vector3.new(3.4, 3.4, 6.4), BLANCO, LISO, SIN)

	-- cristales: burbuja delantera y banda de ventanas
	local transparenciaVidrio = if estrellado then 0.7 else 0.3
	Kit.ovoide(m, c(0, 6.0, -5.5), Vector3.new(6.5, 5.1, 7.2), VIDRIO, M.Glass, {
		colision = false,
		transparencia = transparenciaVidrio,
		reflejo = 0.25,
	})
	Kit.ovoide(m, c(0, 6.4, -1.6), Vector3.new(7.56, 2.5, 11.2), VIDRIO, M.Glass, {
		colision = false,
		transparencia = transparenciaVidrio,
		reflejo = 0.25,
	})
	-- montante central del parabrisas y marcos de las puertas
	Kit.ovoide(m, c(0, 6.0, -5.5), Vector3.new(0.35, 5.25, 7.35), BLANCO, LISO, SIN)
	for _, z in { -2.4, 2.2 } do
		Kit.ovoide(m, c(0, 5.0, z), Vector3.new(7.7, 7.3, 0.35), GRIS, LISO, SIN)
	end
	-- puerta corrediza de estribor (+X); la cinemática de embarque la desliza hacia la cola
	if not estrellado then
		local puerta = Kit.modelo("Puerta", m)
		local hoja = Kit.parte(puerta, c(3.84, 4.9, -0.1), Vector3.new(0.2, 4.6, 4), BLANCO, LISO, {
			nombre = "Hoja",
			colision = false,
		})
		puerta.PrimaryPart = hoja
		Kit.parte(puerta, c(3.86, 6.0, -0.1), Vector3.new(0.22, 1.7, 2.8), VIDRIO, M.Glass, {
			colision = false,
			transparencia = 0.3,
			reflejo = 0.25,
		})
		Kit.parte(puerta, c(3.86, 4.35, -0.1), Vector3.new(0.22, 0.32, 4), TURQUESA, LISO, SIN)
		Kit.parte(puerta, c(3.97, 5.0, -1.4), Vector3.new(0.14, 0.22, 0.9), CROMO, M.Metal, SIN)
		Kit.cilindro(m, p(3.9, 7.35, -2.3), p(3.9, 7.35, 4.4), 0.18, GRIS, M.Metal, SIN)
	end
	for _, s in { -1, 1 } do
		Kit.parte(m, c(s * 3.78, 5.1, -0.4), Vector3.new(0.14, 0.22, 0.9), CROMO, M.Metal, SIN)
		-- rejilla de admisión del motor
		for k = 0, 3 do
			Kit.parte(m, c(s * 2.25, 8.4 + k * 0.28, 0), Vector3.new(0.2, 0.12, 2.2), NEGRO, M.Metal, SIN)
		end
		-- escapes
		Kit.cilindro(m, p(s * 1.3, 8.9, 5.2), p(s * 1.7, 9.7, 6.9), 1.05, GRIS, M.Metal, SIN)
		Kit.cilindro(m, p(s * 1.68, 9.66, 6.82), p(s * 1.72, 9.74, 7.0), 0.8, NEGRO, M.Metal, SIN)
	end

	-- interior visible a través del cristal
	local tapiz = Color3.fromRGB(40, 36, 34)
	for _, z in { -2.6, 0.6 } do
		for _, x in { -1.6, 1.6 } do
			Kit.parte(m, c(x, 3.9, z), Vector3.new(1.8, 0.6, 1.8), tapiz, M.Fabric, SIN)
			Kit.parte(m, c(x, 5.0, z + 0.9), Vector3.new(1.8, 2.2, 0.4), tapiz, M.Fabric, SIN)
		end
	end
	local panel = Kit.parte(m, c(0, 5.1, -5.0), Vector3.new(5, 1, 1), NEGRO, LISO, SIN)
	local pantalla = Kit.parte(
		m,
		panel.CFrame * CFrame.new(0, 0.2, -0.51),
		Vector3.new(3.6, 0.5, 0.05),
		Color3.fromRGB(120, 220, 255),
		M.Neon,
		SIN
	)
	pantalla.Transparency = if estrellado then 0.8 else 0.2

	-- botalón cónico con banda naranja
	Kit.cilindro(m, p(0, 5.8, 6.5), p(0, 6.6, 13), 2.5, BLANCO, LISO)
	if not estrellado then
		Kit.cilindro(m, p(0, 6.6, 13), p(0, 7.2, 19), 1.9, BLANCO, LISO)
		Kit.cilindro(m, p(0, 7.2, 19), p(0, 7.6, 23.6), 1.4, BLANCO, LISO)
		Kit.cilindro(m, p(0, 7.25, 19.6), p(0, 7.4, 21.4), 1.55, NARANJA, LISO, SIN)
		Kit.parte(m, c(0, 7.1, 20.2), Vector3.new(6.8, 0.3, 1.5), BLANCO, LISO)
		for _, s in { -1, 1 } do
			Kit.parte(m, c(s * 3.4, 7.1, 20.3), Vector3.new(0.25, 1.8, 1.4), NARANJA, LISO)
			-- luces de navegación: roja a babor (-X), verde a estribor (+X)
			local nav = Kit.parte(
				m,
				c(s * 3.55, 7.9, 20.3),
				Vector3.one * 0.35,
				if s < 0 then Color3.fromRGB(255, 50, 40) else Color3.fromRGB(60, 255, 110),
				M.Neon,
				{ forma = Enum.PartType.Ball, colision = false, sombra = false }
			)
			Kit.luz(nav, nav.Color, 6, 1)
		end
		Kit.parte(m, c(0, 10.3, 23.4), Vector3.new(0.4, 5.6, 3.2), NARANJA, LISO, { cuna = true })
		Kit.parte(m, c(0, 6.1, 23.7), Vector3.new(0.35, 1.8, 1.4), NARANJA, LISO, SIN)
		local estrobo = Kit.parte(m, c(0, 13.2, 24.6), Vector3.one * 0.35, Color3.new(1, 1, 1), M.Neon, {
			forma = Enum.PartType.Ball,
			colision = false,
			sombra = false,
		})
		Kit.etiquetar(estrobo, "Baliza")

		-- matrícula
		for _, cara in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = cara
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			local placa = m:FindFirstChild("Matricula") :: BasePart?
			if not placa then
				placa = Kit.parte(m, c(0, 6.9, 15.6), Vector3.new(2.0, 0.8, 4), BLANCO, LISO, {
					colision = false,
					transparencia = 1,
					nombre = "Matricula",
				})
			end
			gui.Parent = placa
			local texto = Instance.new("TextLabel")
			texto.BackgroundTransparency = 1
			texto.Size = UDim2.fromScale(1, 1)
			texto.Font = Enum.Font.GothamBold
			texto.TextScaled = true
			texto.TextColor3 = Color3.fromRGB(30, 34, 36)
			texto.Text = "AMZ-07"
			texto.Parent = gui
		end

		-- rotor de cola
		local cola = Kit.modelo("RotorCola", m)
		local eje = Kit.cilindro(cola, p(0.2, 9.6, 23.6), p(0.75, 9.6, 23.6), 0.6, GRIS, M.Metal, SIN)
		eje.Name = "Eje"
		cola.PrimaryPart = eje
		Kit.parte(cola, c(0.7, 9.6, 23.6), Vector3.new(0.15, 4.4, 0.45), NEGRO, M.Metal, SIN)
		Kit.parte(cola, c(0.7, 9.6, 23.6), Vector3.new(0.15, 0.45, 4.4), NEGRO, M.Metal, SIN)
	end

	-- patines
	for _, z in { -3.2, 3.4 } do
		Kit.cilindro(m, p(-2.3, 2.0, z), p(2.3, 2.0, z), 0.45, GRIS, M.Metal, SIN)
		for _, s in { -1, 1 } do
			Kit.cilindro(m, p(s * 2.3, 2.0, z), p(s * 3.5, 0.45, z), 0.45, GRIS, M.Metal, SIN)
		end
	end
	for _, s in { -1, 1 } do
		Kit.cilindro(m, p(s * 3.5, 0.4, -6.4), p(s * 3.5, 0.4, 7), 0.55, GRIS, M.Metal)
		Kit.cilindro(m, p(s * 3.5, 0.4, -6.4), p(s * 3.5, 1.3, -8), 0.55, GRIS, M.Metal, SIN)
		Kit.parte(m, c(s * 3.5, 0.75, -0.5), Vector3.new(0.9, 0.15, 1.8), NEGRO, M.DiamondPlate, SIN)
	end

	-- mástil, plato oscilante y rotor principal
	Kit.cilindro(m, p(0, 9.6, 0.5), p(0, 11.6, 0.5), 0.7, GRIS, M.Metal, SIN)
	Kit.parte(m, c(0, 10.6, 0.5) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 1.8, 1.8), CROMO, M.Metal, {
		forma = Enum.PartType.Cylinder,
		colision = false,
	})
	local antena = Kit.cilindro(m, p(0, 9.6, 4.2), p(0, 10.9, 4.6), 0.12, NEGRO, M.Metal, SIN)
	antena.Name = "Antena"
	local baliza = Kit.parte(m, c(0, 9.85, 3.2), Vector3.new(0.5, 0.35, 0.5), Color3.fromRGB(255, 40, 30), M.Neon, {
		colision = false,
		sombra = false,
	})
	Kit.luz(baliza, Color3.fromRGB(255, 50, 40), 14, 1.6)
	Kit.etiquetar(baliza, "Baliza")

	local rotor = Kit.modelo("Rotor", m)
	local eje = Kit.parte(
		rotor,
		c(0, 11.7, 0.5),
		Vector3.new(1.7, 0.7, 1.7),
		GRIS,
		M.Metal,
		{ nombre = "Eje", colision = false }
	)
	rotor.PrimaryPart = eje
	Kit.ovoide(rotor, c(0, 12.15, 0.5), Vector3.new(1.2, 0.8, 1.2), BLANCO, LISO)
	for i = 1, 4 do
		local roto = estrellado and i >= 3
		if not roto then
			local a = i / 4 * math.pi * 2
			local largo = if estrellado and i == 2 then 7 else 17
			local giro = c(0, 11.75, 0.5) * CFrame.Angles(0, a, 0)
			Kit.parte(
				rotor,
				giro * CFrame.new(0, -largo * 0.02, -largo / 2 - 0.7) * CFrame.Angles(math.rad(2), 0, 0),
				Vector3.new(1.1, 0.18, largo),
				NEGRO,
				M.SmoothPlastic,
				SIN
			)
			if largo > 10 then
				Kit.parte(
					rotor,
					giro * CFrame.new(0, -largo * 0.04, -largo - 0.2),
					Vector3.new(1.12, 0.2, 1),
					Color3.fromRGB(240, 200, 40),
					M.SmoothPlastic,
					SIN
				)
			end
		end
	end

	-- punto de embarque
	local cabina = Instance.new("Attachment")
	cabina.Name = "Cabina"
	cabina.Parent = Kit.parte(m, c(0, 4.6, -0.5), Vector3.one, Color3.new(), LISO, {
		transparencia = 1,
		colision = false,
		consulta = false,
		nombre = "Interior",
	})

	if estrellado then
		-- cola arrancada en el suelo
		local trozo = cf
			* CFrame.new(rng:NextNumber(6, 10), 1.3, rng:NextNumber(20, 26))
			* CFrame.Angles(0.15, rng:NextNumber(-0.7, 0.7), 0.45)
		Kit.cilindro(m, trozo.Position, (trozo * CFrame.new(0, 0, 8)).Position, 1.7, BLANCO, LISO)
		Kit.parte(m, trozo * CFrame.new(0, 2.6, 7.8), Vector3.new(0.4, 5.4, 3.1), NARANJA, LISO, { cuna = true })
		-- pala clavada
		Kit.parte(
			m,
			cf
				* CFrame.new(rng:NextNumber(-16, -11), 3, rng:NextNumber(-6, 6))
				* CFrame.Angles(0.9, rng:NextNumber(0, 6), 0.2),
			Vector3.new(1.1, 0.18, 15),
			NEGRO,
			M.SmoothPlastic
		)
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(8, 22)
			Kit.parte(
				m,
				cf
					* CFrame.new(math.cos(a) * r, 0.3, math.sin(a) * r)
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)),
				Vector3.new(rng:NextNumber(1, 3.5), 0.2, rng:NextNumber(1, 3)),
				Kit.elegir(rng, { BLANCO, NARANJA, GRIS }),
				M.CorrodedMetal
			)
		end
		local motor = Kit.parte(m, c(0, 8.6, 2), Vector3.new(3, 1.5, 4), NEGRO, M.CorrodedMetal, SIN)
		local humo = Instance.new("Smoke")
		humo.Color = Color3.fromRGB(40, 40, 40)
		humo.Opacity = 0.22
		humo.RiseVelocity = 5
		humo.Size = 7
		humo.Parent = motor
		local fuego = Instance.new("Fire")
		fuego.Size = 3
		fuego.Heat = 6
		fuego.Parent = motor
		Kit.luz(motor, Color3.fromRGB(255, 160, 90), 22, 1.6)
		Kit.etiquetar(motor, "Antorcha")
	end
	return m
end

return Helicoptero
