--!strict
--[[
	El culto a la serpiente que une el mapa (docs/SELVA-CULTO.md): santuarios junto a los
	senderos, un altar en cada aldea y el templo escalonado. Todo comparte el mismo estilo de
	tallas: cabezas de serpiente, escamas en rombo y espirales, en piedra agrietada con musgo y
	raíces encima.

	Los altares de las aldeas eran para mantener a la serpiente lejos (ofrendas de protección):
	los habitantes huyeron de ella, no la servían (CONTEXT.md: no asociar a los habitantes con
	los monstruos).

	Convención de Estructuras: `cf` está en el suelo y el frente mira hacia -Z.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local CU = Config.Mapa.Culto
local M = Enum.Material
local BOLA = Enum.PartType.Ball
local CIL = Enum.PartType.Cylinder

local OSCURO = Color3.fromRGB(26, 28, 24)
local HUESO = Color3.fromRGB(196, 186, 160)
local CERA = Color3.fromRGB(214, 204, 170)
local LLAMA = Color3.fromRGB(255, 150, 70)
local BARRO = Color3.fromRGB(112, 72, 48)
local TELAS = { Color3.fromRGB(120, 32, 26), Color3.fromRGB(150, 110, 40), Color3.fromRGB(70, 40, 30) }
local PLUMAS = { Color3.fromRGB(30, 30, 34), Color3.fromRGB(150, 40, 30), Color3.fromRGB(40, 90, 70) }

-- decoración: sin colisión, sin raycasts, sin sombra
local DECOR = Kit.FOLLAJE
-- tallas grandes: proyectan sombra pero no estorban al caminar
local TALLA = { colision = false, consulta = false } :: Kit.Opciones

local Culto = {}

local function piedra(rng: Random): Color3
	return Kit.variar(CU.PIEDRA, rng, 0.04)
end

---------------------------------------------------------------------------------------------
-- Motivos
---------------------------------------------------------------------------------------------

-- Espiral tallada sobre una cara. `cf` es el centro de la cara y +Z sale de ella.
function Culto.espiral(padre: Instance, cf: CFrame, radio: number, rng: Random)
	local tramos = 10
	local vueltas = 2.2
	local grosor = math.max(radio * 0.16, 0.25)
	local color = Kit.variar(CU.PIEDRA:Lerp(OSCURO, 0.45), rng, 0.03)
	local prev = cf.Position
	for k = 1, tramos do
		local t = k / tramos
		local a = t * vueltas * math.pi * 2
		local p = cf:PointToWorldSpace(Vector3.new(math.cos(a) * radio * t, math.sin(a) * radio * t, 0.05))
		Kit.cilindro(padre, prev, p, grosor, color, M.Slate, DECOR)
		prev = p
	end
end

-- Escamas en rombo sobre una cara. `cf` es el centro y +Y sale de ella.
function Culto.escamas(padre: Instance, cf: CFrame, ancho: number, largo: number, tam: number, rng: Random)
	local filas = math.min(10, math.floor(largo / tam))
	local columnas = math.min(8, math.floor(ancho / tam))
	local color = Kit.variar(CU.PIEDRA:Lerp(OSCURO, 0.3), rng, 0.03)
	for f = 0, filas - 1 do
		local desfase = if f % 2 == 0 then 0 else tam / 2
		for c = 0, columnas - 1 do
			local x = -ancho / 2 + tam / 2 + c * tam + desfase
			if x < ancho / 2 and rng:NextNumber() > 0.08 then
				Kit.parte(
					padre,
					cf * CFrame.new(x, 0.05, -largo / 2 + tam / 2 + f * tam * 0.8) * CFrame.Angles(0, math.pi / 4, 0),
					Vector3.new(tam * 0.62, tam * 0.12, tam * 0.62),
					color,
					M.Slate,
					DECOR
				)
			end
		end
	end
end

-- Grieta: una franja oscura sobre una cara (+Z sale de ella).
local function grieta(padre: Instance, cf: CFrame, largo: number, rng: Random)
	local a = cf * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5))
	Kit.parte(padre, a * CFrame.new(0, 0, 0.02), Vector3.new(largo * 0.06 + 0.1, largo, 0.06), OSCURO, M.Slate, DECOR)
end

-- Mancha de musgo plana sobre una superficie (+Y sale de ella).
local function musgo(padre: Instance, cf: CFrame, tam: number, rng: Random)
	Kit.parte(
		padre,
		cf * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.new(0, 0.1, 0),
		Vector3.new(tam, 0.25, tam * rng:NextNumber(0.5, 0.9)),
		Kit.variar(CU.MUSGO, rng, 0.05),
		M.Grass,
		DECOR
	)
