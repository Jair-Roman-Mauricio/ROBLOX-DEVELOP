--!strict
--[[
	Piezas de la base de expediciones del lobby: torre de control, pabellón de operaciones,
	jeep, depósito de combustible, muelle con canoas, faroles y manga de viento.
	Convención: `cf` en el suelo, frente hacia -Z.
]]

local Estructuras = require(script.Parent.Estructuras)
local Kit = require(script.Parent.Kit)

local M = Enum.Material

local MADERA = Color3.fromRGB(96, 74, 52)
local TABLA = Color3.fromRGB(128, 98, 66)
local CHAPA = Color3.fromRGB(118, 108, 96)
local LUZ_CALIDA = Color3.fromRGB(255, 196, 130)
local VIDRIO = Color3.fromRGB(60, 84, 96)

local Campamento = {}

local function punto(cf: CFrame, x: number, y: number, z: number): Vector3
	return cf:PointToWorldSpace(Vector3.new(x, y, z))
end

-- Farol en poste con luz cálida.
function Campamento.farol(cf: CFrame, padre: Instance, conLuz: boolean?): Model
	local m = Kit.modelo("Farol", padre)
	Kit.cilindro(m, punto(cf, 0, -0.5, 0), punto(cf, 0, 6, 0), 0.35, MADERA, M.Wood)
	Kit.parte(m, cf * CFrame.new(0.7, 6, 0), Vector3.new(1.6, 0.25, 0.25), MADERA, M.Wood)
	local farol = Kit.parte(
		m,
		cf * CFrame.new(1.3, 5.3, 0),
		Vector3.new(0.7, 1, 0.7),
		LUZ_CALIDA,
		M.Neon,
		{ colision = false, sombra = false, nombre = "Llama" }
	)
	Kit.parte(
		m,
		cf * CFrame.new(1.3, 5.9, 0),
		Vector3.new(0.9, 0.2, 0.9),
		Color3.fromRGB(40, 36, 32),
		M.Metal,
		Kit.FOLLAJE
	)
	if conLuz ~= false then
		Kit.luz(farol, LUZ_CALIDA, 20, 1.2)
		Kit.etiquetar(farol, "Antorcha")
	end
	return m
end