end

-- Raíz que trepa desde el suelo sobre la piedra: una línea quebrada que adelgaza.
function Culto.raiz(padre: Instance, desde: Vector3, hasta: Vector3, grosor: number, rng: Random)
	local tramos = 4
	local prev = desde
	local largo = (hasta - desde).Magnitude
	for k = 1, tramos do
		local t = k / tramos
		local p = desde:Lerp(hasta, t)
		if k < tramos then
			p += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-1, 1)) * largo * 0.06
		end
		Kit.cilindro(padre, prev, p, grosor * (1 - t * 0.55), Kit.variar(CU.RAIZ, rng, 0.05), M.Wood, DECOR)
		prev = p
	end
end

---------------------------------------------------------------------------------------------
-- Serpientes de piedra
---------------------------------------------------------------------------------------------

-- Cabeza de serpiente tallada. `cf` es la nuca a ras de su base; la boca mira hacia -Z.
-- `s` es el largo aproximado; `abierta` el ángulo de las mandíbulas en radianes.
function Culto.cabeza(padre: Instance, cf: CFrame, s: number, abierta: number, rng: Random, solida: boolean?): Model
	local m = Kit.modelo("CabezaSerpiente", padre)
	local col = piedra(rng)
	local op = if solida then nil else TALLA
	Kit.parte(m, cf * CFrame.new(0, 0.32 * s, -0.3 * s), Vector3.new(0.78 * s, 0.5 * s, 0.7 * s), col, M.Slate, op)
	local bisagra = cf * CFrame.new(0, 0.3 * s, -0.55 * s)
	local superior = bisagra * CFrame.Angles(abierta * 0.55, 0, 0)
	local inferior = bisagra * CFrame.Angles(-abierta * 0.45, 0, 0)
	Kit.parte(
		m,
		superior * CFrame.new(0, 0.1 * s, -0.36 * s),
		Vector3.new(0.68 * s, 0.22 * s, 0.76 * s),
		Kit.variar(col, rng, 0.03),
		M.Slate,
		op
	)
	-- hocico redondeado y fosas
	Kit.ovoide(
		m,
		superior * CFrame.new(0, 0.1 * s, -0.72 * s),
		Vector3.new(0.6 * s, 0.22 * s, 0.24 * s),
		col,
		M.Slate,
		DECOR
	)
	for _, x in { -0.13, 0.13 } do
		Kit.parte(
			m,
			superior * CFrame.new(x * s, 0.2 * s, -0.78 * s),
			Vector3.one * 0.07 * s,
			OSCURO,
			M.Slate,
			{ forma = BOLA, colision = false, consulta = false, sombra = false }
		)
	end
	Kit.parte(
		m,
		inferior * CFrame.new(0, -0.06 * s, -0.33 * s),
		Vector3.new(0.58 * s, 0.14 * s, 0.7 * s),
		Kit.variar(col, rng, 0.03),
		M.Slate,
		op
	)
	-- garganta oscura entre las mandíbulas
	if abierta > 0.1 then
		Kit.parte(
			m,
			bisagra * CFrame.new(0, 0.02 * s, -0.22 * s),
			Vector3.new(0.5 * s, math.max(0.1, math.sin(abierta) * 0.45 * s), 0.42 * s),
			OSCURO,
			M.Slate,
			DECOR
		)
		-- colmillos que cuelgan de la mandíbula superior
		for _, x in { -0.22, 0.22 } do
			Kit.parte(
				m,
				superior * CFrame.new(x * s, -0.1 * s, -0.62 * s) * CFrame.Angles(0.15, 0, 0),
				Vector3.new(0.06 * s, 0.26 * s, 0.07 * s),
				HUESO,
				M.Slate,
				DECOR
			)
		end
		-- lengua bífida
		local raiz = inferior * CFrame.new(0, 0.04 * s, -0.4 * s)
		local punta = raiz * CFrame.Angles(0.15, 0, 0) * CFrame.new(0, 0, -0.5 * s)
		Kit.cilindro(m, raiz.Position, punta.Position, 0.05 * s, Color3.fromRGB(90, 30, 28), M.Slate, DECOR)
		for _, g in { -0.35, 0.35 } do
			local p = (punta * CFrame.Angles(0, g, 0) * CFrame.new(0, 0, -0.14 * s)).Position
			Kit.cilindro(m, punta.Position, p, 0.035 * s, Color3.fromRGB(90, 30, 28), M.Slate, DECOR)
		end
	end
	-- ojos hundidos y cejas
	for _, x in { -1, 1 } do
		Kit.parte(
			m,
			cf * CFrame.new(x * 0.36 * s, 0.46 * s, -0.48 * s),
			Vector3.one * 0.15 * s,
			OSCURO,
			M.Slate,
			{ forma = BOLA, colision = false, consulta = false, sombra = false }
		)
		Kit.parte(
			m,
			cf * CFrame.new(x * 0.3 * s, 0.6 * s, -0.46 * s) * CFrame.Angles(0, 0, -x * 0.35),
			Vector3.new(0.26 * s, 0.07 * s, 0.24 * s),
			Kit.variar(col, rng, 0.04),
			M.Slate,
			DECOR
		)
	end
	Culto.escamas(m, cf * CFrame.new(0, 0.57 * s, -0.22 * s), 0.6 * s, 0.55 * s, math.max(0.14 * s, 0.7), rng)
	return m
end

-- Cuerpo de serpiente por una lista de puntos: tramos cilíndricos unidos por bolas.
local function cuerpo(padre: Instance, puntos: { Vector3 }, grosor: number, rng: Random, solido: boolean)
	local op = if solido then nil else TALLA
	for k = 1, #puntos do
		local g = grosor * (1 - 0.35 * (k - 1) / math.max(1, #puntos - 1))
		local col = if rng:NextNumber() < 0.15 then Kit.variar(CU.MUSGO, rng, 0.05) else piedra(rng)
		Kit.parte(padre, CFrame.new(puntos[k]), Vector3.one * g, col, M.Slate, {
			forma = BOLA,
			colision = solido,
			consulta = solido,
		})
		if k > 1 then
			Kit.cilindro(padre, puntos[k - 1], puntos[k], g * 0.96, piedra(rng), M.Slate, op)
		end
	end
end

-- Serpiente enroscada sobre sí misma que levanta la cabeza hacia -Z.
function Culto.enroscada(padre: Instance, cf: CFrame, radio: number, alto: number, grosor: number, rng: Random): Model
	local m = Kit.modelo("SerpienteEnroscada", padre)
	local puntos: { Vector3 } = {}
	local n = 22
	local vueltas = 2.4
	local a0 = rng:NextNumber(0, math.pi * 2)
	for k = 0, n do
		local t = k / n
		local a = a0 + t * vueltas * math.pi * 2
		local r = radio * (1 - 0.5 * t)
		table.insert(
			puntos,
			cf:PointToWorldSpace(Vector3.new(math.cos(a) * r, grosor * 0.45 + t * alto * 0.35, math.sin(a) * r))
		)
	end
	-- el cuello sube desde la última vuelta hasta la cabeza
	local ultimo = puntos[#puntos]
	local cabezaEn = cf:PointToWorldSpace(Vector3.new(0, alto, -radio * 0.2))
	for k = 1, 5 do
		local t = k / 5
		local p = ultimo:Lerp(cabezaEn, t)
			+ cf:VectorToWorldSpace(Vector3.new(0, 0, math.sin(t * math.pi) * radio * 0.35))
		table.insert(puntos, p)
	end
	cuerpo(m, puntos, grosor, rng, true)
	local mirar = CFrame.lookAt(cabezaEn, cabezaEn + cf.LookVector) * CFrame.Angles(-0.12, 0, 0)
	Culto.cabeza(m, mirar * CFrame.new(0, -grosor * 0.4, grosor * 0.2), grosor * 2.1, rng:NextNumber(0.45, 0.75), rng)
	return m
end

---------------------------------------------------------------------------------------------
-- Ofrendas
---------------------------------------------------------------------------------------------

-- Vela derretida con su charco de cera. Devuelve la llama (para colgarle una luz).
function Culto.vela(padre: Instance, cf: CFrame, rng: Random): BasePart
	local alto = rng:NextNumber(0.4, 1.5)
	Kit.parte(
		padre,
		cf * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.08, rng:NextNumber(0.7, 1.2), rng:NextNumber(0.7, 1.2)),
		CERA,
		M.SmoothPlastic,
		{ forma = CIL, colision = false, consulta = false, sombra = false }
	)
	Kit.parte(
		padre,
		cf * CFrame.new(0, alto / 2, 0) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, math.pi / 2),
		Vector3.new(alto, 0.34, 0.34),
		Kit.variar(CERA, rng, 0.04),
		M.SmoothPlastic,
		{ forma = CIL, colision = false, consulta = false, sombra = false }
	)
	return Kit.parte(
		padre,
		cf * CFrame.new(0, alto + 0.16, 0),
		Vector3.new(0.16, 0.3, 0.16),
		LLAMA,
		M.Neon,
		{ forma = BOLA, colision = false, consulta = false, sombra = false, nombre = "Llama" }
	)
end

function Culto.cuenco(padre: Instance, cf: CFrame, rng: Random)
	local d = rng:NextNumber(1.2, 1.9)
	Kit.parte(
		padre,
		cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.6, d, d),
		Kit.variar(BARRO, rng, 0.05),
		M.Slate,
		{ forma = CIL, colision = false, consulta = false, sombra = false }
	)
	Kit.parte(
		padre,
		cf * CFrame.new(0, 0.61, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.04, d * 0.8, d * 0.8),
		Color3.fromRGB(40, 18, 14),
		M.SmoothPlastic,
		{ forma = CIL, colision = false, consulta = false, sombra = false }
	)