function Campamento.mangaViento(cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("MangaViento", padre)
	Kit.cilindro(m, punto(cf, 0, -1, 0), punto(cf, 0, 12, 0), 0.4, Color3.fromRGB(200, 200, 196), M.Metal)
	local manga = Kit.modelo("Manga", m)
	local eje =
		Kit.parte(manga, cf * CFrame.new(0, 12, 0), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(60, 60, 60), M.Metal, {
			nombre = "Eje",
			colision = false,
		})
	manga.PrimaryPart = eje
	for k = 0, 4 do
		local d = 1.6 - k * 0.22
		local color = if k % 2 == 0 then Color3.fromRGB(240, 110, 30) else Color3.fromRGB(240, 236, 228)
		Kit.cilindro(
			manga,
			punto(cf, 0.3, 11.9 - k * 0.12, k * 1.1),
			punto(cf, 0.3, 11.8 - k * 0.12, k * 1.1 + 1.1),
			d,
			color,
			M.Fabric,
			Kit.FOLLAJE
		)
	end
	Kit.etiquetar(manga, "Manga")
	return m
end

-- Torre de control de madera con cabina acristalada, focos hacia los helipuertos y baliza.
function Campamento.torre(cf: CFrame, padre: Instance, objetivos: { Vector3 }): Model
	local m = Kit.modelo("TorreControl", padre)
	local alto = 16
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			Kit.cilindro(m, punto(cf, x * 1.15, -1, z * 1.15), punto(cf, x, alto, z), 0.8, MADERA, M.Wood)
		end
	end
	-- arriostramiento en cruz
	for _, lado in
		{ { -3.5, -3.5, 3.5, -3.5 }, { -3.5, 3.5, 3.5, 3.5 }, { -3.5, -3.5, -3.5, 3.5 }, { 3.5, -3.5, 3.5, 3.5 } }
	do
		Kit.cilindro(m, punto(cf, lado[1], 2, lado[2]), punto(cf, lado[3], alto - 2, lado[4]), 0.35, MADERA, M.Wood)
		Kit.cilindro(m, punto(cf, lado[3], 2, lado[4]), punto(cf, lado[1], alto - 2, lado[2]), 0.35, MADERA, M.Wood)
	end
	Kit.parte(m, cf * CFrame.new(0, alto + 0.3, 0), Vector3.new(10, 0.6, 10), TABLA, M.WoodPlanks)
	-- barandilla
	for _, s in { -1, 1 } do
		Kit.parte(m, cf * CFrame.new(s * 4.9, alto + 1.6, 0), Vector3.new(0.3, 0.3, 10), MADERA, M.Wood)
		Kit.parte(m, cf * CFrame.new(0, alto + 1.6, s * 4.9), Vector3.new(10, 0.3, 0.3), MADERA, M.Wood)
	end
	-- cabina
	local base = cf * CFrame.new(0, alto + 0.6, 0)
	Kit.parte(m, base * CFrame.new(0, 0.8, 0), Vector3.new(7, 1.6, 7), TABLA, M.WoodPlanks)
	Kit.parte(
		m,
		base * CFrame.new(0, 3, 0),
		Vector3.new(6.8, 2.8, 6.8),
		VIDRIO,
		M.Glass,
		{ transparencia = 0.45, reflejo = 0.2 }
	)
	local interior = Kit.parte(m, base * CFrame.new(0, 2.4, 0), Vector3.new(1, 0.4, 1), LUZ_CALIDA, M.Neon, Kit.FOLLAJE)
	Kit.luz(interior, LUZ_CALIDA, 14, 1)
	for _, x in { -3.3, 3.3 } do
		for _, z in { -3.3, 3.3 } do
			Kit.parte(m, base * CFrame.new(x, 3, z), Vector3.new(0.4, 2.8, 0.4), MADERA, M.Wood)
		end
	end
	Kit.parte(m, base * CFrame.new(0, 4.7, 0), Vector3.new(8.4, 0.6, 8.4), CHAPA, M.CorrodedMetal)
	-- antena y baliza
	Kit.cilindro(m, punto(base, 2.5, 5, 2.5), punto(base, 2.5, 11, 2.5), 0.15, Color3.fromRGB(60, 60, 60), M.Metal)
	local baliza =
		Kit.parte(m, base * CFrame.new(2.5, 11.2, 2.5), Vector3.one * 0.5, Color3.fromRGB(255, 50, 40), M.Neon, {
			forma = Enum.PartType.Ball,
			colision = false,
		})
	Kit.luz(baliza, Color3.fromRGB(255, 50, 40), 16, 2)
	Kit.etiquetar(baliza, "Baliza")
	-- escalera
	for k = 0, 13 do
		Kit.parte(m, cf * CFrame.new(0, 1 + k * 1.1, 4.4), Vector3.new(2.4, 0.25, 0.4), MADERA, M.Wood)
	end
	for _, x in { -1.3, 1.3 } do
		Kit.parte(m, cf * CFrame.new(x, alto / 2, 4.4), Vector3.new(0.3, alto, 0.3), MADERA, M.Wood)
	end
	-- focos que iluminan los helipuertos
	for _, objetivo in objetivos do
		local origen = punto(base, 0, 5.4, 0)
		local dir = (objetivo - origen).Unit
		local foco = Kit.parte(
			m,
			CFrame.lookAt(origen + dir * 4.5, objetivo),
			Vector3.new(1.2, 1.2, 1.4),
			Color3.fromRGB(255, 244, 220),
			M.Neon,
			{ colision = false, sombra = false }
		)
		local luz = Instance.new("SpotLight")
		luz.Face = Enum.NormalId.Front
		luz.Angle = 28
		luz.Range = 60
		luz.Brightness = 3
		luz.Color = Color3.fromRGB(255, 236, 200)
		luz.Shadows = true
		luz.Parent = foco
	end
	Campamento.mangaViento(base * CFrame.new(-2.5, 4.4, -2.5), m)
	return m
end

-- Pabellón de operaciones: casa de madera elevada con porche y ventanas iluminadas.
function Campamento.pabellon(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Pabellon", padre)
	local W, D, piso, pared = 22, 14, 2, 8
	for _, x in { -W / 2 + 1, 0, W / 2 - 1 } do
		for _, z in { -D / 2 - 4, -D / 2 + 1, D / 2 - 1 } do
			Kit.cilindro(m, punto(cf, x, -1, z), punto(cf, x, piso, z), 0.9, MADERA, M.Wood)
		end
	end
	Kit.parte(m, cf * CFrame.new(0, piso, -2), Vector3.new(W, 0.6, D + 4), TABLA, M.WoodPlanks)
	-- paredes con ventanas encendidas
	local muro = Color3.fromRGB(150, 116, 80)
	Kit.parte(m, cf * CFrame.new(0, piso + pared / 2, D / 2 - 0.4), Vector3.new(W, pared, 0.6), muro, M.WoodPlanks)
	for _, s in { -1, 1 } do
		Kit.parte(
			m,
			cf * CFrame.new(s * (W / 2 - 0.3), piso + pared / 2, 0),
			Vector3.new(0.6, pared, D - 0.6),
			muro,
			M.WoodPlanks
		)
	end
	-- fachada: muro con puerta y dos ventanas
	local frente = cf * CFrame.new(0, piso, -D / 2 + 0.4)
	Kit.parte(m, frente * CFrame.new(-7.5, pared / 2, 0), Vector3.new(7, pared, 0.6), muro, M.WoodPlanks)
	Kit.parte(m, frente * CFrame.new(7.5, pared / 2, 0), Vector3.new(7, pared, 0.6), muro, M.WoodPlanks)
	Kit.parte(m, frente * CFrame.new(0, pared - 1.2, 0), Vector3.new(8, 2.4, 0.6), muro, M.WoodPlanks)
	Kit.parte(m, frente * CFrame.new(0, 2.8, 0.1), Vector3.new(3.4, 5.6, 0.3), Color3.fromRGB(80, 56, 38), M.Wood)
	for _, x in { -7.5, 7.5 } do
		local ventana = Kit.parte(
			m,
			frente * CFrame.new(x, 4.4, -0.32),
			Vector3.new(3.6, 2.4, 0.1),
			LUZ_CALIDA,
			M.Neon,
			Kit.FOLLAJE
		)
		ventana.Transparency = 0.15
		Kit.luz(ventana, LUZ_CALIDA, 16, 0.9)
		Kit.parte(m, frente * CFrame.new(x, 4.4, -0.4), Vector3.new(0.25, 2.6, 0.12), MADERA, M.Wood, Kit.FOLLAJE)
	end
	-- tejado de chapa a dos aguas sobre casa y porche
	local subida = 4.5
	local angulo = math.atan(subida / (D / 2 + 2.5))
	local largo = math.sqrt((D / 2 + 2.5) ^ 2 + subida ^ 2) + 1.5
	for _, s in { -1, 1 } do
		Kit.parte(
			m,
			cf * CFrame.new(0, piso + pared + subida / 2, -2 + s * (D / 2 + 2.5) / 2) * CFrame.Angles(s * angulo, 0, 0),
			Vector3.new(W + 2, 0.4, largo),
			Kit.variar(CHAPA, rng, 0.04),
			M.CorrodedMetal
		)
	end
	-- postes del porche, barandilla y escalones
	for _, x in { -W / 2 + 1, -4, 4, W / 2 - 1 } do
		Kit.cilindro(m, punto(cf, x, piso, -D / 2 - 4.5), punto(cf, x, piso + pared, -D / 2 - 4.5), 0.5, MADERA, M.Wood)
	end
	for _, x in { -7.5, 7.5 } do
		Kit.parte(m, cf * CFrame.new(x, piso + 1.6, -D / 2 - 4.5), Vector3.new(7, 0.25, 0.25), MADERA, M.Wood)
	end
	for e = 1, 2 do
		Kit.parte(
			m,
			cf * CFrame.new(0, e * 0.9 - 0.4, -D / 2 - 4.6 - (3 - e) * 1),
			Vector3.new(5, 0.4, 1.1),
			TABLA,
			M.WoodPlanks
		)
	end
	-- cartel
	local cartel = Kit.parte(
		m,
		cf * CFrame.new(0, piso + pared + 0.2, -D / 2 - 4.6),
		Vector3.new(11, 1.6, 0.3),
		Color3.fromRGB(60, 44, 32),
		M.WoodPlanks
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = cartel
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.fromScale(1, 1)
	texto.Font = Enum.Font.Merriweather
	texto.TextScaled = true
	texto.TextColor3 = Color3.fromRGB(244, 222, 180)
	texto.Text = "BASE DE OPERACIONES"
	texto.Parent = gui
	-- porche amueblado
	Estructuras.pilaCajas(rng, cf * CFrame.new(-8, piso + 0.3, -D / 2 - 2), m)
	Campamento.farol(cf * CFrame.new(W / 2 + 1, 0, -D / 2 - 5), m)
	return m
end

function Campamento.jeep(cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Jeep", padre)
	local verde = Color3.fromRGB(86, 96, 62)
	local negro = Color3.fromRGB(26, 26, 26)
	Kit.parte(m, cf * CFrame.new(0, 2.6, 0), Vector3.new(6, 1.8, 11), verde, M.Metal)
	Kit.parte(m, cf * CFrame.new(0, 3.4, -3.6), Vector3.new(5.8, 1.2, 3.6), verde, M.Metal)
	Kit.parte(m, cf * CFrame.new(0, 3.2, -5.55), Vector3.new(4.6, 1, 0.2), Color3.fromRGB(40, 40, 40), M.Metal)
	for _, x in { -1.8, 1.8 } do
		Kit.parte(
			m,
			cf * CFrame.new(x, 3.2, -5.62),
			Vector3.new(0.8, 0.8, 0.1),
			Color3.fromRGB(255, 240, 200),
			M.Neon,
			Kit.FOLLAJE
		)
	end
	Kit.parte(
		m,
		cf * CFrame.new(0, 4.6, -1.6),
		Vector3.new(5.8, 2, 0.2),
		Color3.fromRGB(70, 90, 100),
		M.Glass,
		{ transparencia = 0.5 }
	)
	for _, x in { -2.9, 2.9 } do
		Kit.parte(m, cf * CFrame.new(x, 5.4, 1.4), Vector3.new(0.25, 3.6, 0.25), negro, M.Metal)
		Kit.parte(m, cf * CFrame.new(x, 5.4, 5), Vector3.new(0.25, 3.6, 0.25), negro, M.Metal)
	end
	Kit.parte(m, cf * CFrame.new(0, 7.2, 3.2), Vector3.new(6.2, 0.2, 4.2), Color3.fromRGB(150, 130, 90), M.Fabric)
	for _, x in { -3.1, 3.1 } do
		for _, z in { -3.4, 3.6 } do
			Kit.parte(
				m,
				cf * CFrame.new(x, 1.5, z) * CFrame.Angles(0, 0, math.pi / 2),
				Vector3.new(1.4, 3, 3),
				negro,
				M.Rubber,
				{
					forma = Enum.PartType.Cylinder,
				}
			)
		end
	end
	Kit.parte(
		m,
		cf * CFrame.new(0, 3.2, 5.7) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(1, 2.8, 2.8),
		negro,
		M.Rubber,
		{
			forma = Enum.PartType.Cylinder,
		}
	)
	return m
end

function Campamento.combustible(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Combustible", padre)
	local tanque = Color3.fromRGB(196, 190, 176)
	Kit.parte(
		m,
		cf * CFrame.new(0, 3.2, 0),
		Vector3.new(10, 4.6, 4.6),
		tanque,
		M.Metal,
		{ forma = Enum.PartType.Cylinder }
	)
	for _, x in { -3.5, 3.5 } do
		Kit.parte(m, cf * CFrame.new(x, 0.8, 0), Vector3.new(0.6, 1.6, 3.6), MADERA, M.Wood)
	end
	Kit.parte(
		m,
		cf * CFrame.new(0, 3.2, 2.32),
		Vector3.new(6, 0.8, 0.05),
		Color3.fromRGB(220, 60, 40),
		M.SmoothPlastic,
		Kit.FOLLAJE
	)
	for i = 1, 6 do
		Estructuras.barril(rng, cf * CFrame.new(-6 + (i % 3) * 2.4, 0, 5 + math.floor((i - 1) / 3) * 2.4), m)
	end
	Estructuras.barril(rng, cf * CFrame.new(5, 0, 6), m, true)
	return m
end

function Campamento.canoa(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Canoa", padre)
	local casco = Kit.variar(Color3.fromRGB(120, 80, 50), rng, 0.05)
	Kit.ovoide(m, cf * CFrame.new(0, 0.6, 0), Vector3.new(3.2, 1.8, 15), casco, M.Wood, { colision = true })
	Kit.ovoide(m, cf * CFrame.new(0, 1.05, 0), Vector3.new(2.5, 1, 13.4), Color3.fromRGB(56, 40, 28), M.Wood)
	for _, z in { -3.5, 0, 3.5 } do
		Kit.parte(m, cf * CFrame.new(0, 1.2, z), Vector3.new(2.6, 0.2, 0.8), TABLA, M.WoodPlanks)
	end
	Kit.viga(m, punto(cf, 0.8, 1.3, -2), punto(cf, -0.6, 1.4, 4), 0.25, 0.25, MADERA, M.Wood)
	return m
end

-- Muelle de tablones que entra en el agua desde `cf` hacia -Z.
function Campamento.muelle(rng: Random, cf: CFrame, largo: number, nivelAgua: number, padre: Instance): Model
	local m = Kit.modelo("Muelle", padre)
	local altura = nivelAgua + 1.5 - cf.Position.Y
	for i = 0, math.floor(largo / 1.3) do
		Kit.parte(
			m,
			cf * CFrame.new(0, altura, -i * 1.3) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0),
			Vector3.new(6, 0.4, 1.2),
			Kit.variar(TABLA, rng, 0.06),
			M.WoodPlanks
		)
	end
	for i = 0, math.floor(largo / 6) do
		for _, x in { -2.8, 2.8 } do
			Kit.cilindro(m, punto(cf, x, altura - 8, -i * 6), punto(cf, x, altura + 1.2, -i * 6), 0.6, MADERA, M.Wood)
		end
	end
	Campamento.farol(cf * CFrame.new(-3.4, altura, -largo + 1), m)
	return m
end

return Campamento