end

function Culto.huesos(padre: Instance, cf: CFrame, rng: Random, n: number)
	for _ = 1, n do
		local c = cf
			* CFrame.new(rng:NextNumber(-1.6, 1.6), 0.15, rng:NextNumber(-1.6, 1.6))
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		local largo = rng:NextNumber(1, 2.2)
		local a = c:PointToWorldSpace(Vector3.new(0, 0, -largo / 2))
		local b = c:PointToWorldSpace(Vector3.new(0, rng:NextNumber(0, 0.2), largo / 2))
		Kit.cilindro(padre, a, b, 0.2, Kit.variar(HUESO, rng, 0.05), M.SmoothPlastic, DECOR)
		for _, p in { a, b } do
			Kit.parte(padre, CFrame.new(p), Vector3.one * 0.32, HUESO, M.SmoothPlastic, {
				forma = BOLA,
				colision = false,
				consulta = false,
				sombra = false,
			})
		end
	end
	-- a veces un cráneo de animal
	if rng:NextNumber() < 0.4 then
		local c = cf
			* CFrame.new(rng:NextNumber(-1, 1), 0.35, rng:NextNumber(-1, 1))
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		Kit.ovoide(padre, c, Vector3.new(0.8, 0.6, 1.1), HUESO, M.SmoothPlastic, DECOR)
		Kit.parte(padre, c * CFrame.new(0, -0.1, -0.7), Vector3.new(0.4, 0.3, 0.6), HUESO, M.SmoothPlastic, DECOR)
		for _, x in { -0.2, 0.2 } do
			Kit.parte(padre, c * CFrame.new(x, 0.12, -0.42), Vector3.one * 0.2, OSCURO, M.SmoothPlastic, {
				forma = BOLA,
				colision = false,
				consulta = false,
				sombra = false,
			})
		end
	end
end

function Culto.plumas(padre: Instance, cf: CFrame, rng: Random, n: number)
	for _ = 1, n do
		Kit.parte(
			padre,
			cf
				* CFrame.new(rng:NextNumber(-1, 1), 0.4, rng:NextNumber(-1, 1))
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)),
			Vector3.new(0.05, 1, 0.26),
			Kit.elegir(rng, PLUMAS),
			M.Fabric,
			{ cuna = true, colision = false, consulta = false, sombra = false }
		)
	end
end

-- Palo con tiras de tela colgando.
function Culto.telas(padre: Instance, cf: CFrame, rng: Random)
	local alto = rng:NextNumber(3.5, 5)
	cf *= CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
	Kit.cilindro(
		padre,
		cf:PointToWorldSpace(Vector3.new(0, -0.8, 0)),
		cf:PointToWorldSpace(Vector3.new(0, alto, 0)),
		0.3,
		Kit.variar(CU.RAIZ, rng, 0.05),
		M.Wood,
		DECOR
	)
	Kit.cilindro(
		padre,
		cf:PointToWorldSpace(Vector3.new(-1.1, alto - 0.3, 0)),
		cf:PointToWorldSpace(Vector3.new(1.1, alto - 0.3, 0)),
		0.2,
		Kit.variar(CU.RAIZ, rng, 0.05),
		M.Wood,
		DECOR
	)
	for k = 1, rng:NextInteger(2, 4) do
		local x = -1 + (k - 0.5) * 0.6
		local largo = rng:NextNumber(1.4, 2.6)
		Kit.parte(
			padre,
			cf
				* CFrame.new(x, alto - 0.3 - largo / 2, 0)
				* CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)),
			Vector3.new(0.42, largo, 0.05),
			Kit.elegir(rng, TELAS),
			M.Fabric,
			DECOR
		)
	end
end

-- Una ofrenda: cuenco, velas y a veces huesos o plumas. Devuelve la llama más alta.
function Culto.ofrenda(padre: Instance, cf: CFrame, rng: Random): BasePart
	local m = Kit.modelo("Ofrenda", padre)
	Culto.cuenco(m, cf, rng)
	local llama = Culto.vela(m, cf * CFrame.new(rng:NextNumber(0.9, 1.4), 0, rng:NextNumber(-0.6, 0.6)), rng)
	if rng:NextNumber() < 0.6 then
		Culto.vela(m, cf * CFrame.new(-rng:NextNumber(0.9, 1.4), 0, rng:NextNumber(-0.6, 0.6)), rng)
	end
	if rng:NextNumber() < 0.5 then
		Culto.huesos(m, cf * CFrame.new(0, 0, 1.4), rng, rng:NextInteger(1, 3))
	end
	if rng:NextNumber() < 0.5 then
		Culto.plumas(m, cf * CFrame.new(0, 0, -1.2), rng, rng:NextInteger(1, 3))
	end
	return llama
end

local function luzVelas(llama: BasePart, rango: number, brillo: number)
	Kit.luz(llama, Color3.fromRGB(255, 160, 90), rango, brillo)
	Kit.etiquetar(llama, "Vela")
end

---------------------------------------------------------------------------------------------
-- Santuario, altar y templo
---------------------------------------------------------------------------------------------

-- Santuario pequeño junto a un sendero: pedestal con una cabeza de serpiente que mira al
-- sendero, ofrendas, velas derretidas, huesos, plumas y tiras de tela.
function Culto.santuario(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Santuario", padre)
	cf *= CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.05, 0.05))
	local base = Kit.parte(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(4.4, 1.6, 4.4), piedra(rng), M.Slate)
	local fuste = Kit.parte(
		m,
		cf * CFrame.new(0, 3.5, 0.2) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0),
		Vector3.new(2.8, 4.4, 2.8),
		piedra(rng),
		M.Slate
	)
	Culto.espiral(m, fuste.CFrame * CFrame.new(0, 0, -1.4) * CFrame.Angles(0, math.pi, 0), 1, rng)
	for _, x in { -1.4, 1.4 } do
		Culto.espiral(
			m,
			fuste.CFrame * CFrame.new(x, 0.4, 0) * CFrame.Angles(0, x > 0 and math.pi / 2 or -math.pi / 2, 0),
			0.8,
			rng
		)
	end
	grieta(m, fuste.CFrame * CFrame.new(0.8, -0.6, -1.41) * CFrame.Angles(0, math.pi, 0), 2.6, rng)
	Culto.cabeza(m, cf * CFrame.new(0, 5.7, 1.1), 3.4, rng:NextNumber(0.3, 0.6), rng)
	musgo(m, base.CFrame * CFrame.new(1.2, 0.8, 1.2), 1.8, rng)
	musgo(m, fuste.CFrame * CFrame.new(-0.6, 2.2, 0.6), 1.4, rng)
	local llama = Culto.ofrenda(m, cf * CFrame.new(-1.3, 1.3, -1.4), rng)
	Culto.vela(m, cf * CFrame.new(1.4, 1.3, -1.6), rng)
	Culto.vela(m, cf * CFrame.new(1.8, 1.3, -1), rng)
	luzVelas(llama, 12, 0.9)
	Culto.huesos(m, cf * CFrame.new(0, 0, -3.4), rng, rng:NextInteger(2, 4))
	Culto.plumas(m, cf * CFrame.new(-2.6, 0, -2.4), rng, 3)
	Culto.telas(m, cf * CFrame.new(3.2, 0, 0.6), rng)
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		Culto.raiz(
			m,
			cf:PointToWorldSpace(Vector3.new(math.cos(a) * 5, -0.3, math.sin(a) * 5)),
			cf:PointToWorldSpace(Vector3.new(math.cos(a) * 1.6, rng:NextNumber(1.4, 4), math.sin(a) * 1.6)),
			0.55,
			rng
		)
	end
	return m
end

-- Altar mediano de aldea: plataforma de tres escalones, losa, estela con una cabeza de serpiente
-- y dos serpientes enroscadas a los lados.
function Culto.altar(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Altar", padre)
	for k, tam in { Vector3.new(15, 1, 12), Vector3.new(12, 1, 9.5), Vector3.new(9, 1, 7) } do
		local escalon = Kit.parte(m, cf * CFrame.new(0, k - 0.6, 1), tam, piedra(rng), M.Slate)
		musgo(m, escalon.CFrame * CFrame.new(rng:NextNumber(-tam.X / 3, tam.X / 3), 0.5, tam.Z / 2 - 0.8), 2.2, rng)
		grieta(
			m,
			escalon.CFrame
				* CFrame.new(rng:NextNumber(-tam.X / 3, tam.X / 3), 0, -tam.Z / 2)
				* CFrame.Angles(0, math.pi, 0),
			0.9,
			rng
		)
	end
	local arriba = cf * CFrame.new(0, 2.4, 0)
	for _, x in { -2.2, 2.2 } do
		Kit.parte(m, arriba * CFrame.new(x, 1.1, 0), Vector3.new(1.1, 2.2, 2.6), piedra(rng), M.Slate)
	end
	local losa = Kit.parte(
		m,
		arriba * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.04, 0.04)),
		Vector3.new(6.4, 1.2, 3.4),
		piedra(rng),
		M.Slate
	)
	Culto.escamas(m, losa.CFrame * CFrame.new(0, 0.6, 0), 6, 3, 0.8, rng)
	local estela = Kit.parte(m, arriba * CFrame.new(0, 3.6, 3.4), Vector3.new(5.6, 7.2, 1.4), piedra(rng), M.Slate)
	for _, x in { -1.5, 1.5 } do
		Culto.espiral(m, estela.CFrame * CFrame.new(x, -1.2, -0.7) * CFrame.Angles(0, math.pi, 0), 1.1, rng)
	end
	grieta(m, estela.CFrame * CFrame.new(-0.4, 1, -0.71) * CFrame.Angles(0, math.pi, 0), 4, rng)
	Culto.cabeza(m, arriba * CFrame.new(0, 7.2, 4.2), 4.6, rng:NextNumber(0.4, 0.7), rng)
	for _, x in { -1, 1 } do
		Culto.enroscada(m, cf * CFrame.new(x * 9.6, 0, -2) * CFrame.Angles(0, -x * 0.35, 0), 2.6, 7, 1.2, rng)
	end
	local llama = Culto.vela(m, losa.CFrame * CFrame.new(-2.2, 0.6, -0.8), rng)
	for _ = 1, 4 do
		Culto.vela(m, losa.CFrame * CFrame.new(rng:NextNumber(-2.8, 2.8), 0.6, rng:NextNumber(-1.3, 1.3)), rng)
	end
	luzVelas(llama, 16, 1)
	Culto.cuenco(m, losa.CFrame * CFrame.new(1.2, 0.6, 0), rng)
	for _ = 1, 3 do
		Culto.ofrenda(m, cf * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-7.5, -5.5)), rng)
	end
	Culto.huesos(m, cf * CFrame.new(rng:NextNumber(-4, 4), 0, -6.5), rng, 4)
	Culto.telas(m, cf * CFrame.new(-6.6, 0, 4.5), rng)
	Culto.telas(m, cf * CFrame.new(6.6, 0, 4.5), rng)
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		Culto.raiz(
			m,
			cf:PointToWorldSpace(Vector3.new(math.cos(a) * 11, -0.3, math.sin(a) * 9)),
			cf:PointToWorldSpace(Vector3.new(math.cos(a) * 4, rng:NextNumber(1.5, 3), math.sin(a) * 3.5)),
			0.8,
			rng
		)
	end
	return m
end

-- Templo escalonado: pisos de piedra con musgo y espirales, escalera al frente con serpientes
-- por baranda, dos serpientes enroscadas gigantes a los pies y, arriba, la losa del altar bajo
-- una cabeza de serpiente enorme con la boca abierta. Con la cabeza supera el dosel.
function Culto.templo(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Templo", padre)
	local P, B, H = CU.TEMPLO_PISOS, CU.TEMPLO_BASE, CU.TEMPLO_PISO
	local cima = B * 0.36
	local paso = (B - cima) / (P - 1)
	local W = 16 -- ancho de la escalera
	local alto = P * H

	for k = 0, P - 1 do
		local lado = B - k * paso
		local piso =
			Kit.parte(m, cf * CFrame.new(0, k * H + H / 2 - 0.8, 0), Vector3.new(lado, H, lado), piedra(rng), M.Slate)
		piso.Name = "Piso" .. (k + 1)
		-- cornisa
		Kit.parte(
			m,
			cf * CFrame.new(0, (k + 1) * H - 0.6, 0),
			Vector3.new(lado + 1.2, 0.9, lado + 1.2),
			Kit.variar(CU.PIEDRA, rng, 0.06),
			M.Slate
		)
		-- espirales a los lados de la escalera y en las otras caras
		for _, x in { -1, 1 } do
			Culto.espiral(
				m,
				cf
					* CFrame.new(x * (W / 2 + lado * 0.18), k * H + H / 2 - 0.8, -lado / 2)
					* CFrame.Angles(0, math.pi, 0),
				H * 0.3,
				rng
			)
		end
		local caraLado = Kit.elegir(rng, { 0, math.pi / 2, -math.pi / 2, math.pi })
		if caraLado ~= math.pi then
			Culto.espiral(
				m,
				cf
					* CFrame.Angles(0, caraLado, 0)
					* CFrame.new(rng:NextNumber(-lado / 4, lado / 4), k * H + H / 2 - 0.8, lado / 2),
				H * 0.3,
				rng
			)
		end
		-- grietas y musgo: más cuanto más abajo (la selva sube desde el suelo)
		for _ = 1, 2 do
			local giro = rng:NextNumber(0, 1) * math.pi * 2
			grieta(
				m,
				cf
					* CFrame.Angles(0, giro, 0)
					* CFrame.new(rng:NextNumber(-lado / 3, lado / 3), k * H + H / 2, lado / 2 + 0.05),
				H * 0.7,
				rng
			)
		end
		for _ = 1, math.max(1, 5 - k) do
			local giro = Kit.elegir(rng, { 0, math.pi / 2, -math.pi / 2, math.pi })
			local x = rng:NextNumber(-lado / 2.4, lado / 2.4)
			if giro ~= math.pi or math.abs(x) > W / 2 + 2 then
				-- musgo colgando de la cara
				Kit.parte(
					m,
					cf * CFrame.Angles(0, giro, 0) * CFrame.new(x, (k + 1) * H - rng:NextNumber(2, 4), lado / 2 + 0.15),
					Vector3.new(rng:NextNumber(4, 10), rng:NextNumber(3, 6), 0.3),
					Kit.variar(CU.MUSGO, rng, 0.05),
					M.Grass,
					DECOR
				)
			end
			musgo(
				m,
				cf
					* CFrame.new(
						rng:NextNumber(-lado / 2.3, lado / 2.3),
						(k + 1) * H - 0.2,
						(lado - paso / 2) / 2 * Kit.elegir(rng, { -1, 1 })
					),
				rng:NextNumber(3, 6),
				rng
			)
		end
	end

	-- escalera: escalones de 1,6 studs sobre una cuña maciza
	local subida, huella = 1.6, 1.2
	local n = math.ceil(alto / subida)
	local frente = -(cima / 2) - n * huella + 2
	Kit.parte(
		m,
		cf * CFrame.new(0, alto / 2 - 0.8, frente + n * huella / 2),
		Vector3.new(W, alto, n * huella),
		piedra(rng),
		M.Slate,
		{ cuna = true }
	)
	for i = 1, n do
		local roto = rng:NextNumber() < 0.06
		local tam = if roto
			then Vector3.new(W * rng:NextNumber(0.4, 0.7), subida, huella)
			else Vector3.new(W, subida, huella)
		local x = if roto then (W - tam.X) / 2 * Kit.elegir(rng, { -1, 1 }) else 0
		Kit.parte(
			m,
			cf * CFrame.new(x, (i - 0.5) * subida - 0.8, frente + (i - 0.5) * huella),
			tam,
			Kit.variar(CU.PIEDRA, rng, 0.05),
			M.Slate
		)
	end
	-- serpientes que bajan por las barandas de la escalera y apoyan la cabeza abajo
	for _, x in { -1, 1 } do
		local puntos: { Vector3 } = {}
		for k = 0, 8 do
			local t = k / 8
			table.insert(
				puntos,
				cf:PointToWorldSpace(
					Vector3.new(x * (W / 2 + 1.4), 1.6 + t * (alto - 1), frente + 2 + t * (n * huella - 2))
				)
			)
		end
		cuerpo(m, puntos, 3, rng, false)
		Culto.cabeza(m, cf * CFrame.new(x * (W / 2 + 1.4), -0.2, frente + 2.6), 7, 0.5, rng, true)
	end
	-- dos serpientes enroscadas gigantes vigilan el pie de la escalera
	for _, x in { -1, 1 } do
		Culto.enroscada(
			m,
			cf * CFrame.new(x * (W / 2 + 15), 0, frente + 8) * CFrame.Angles(0, -x * 0.25, 0),
			9,
			24,
			4.4,
			rng
		)
	end

	-- cumbre: pedestal, losa del altar y la cabeza gigante con la boca abierta encima
	local tope = cf * CFrame.new(0, alto - 0.8, 0)
	local pedestal =
		Kit.parte(m, tope * CFrame.new(0, 3, cima / 4), Vector3.new(cima * 0.6, 6, cima * 0.42), piedra(rng), M.Slate)
	Culto.escamas(
		m,
		pedestal.CFrame * CFrame.new(0, 0, -cima * 0.21) * CFrame.Angles(-math.pi / 2, 0, 0),
		cima * 0.55,
		5,
		1.4,
		rng
	)
	for _, x in { -2.8, 2.8 } do
		Kit.parte(m, tope * CFrame.new(x, 1.2, -cima / 6), Vector3.new(1.4, 2.4, 3.2), piedra(rng), M.Slate)
	end
	local losa = Kit.parte(m, tope * CFrame.new(0, 2.9, -cima / 6), Vector3.new(8.4, 1.3, 4), piedra(rng), M.Slate)
	Culto.escamas(m, losa.CFrame * CFrame.new(0, 0.65, 0), 8, 3.6, 0.9, rng)
	Culto.cabeza(m, tope * CFrame.new(0, 6, cima / 4 + 6), 26, 0.72, rng, true)

	-- brasero sobre la losa: la única luz que se ve de lejos
	local brasa = Kit.parte(
		m,
		losa.CFrame * CFrame.new(0, 1, 0),
		Vector3.new(1.6, 0.8, 1.6),
		Color3.fromRGB(255, 110, 40),
		M.Neon,
		{
			forma = BOLA,
			colision = false,
			consulta = false,
			sombra = false,
			nombre = "Brasa",
		}
	)
	local fuego = Instance.new("Fire")
	fuego.Size = 4
	fuego.Heat = 6
	fuego.Color = Color3.fromRGB(255, 130, 50)
	fuego.SecondaryColor = Color3.fromRGB(150, 30, 15)
	fuego.Parent = brasa
	Kit.luz(brasa, Color3.fromRGB(255, 140, 70), 40, 1.3)
	for _ = 1, 8 do
		Culto.vela(m, losa.CFrame * CFrame.new(rng:NextNumber(-3.8, 3.8), 0.65, rng:NextNumber(-1.6, 1.6)), rng)
	end
	for _, x in { -6, 6 } do
		Culto.ofrenda(m, tope * CFrame.new(x, 0, -cima / 3), rng)
		Culto.huesos(m, tope * CFrame.new(x * 0.6, 0, -cima / 2.6), rng, 4)
		Culto.telas(m, tope * CFrame.new(x * 1.3, 0, cima / 6), rng)
	end

	-- ofrendas y huesos al pie de la escalera, con luz
	local pie = cf * CFrame.new(0, 0, frente - 4)
	local llama = Culto.ofrenda(m, pie * CFrame.new(-4, 0, 0), rng)
	Culto.ofrenda(m, pie * CFrame.new(4, 0, 0), rng)
	luzVelas(llama, 18, 1)
	Culto.huesos(m, pie * CFrame.new(0, 0, -3), rng, 6)

	-- raíces gruesas que trepan por los primeros pisos
	for _ = 1, 10 do
		local giro = rng:NextNumber(0, 1) * math.pi * 2
		local base = cf * CFrame.Angles(0, giro, 0)
		local x = rng:NextNumber(-B / 3, B / 3)
		if giro > math.pi * 0.9 and giro < math.pi * 1.1 and math.abs(x) < W then
			continue
		end
		local k = rng:NextInteger(1, 3)
		Culto.raiz(
			m,
			base:PointToWorldSpace(Vector3.new(x, -0.5, B / 2 + rng:NextNumber(6, 14))),
			base:PointToWorldSpace(Vector3.new(x + rng:NextNumber(-6, 6), k * H, (B - k * paso) / 2 + 0.4)),
			rng:NextNumber(1.6, 2.6),
			rng
		)
	end
	return m
end

return Culto
