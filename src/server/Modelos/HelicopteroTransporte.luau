--!strict
--[[
	Helicóptero de transporte AMZ-07 hecho solo con partes de Studio (sin mallas subidas, así
	carga igual para cualquier cuenta). Mismo diseño que art/blender/build_helicoptero.py:
	el casco es un "loft" de secciones superelípticas resuelto con paneles finos, lo que deja
	un hueco real en la puerta corrediza y un interior visible.

	Convención: `cf` en el suelo, morro hacia -Z, estribor en +X. Hijos con nombre fijo:
	  Rotor (Model, eje vertical) · RotorCola (Model, eje X) · Puerta (Model, atributo Recorrido)
	  Interior (parte ancla frente a la puerta, con el Attachment Cabina)
]]

local Kit = require(script.Parent.Kit)

local M = Enum.Material

local Transporte = {}

local SIN = { colision = false, consulta = false } :: Kit.Opciones
local LUZ = { colision = false, consulta = false, sombra = false } :: Kit.Opciones

local BLANCO = Color3.fromRGB(233, 231, 223)
local NARANJA = Color3.fromRGB(224, 104, 42)
local TURQUESA = Color3.fromRGB(28, 140, 148)
local GRIS = Color3.fromRGB(80, 86, 90)
local GRIS_CLARO = Color3.fromRGB(142, 148, 150)
local NEGRO = Color3.fromRGB(27, 29, 31)
local AMARILLO = Color3.fromRGB(240, 194, 40)
local CROMO = Color3.fromRGB(184, 187, 184)
local OLIVA = Color3.fromRGB(78, 86, 56)
local OLIVA_OSC = Color3.fromRGB(53, 59, 39)
local LONA = Color3.fromRGB(154, 46, 38)
local CINCHA = Color3.fromRGB(138, 100, 40)
local SUELO = Color3.fromRGB(60, 63, 62)
local CAJA = Color3.fromRGB(107, 90, 58)
local CUERO = Color3.fromRGB(43, 46, 48)
local GOMA = Color3.fromRGB(20, 21, 22)
local VIDRIO = Color3.fromRGB(58, 92, 104)
local LISO = M.SmoothPlastic

local PUERTA_Z0, PUERTA_Z1 = -5.6, -1.4
local PUERTA_F0, PUERTA_F1 = 0.137, 0.885
local PUERTA_RECORRIDO = 4.5
local ROTOR_EJE = Vector3.new(0, 11.75, -0.6)
local COLA_EJE = Vector3.new(0.62, 10.9, 23.7)

-- estaciones del casco: z, semiancho, y abajo, y arriba
local CLAVES = {
	{ -14.3, 0.3, 4.0, 4.6 },
	{ -13.9, 1.25, 3.05, 5.2 },
	{ -13.2, 2.3, 2.35, 6.05 },
	{ -12.1, 3.1, 1.95, 7.0 },
	{ -10.6, 3.6, 1.72, 7.85 },
	{ -8.6, 3.82, 1.58, 8.35 },
	{ -6.6, 3.86, 1.55, 8.5 },
	{ 4.6, 3.86, 1.55, 8.5 },
	{ 5.6, 3.78, 1.95, 8.48 },
	{ 6.8, 3.55, 2.95, 8.42 },
	{ 8.0, 3.15, 4.15, 8.3 },
	{ 9.1, 2.55, 5.3, 8.12 },
	{ 9.8, 1.9, 6.0, 7.95 },
}
local SUPER = 2.9
-- cortes a lo largo y en altura (fracción 0 abajo .. 1 arriba); incluyen los bordes de la
-- puerta, las franjas de color y el parabrisas
local ZS = { -14.3, -13.9, -13.2, -12.6, -12.1, -11.3, -10.65, -9.6, -8.6, -7.6, -6.6 }
for _, z in { PUERTA_Z0, PUERTA_Z1, 4.6, 5.2, 6.0, 6.8, 7.4, 8.0, 8.6, 9.1, 9.8 } do
	table.insert(ZS, z)
end
local FR = { 0, 0.025, 0.06, 0.1, 0.137, 0.2, 0.27, 0.338, 0.417, 0.5, 0.62, 0.74, 0.81, 0.885, 0.93, 0.965, 1 }

local function seccion(z: number): (number, number, number)
	local n = #CLAVES
	if z <= CLAVES[1][1] then
		return CLAVES[1][2], CLAVES[1][3], CLAVES[1][4]
	end
	for i = 1, n - 1 do
		local a, b = CLAVES[i], CLAVES[i + 1]
		if z <= b[1] then
			local t = (z - a[1]) / (b[1] - a[1])
			t = t * t * (3 - 2 * t)
			return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
		end
	end
	return CLAVES[n][2], CLAVES[n][3], CLAVES[n][4]
end

-- punto del casco en coordenadas locales
local function punto(z: number, f: number, lado: number): Vector3
	local w, yb, yt = seccion(z)
	local s = 2 * f - 1
	local sn = math.sign(s) * math.abs(s) ^ (SUPER / 2)
	local cs = math.sqrt(math.max(0, 1 - sn * sn))
	return Vector3.new(lado * w * cs ^ (2 / SUPER), yb + (yt - yb) * f, z)
end

function Transporte.construir(cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Helicoptero", padre)
	local function c(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local function p(x: number, y: number, z: number): Vector3
		return cf:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local function mundo(v: Vector3): Vector3
		return cf:PointToWorldSpace(v)
	end

	-- Triángulo exacto con dos cuñas (para los paneles que se estrechan: morro, cola y botalón).
	local function triangulo(
		grupo: Instance,
		a: Vector3,
		b: Vector3,
		d: Vector3,
		dentro: Vector3,
		color: Color3,
		material: Enum.Material,
		grosor: number,
		hundir: number,
		o: Kit.Opciones?
	)
		local ab, ad, bd = b - a, d - a, d - b
		local lab, lad, lbd = ab:Dot(ab), ad:Dot(ad), bd:Dot(bd)
		if lab > lad and lab > lbd then
			d, a = a, d
		elseif lad > lbd and lad > lab then
			a, b = b, a
		end
		ab, ad, bd = b - a, d - a, d - b
		local cruz = ad:Cross(ab)
		if cruz.Magnitude < 1e-5 then
			return
		end
		local derecha = cruz.Unit
		local arriba = bd:Cross(derecha).Unit
		local atras = bd.Unit
		local alto = math.abs(ab:Dot(arriba))
		local fuera = if derecha:Dot((a + b + d) / 3 - dentro) < 0 then -derecha else derecha
		local corr = -fuera * (grosor / 2 + hundir)
		local op = table.clone(o or SIN)
		op.cuna = true
		local l1, l2 = math.abs(ab:Dot(atras)), math.abs(ad:Dot(atras))
		if alto < 0.004 then
			return
		end
		if l1 > 0.004 then
			local cuna = CFrame.fromMatrix((a + b) / 2 + corr, derecha, arriba, atras)
			Kit.parte(grupo, cf * cuna, Vector3.new(grosor, alto, l1), color, material, op)
		end
		if l2 > 0.004 then
			local cuna = CFrame.fromMatrix((a + d) / 2 + corr, -derecha, arriba, -atras)
			Kit.parte(grupo, cf * cuna, Vector3.new(grosor, alto, l2), color, material, op)
		end
	end

	-- Panel fino sobre cuatro puntos locales (a-b y d-e son los bordes "de anillo").
	-- `dentro` es un punto interior para orientar la cara; `hundir` lo mete hacia dentro.
	-- Si el cuadrilátero es casi un rectángulo usa una sola parte; si no, cuatro cuñas.
	local function placa(
		grupo: Instance,
		a: Vector3,
		b: Vector3,
		d: Vector3,
		e: Vector3,
		dentro: Vector3,
		color: Color3,
		material: Enum.Material,
		grosor: number,
		hundir: number,
		o: Kit.Opciones?
	): BasePart?
		local largo = ((d - a) + (e - b)) / 2
		local ancho = ((b - a) + (e - d)) / 2
		local normal = largo:Cross(ancho)
		if normal.Magnitude > 1e-4 and ancho.Magnitude > 0.02 and largo.Magnitude > 0.02 then
			local centro = (a + b + d + e) / 4
			local ejeX = ancho.Unit
			normal = normal.Unit
			if normal:Dot(centro - dentro) < 0 then
				normal = -normal
			end
			local ejeZ = ejeX:Cross(normal)
			local w, l = ancho.Magnitude / 2, largo.Magnitude / 2 * math.sign(ejeZ:Dot(largo))
			local desvio = math.max(
				(centro - ejeX * w - ejeZ * l - a).Magnitude,
				(centro + ejeX * w - ejeZ * l - b).Magnitude,
				(centro - ejeX * w + ejeZ * l - d).Magnitude,
				(centro + ejeX * w + ejeZ * l - e).Magnitude
			)
			if desvio < 0.02 then
				local tam = Vector3.new(ancho.Magnitude + 0.02, grosor, largo.Magnitude + 0.02)
				local pos = centro - normal * (grosor / 2 + hundir)
				return Kit.parte(grupo, cf * CFrame.fromMatrix(pos, ejeX, normal, ejeZ), tam, color, material, o or SIN)
			end
		end
		triangulo(grupo, a, b, e, dentro, color, material, grosor, hundir, o)
		triangulo(grupo, a, e, d, dentro, color, material, grosor, hundir, o)
		return nil
	end

	-- ── casco ────────────────────────────────────────────────────────────────
	local puerta = Kit.modelo("Puerta", m)
	puerta:SetAttribute("Recorrido", PUERTA_RECORRIDO)
	local cristal =
		{ colision = false, consulta = false, sombra = false, transparencia = 0.45, reflejo = 0.3 } :: Kit.Opciones
	for i = 1, #ZS - 1 do
		local z0, z1 = ZS[i], ZS[i + 1]
		local zc = (z0 + z1) / 2
		local dentro = Vector3.new(0, 5, math.clamp(zc, -9, 4))
		for k = 1, #FR - 1 do
			local f0, f1 = FR[k], FR[k + 1]
			local fc = (f0 + f1) / 2
			for _, lado in { 1, -1 } do
				local a, b = punto(z0, f0, lado), punto(z0, f1, lado)
				local d, e = punto(z1, f0, lado), punto(z1, f1, lado)
				local enPuerta = lado > 0 and zc > PUERTA_Z0 and zc < PUERTA_Z1 and fc > PUERTA_F0 and fc < PUERTA_F1
				local esVidrio = (zc < -10.65 and fc > 0.5 and fc < 0.885)
					or (zc > -10.65 and zc < -8.6 and fc > 0.5 and fc < 0.81)
				local color = if fc < 0.338 then NARANJA elseif fc < 0.417 then TURQUESA else BLANCO
				if enPuerta then
					local hoja = placa(puerta, a, b, d, e, dentro, color, LISO, 0.14, -0.1)
					if hoja and fc > 0.417 and fc < 0.5 then
						hoja.Name = "Hoja"
						puerta.PrimaryPart = hoja
					end
				elseif esVidrio then
					placa(m, a, b, d, e, dentro, VIDRIO, M.Glass, 0.04, 0.02, cristal)
				else
					placa(m, a, b, d, e, dentro, color, LISO, 0.16, 0)
					-- forro interior de la bodega (se ve por la puerta)
					if zc > -6.6 and zc < 4.6 then
						placa(m, a, b, d, e, dentro, OLIVA, M.Fabric, 0.06, 0.17, LUZ)
					end
				end
			end
		end
	end
	-- punta del morro y cierre trasero sobre la rampa
	Kit.ovoide(m, c(0, 4.3, -14.27), Vector3.new(0.75, 0.75, 0.4), NEGRO, LISO, SIN)
	Kit.parte(m, c(0, 7.0, 9.72), Vector3.new(3.7, 2.0, 0.16), BLANCO, LISO, SIN)

	-- marco del parabrisas y de las ventanas de cabina
	local function liston(a: Vector3, b: Vector3, diametro: number, color: Color3)
		Kit.cilindro(m, mundo(a), mundo(b), diametro, color, LISO, SIN)
	end
	for _, lado in { 1, -1 } do
		for _, z in { -10.65, -8.6 } do
			local tope = if z < -9 then 0.885 else 0.81
			local previo: Vector3? = nil
			for _, f in { 0.5, 0.62, 0.74, 0.81, 0.885 } do
				if f <= tope then
					local actual = punto(z, f, lado) * Vector3.new(1.012, 1, 1)
					if previo then
						liston(previo, actual, 0.18, BLANCO)
					end
					previo = actual
				end
			end
		end
		for i = 2, 8 do
			local z0, z1 = ZS[i], ZS[i + 1]
			liston(punto(z0, 0.5, lado), punto(z1, 0.5, lado), 0.14, BLANCO)
		end
	end
	-- limpiaparabrisas
	for _, lado in { 1, -1 } do
		local base = punto(-12.9, 0.52, lado) + Vector3.new(0.05 * lado, 0, -0.1)
		liston(base, base + Vector3.new(-0.5 * lado, 1.1, -0.1), 0.07, NEGRO)
	end

	-- ojos de buey: aro gris y cristal oscuro
	local function ojo(grupo: Instance, z: number, lado: number, extra: number)
		local s = punto(z, 0.66, lado)
		local x = s.X + lado * extra
		Kit.cilindro(grupo, p(x - lado * 0.06, s.Y, z), p(x + lado * 0.08, s.Y, z), 1.52, GRIS, M.Metal, SIN)
		Kit.cilindro(grupo, p(x, s.Y, z), p(x + lado * 0.11, s.Y, z), 1.22, VIDRIO, M.Glass, {
			colision = false,
			reflejo = 0.35,
		})
	end
	for _, z in { 0.8, 2.9 } do
		ojo(m, z, 1, 0)
	end
	ojo(puerta, (PUERTA_Z0 + PUERTA_Z1) / 2, 1, 0.1)
	for _, z in { -6.0, -3.8, -1.6, 0.6, 2.8 } do
		ojo(m, z, -1, 0)
	end

	-- manilla y marco de la puerta
	do
		local s = punto(PUERTA_Z1 - 0.6, 0.45, 1)
		Kit.parte(puerta, c(s.X + 0.24, s.Y, PUERTA_Z1 - 0.6), Vector3.new(0.08, 1.05, 0.4), GRIS, M.Metal, SIN)
		Kit.parte(puerta, c(s.X + 0.3, s.Y, PUERTA_Z1 - 0.6), Vector3.new(0.12, 0.85, 0.22), CROMO, M.Metal, SIN)
		-- riel superior con soportes y guía inferior
		local r = punto(0, 0.915, 1)
		local x = r.X + 0.34
		Kit.cilindro(
			m,
			p(x, r.Y, PUERTA_Z0 - 0.4),
			p(x, r.Y, PUERTA_Z1 + PUERTA_RECORRIDO + 0.4),
			0.16,
			CROMO,
			M.Metal,
			SIN
		)
		for _, z in { PUERTA_Z0 - 0.2, PUERTA_Z1 + 1.2, PUERTA_Z1 + PUERTA_RECORRIDO + 0.2 } do
			Kit.parte(m, c(x - 0.18, r.Y, z), Vector3.new(0.42, 0.14, 0.22), GRIS, M.Metal, SIN)
		end
		local g = punto(0, 0.1, 1)
		Kit.parte(
			m,
			c(g.X + 0.12, g.Y, (PUERTA_Z0 + PUERTA_Z1 + PUERTA_RECORRIDO) / 2),
			Vector3.new(0.14, 0.1, PUERTA_Z1 - PUERTA_Z0 + PUERTA_RECORRIDO),
			GRIS,
			M.Metal,
			SIN
		)
	end

	-- ── motores, carenado y mástil ───────────────────────────────────────────
	Kit.parte(m, c(0, 8.95, -1.55), Vector3.new(4.0, 1.3, 10.3), BLANCO, LISO, SIN)
	Kit.ovoide(m, c(0, 8.75, 5.3), Vector3.new(3.4, 2.1, 8.4), BLANCO, LISO, SIN)
	Kit.ovoide(m, c(0, 8.8, -7.6), Vector3.new(3.9, 1.5, 3.0), BLANCO, LISO, SIN)
	for _, s in { 1, -1 } do
		local x = s * 1.5
		Kit.cilindro(m, p(x, 10, -7.0), p(x, 10, 1.7), 2.2, BLANCO, LISO, SIN)
		Kit.cilindro(m, p(x, 10, -7.0), p(x, 10, -6.75), 2.32, CROMO, M.Metal, SIN)
		Kit.cilindro(m, p(x, 10, -7.04), p(x, 10, -6.9), 1.7, NEGRO, LISO, SIN)
		Kit.ovoide(m, c(x, 10, -7.05), Vector3.new(0.62, 0.62, 0.7), GRIS_CLARO, M.Metal, SIN)
		for k = 0, 5 do -- álabes de la toma
			local a = k / 6 * math.pi
			Kit.parte(m, c(x, 10, -7.06) * CFrame.Angles(0, 0, a), Vector3.new(1.6, 0.07, 0.05), GRIS, M.Metal, SIN)
		end
		Kit.ovoide(m, c(x, 10, 1.7), Vector3.new(2.1, 2.1, 1.8), BLANCO, LISO, SIN)
		-- escape doblado hacia fuera
		Kit.cilindro(m, p(x, 10, 1.4), p(x + s * 0.8, 10.25, 3.7), 1.2, GRIS_CLARO, M.Metal, SIN)
		Kit.cilindro(m, p(x + s * 0.76, 10.24, 3.6), p(x + s * 0.81, 10.26, 3.74), 0.95, NEGRO, LISO, SIN)
		-- carenado lateral y rejillas
		Kit.parte(m, c(s * 1.55, 9.25, -2.3), Vector3.new(1.0, 0.7, 7.2), BLANCO, LISO, SIN)
		for k = 0, 4 do
			Kit.parte(m, c(s * 2.02, 8.6 + k * 0.17, 0.9), Vector3.new(0.05, 0.08, 1.5), NEGRO, M.Metal, SIN)
		end
	end
	Kit.cilindro(m, p(0, 9.6, ROTOR_EJE.Z), p(0, ROTOR_EJE.Y - 0.25, ROTOR_EJE.Z), 0.84, GRIS, M.Metal, SIN)
	Kit.cilindro(m, p(0, 10.65, ROTOR_EJE.Z), p(0, 10.95, ROTOR_EJE.Z), 1.9, CROMO, M.Metal, SIN)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		Kit.cilindro(
			m,
			p(math.cos(a) * 0.7, 10.95, ROTOR_EJE.Z + math.sin(a) * 0.7),
			p(math.cos(a) * 0.55, ROTOR_EJE.Y - 0.1, ROTOR_EJE.Z + math.sin(a) * 0.55),
			0.12,
			GRIS,
			M.Metal,
			SIN
		)
	end

	-- ── botalón de cola (tubo cónico de paneles), deriva y estabilizadores ────
	do
		local LADOS, TRAMOS = 12, 4
		local function anillo(z: number, k: number): Vector3
			local t = (z - 6.4) / 17.6
			local u = t ^ 0.8
			local a = k / LADOS * math.pi * 2
			return Vector3.new((1.75 - 1.2 * u) * math.cos(a), 7.25 + 0.9 * t + (1.45 - 0.85 * u) * math.sin(a), z)
		end
		for i = 0, TRAMOS - 1 do
			local z0, z1 = 6.4 + 17.6 * i / TRAMOS, 6.4 + 17.6 * (i + 1) / TRAMOS
			local dentro = Vector3.new(0, 7.25 + 0.9 * ((z0 + z1) / 2 - 6.4) / 17.6, (z0 + z1) / 2)
			for k = 0, LADOS - 1 do
				placa(
					m,
					anillo(z0, k),
					anillo(z0, k + 1),
					anillo(z1, k),
					anillo(z1, k + 1),
					dentro,
					BLANCO,
					LISO,
					0.12,
					0
				)
			end
		end
		Kit.ovoide(m, c(0, 8.15, 24.0), Vector3.new(1.1, 1.2, 1.4), BLANCO, LISO, SIN)
	end
	Kit.parte(m, c(0, 10.4, 23.3) * CFrame.Angles(math.rad(-16), 0, 0), Vector3.new(0.4, 4.9, 2.7), BLANCO, LISO, SIN)
	Kit.parte(
		m,
		c(0, 12.75, 24.05) * CFrame.Angles(math.rad(-16), 0, 0),
		Vector3.new(0.42, 0.5, 2.2),
		NARANJA,
		LISO,
		SIN
	)
	Kit.parte(m, c(0, 7.1, 24.1) * CFrame.Angles(math.rad(14), 0, 0), Vector3.new(0.32, 1.6, 1.1), BLANCO, LISO, SIN)
	Kit.ovoide(m, c(0.1, 10.9, 23.7), Vector3.new(1.0, 1.3, 1.7), BLANCO, LISO, SIN)
	for _, s in { 1, -1 } do
		Kit.parte(m, c(s * 1.75, 8.45, 21.95), Vector3.new(2.9, 0.18, 1.6), BLANCO, LISO, SIN)
		local nav = Kit.parte(
			m,
			c(s * 3.25, 8.45, 21.95),
			Vector3.one * 0.3,
			if s < 0 then Color3.fromRGB(255, 50, 40) else Color3.fromRGB(60, 255, 110),
			M.Neon,
			{ forma = Enum.PartType.Ball, colision = false, sombra = false }
		)
		Kit.luz(nav, nav.Color, 6, 1)
	end
	local estrobo = Kit.parte(m, c(0, 13.1, 24.5), Vector3.one * 0.32, Color3.new(1, 1, 1), M.Neon, {
		forma = Enum.PartType.Ball,
		colision = false,
		sombra = false,
	})
	Kit.etiquetar(estrobo, "Baliza")

	-- matrícula a ambos lados del botalón
	local placaMatricula = Kit.parte(m, c(0, 7.68, 14.6), Vector3.new(2.3, 0.95, 4.4), BLANCO, LISO, {
		colision = false,
		sombra = false,
		transparencia = 1,
		nombre = "Matricula",
	})
	for _, cara in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = cara
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = placaMatricula
		local texto = Instance.new("TextLabel")
		texto.BackgroundTransparency = 1
		texto.Size = UDim2.fromScale(1, 1)
		texto.Font = Enum.Font.GothamBold
		texto.TextScaled = true
		texto.TextColor3 = Color3.fromRGB(30, 34, 36)
		texto.Text = "AMZ-07"
		texto.Parent = gui
	end

	-- ── rotores ──────────────────────────────────────────────────────────────
	local rotor = Kit.modelo("Rotor", m)
	local eje = Kit.parte(rotor, cf * CFrame.new(ROTOR_EJE), Vector3.new(1.5, 0.8, 1.5), GRIS, M.Metal, {
		nombre = "Eje",
		colision = false,
	})
	rotor.PrimaryPart = eje
	Kit.cilindro(
		rotor,
		mundo(ROTOR_EJE - Vector3.new(0, 0.35, 0)),
		mundo(ROTOR_EJE + Vector3.new(0, 0.45, 0)),
		1.6,
		GRIS,
		M.Metal,
		SIN
	)
	Kit.ovoide(rotor, cf * CFrame.new(ROTOR_EJE + Vector3.new(0, 0.55, 0)), Vector3.new(0.9, 0.6, 0.9), CROMO, M.Metal)
	local LARGO = 15.3
	for i = 1, 5 do
		local giro = cf * CFrame.new(ROTOR_EJE) * CFrame.Angles(0, i / 5 * math.pi * 2, 0)
		Kit.parte(rotor, giro * CFrame.new(0, 0, -1.15), Vector3.new(0.4, 0.4, 1.5), GRIS, M.Metal, SIN)
		Kit.parte(rotor, giro * CFrame.new(0, 0.2, -1.4), Vector3.new(0.3, 0.3, 0.3), CROMO, M.Metal, SIN)
		local caida = CFrame.Angles(math.rad(-1.2), 0, 0)
		Kit.parte(
			rotor,
			giro * caida * CFrame.new(0, 0, -LARGO / 2 - 1.7),
			Vector3.new(1.3, 0.13, LARGO),
			NEGRO,
			LISO,
			SIN
		)
		Kit.parte(
			rotor,
			giro * caida * CFrame.new(0, 0, -LARGO - 2.2),
			Vector3.new(1.32, 0.15, 1.0),
			AMARILLO,
			LISO,
			SIN
		)
	end

	local cola = Kit.modelo("RotorCola", m)
	local ejeCola = Kit.cilindro(
		cola,
		mundo(COLA_EJE - Vector3.new(0.3, 0, 0)),
		mundo(COLA_EJE + Vector3.new(0.3, 0, 0)),
		0.6,
		GRIS,
		M.Metal,
		SIN
	)
	ejeCola.Name = "Eje"
	cola.PrimaryPart = ejeCola
	for i = 0, 3 do
		local giro = cf * CFrame.new(COLA_EJE + Vector3.new(0.08, 0, 0)) * CFrame.Angles(i / 4 * math.pi * 2, 0, 0)
		Kit.parte(cola, giro * CFrame.new(0, 1.3, 0), Vector3.new(0.1, 2.2, 0.44), NEGRO, LISO, SIN)
		Kit.parte(cola, giro * CFrame.new(0, 2.5, 0), Vector3.new(0.11, 0.35, 0.45), AMARILLO, LISO, SIN)
	end

	-- ── tren de aterrizaje y sponsons ────────────────────────────────────────
	local function rueda(x: number, y: number, z: number, radio: number, ancho: number)
		Kit.cilindro(m, p(x - ancho / 2, y, z), p(x + ancho / 2, y, z), radio * 2, GOMA, LISO, SIN)
		Kit.cilindro(
			m,
			p(x - ancho / 2 - 0.02, y, z),
			p(x + ancho / 2 + 0.02, y, z),
			radio * 1.05,
			GRIS_CLARO,
			M.Metal,
			SIN
		)
		Kit.cilindro(m, p(x - ancho / 2 - 0.05, y, z), p(x + ancho / 2 + 0.05, y, z), 0.3, CROMO, M.Metal, SIN)
	end
	for _, s in { 1, -1 } do
		Kit.ovoide(m, c(s * 3.95, 2.05, 2.7), Vector3.new(1.8, 1.56, 6.6), NARANJA, LISO, SIN)
		Kit.parte(m, c(s * 3.45, 2.1, 2.7), Vector3.new(0.9, 0.5, 4.2), NARANJA, LISO, SIN)
		rueda(s * 4.0, 0.85, 3.0, 0.85, 0.6)
		Kit.cilindro(m, p(s * 4.0, 0.95, 3.0), p(s * 3.95, 1.6, 2.8), 0.4, CROMO, M.Metal, SIN)
		Kit.cilindro(m, p(s * 3.4, 1.4, 1.8), p(s * 3.95, 1.05, 2.75), 0.24, GRIS, M.Metal, SIN)
		local faro = Kit.ovoide(
			m,
			c(s * 3.95, 2.0, -0.55),
			Vector3.new(0.36, 0.36, 0.2),
			Color3.fromRGB(255, 242, 200),
			M.Neon,
			LUZ
		)
		faro.Name = "Faro"
		-- luces de navegación del morro
		local nav = Kit.parte(
			m,
			cf * CFrame.new(punto(-9.4, 0.3, s) + Vector3.new(s * 0.08, 0, 0)),
			Vector3.one * 0.3,
			if s < 0 then Color3.fromRGB(255, 50, 40) else Color3.fromRGB(60, 255, 110),
			M.Neon,
			{ forma = Enum.PartType.Ball, colision = false, sombra = false }
		)
		Kit.luz(nav, nav.Color, 6, 1)
	end
	Kit.cilindro(m, p(0, 2.0, -10.4), p(0, 0.8, -10.55), 0.32, CROMO, M.Metal, SIN)
	Kit.parte(m, c(0, 0.72, -10.55), Vector3.new(0.5, 0.25, 0.3), GRIS, M.Metal, SIN)
	for _, s in { 1, -1 } do
		rueda(s * 0.34, 0.62, -10.55, 0.62, 0.34)
	end

	-- antenas y baliza del lomo
	for _, a in { { 0, 8.5, -7.8, 1.1 }, { 0.9, 8.45, 3.6, 0.9 }, { -0.9, 8.45, 4.2, 0.7 } } do
		Kit.cilindro(m, p(a[1], a[2], a[3]), p(a[1], a[2] + a[4], a[3] + 0.25), 0.08, NEGRO, M.Metal, SIN)
		Kit.cilindro(m, p(a[1], a[2] - 0.05, a[3]), p(a[1], a[2] + 0.12, a[3]), 0.24, GRIS, M.Metal, SIN)
	end
	local baliza = Kit.parte(m, c(0, 9.85, 2.6), Vector3.new(0.5, 0.35, 0.5), Color3.fromRGB(255, 40, 30), M.Neon, LUZ)
	Kit.luz(baliza, Color3.fromRGB(255, 50, 40), 14, 1.6)
	Kit.etiquetar(baliza, "Baliza")

	-- ── interior: bodega ─────────────────────────────────────────────────────
	local Y_SUELO = 2.45
	Kit.parte(m, c(0, Y_SUELO - 0.12, -1.0), Vector3.new(6.3, 0.24, 11.4), SUELO, M.DiamondPlate, SIN)
	Kit.parte(m, c(0, Y_SUELO - 0.15, -9.0), Vector3.new(5.4, 0.2, 4.8), SUELO, M.DiamondPlate, SIN)
	-- mamparo con paso a la cabina de pilotos
	for _, s in { 1, -1 } do
		Kit.parte(m, c(s * 2.55, 5.1, -6.75), Vector3.new(2.3, 5.4, 0.18), OLIVA_OSC, M.Metal, SIN)
	end
	Kit.parte(m, c(0, 7.55, -6.75), Vector3.new(2.8, 1.0, 0.18), OLIVA_OSC, M.Metal, SIN)
	-- fondo de la bodega (antes de la rampa)
	Kit.parte(m, c(0, 5.2, 4.7), Vector3.new(7.0, 5.6, 0.18), OLIVA_OSC, M.Metal, SIN)
	-- cuadernas y vigas del techo
	for _, z in { -5.9, -1.1, 1.0, 3.1 } do
		for _, s in { 1, -1 } do
			local previo: Vector3? = nil
			for _, f in { 0.17, 0.3, 0.5, 0.7, 0.86 } do
				local actual = punto(z, f, s) * Vector3.new(0.93, 1, 1)
				if previo then
					Kit.cilindro(m, mundo(previo), mundo(actual), 0.2, OLIVA_OSC, M.Metal, LUZ)
				end
				previo = actual
			end
		end
		Kit.parte(m, c(0, 8.12, z), Vector3.new(5.2, 0.2, 0.22), OLIVA_OSC, M.Metal, LUZ)
	end
	-- asientos de lona con cinchas (babor completo; estribor detrás de la puerta)
	local function banco(s: number, z0: number, z1: number)
		local x = s * 3.05
		local medio, largo = (z0 + z1) / 2, z1 - z0
		Kit.parte(m, c(x - s * 0.75, 3.7, medio), Vector3.new(0.08, 0.08, largo), CROMO, M.Metal, LUZ)
		Kit.parte(m, c(x + s * 0.06, 6.05, medio), Vector3.new(0.08, 0.08, largo), CROMO, M.Metal, LUZ)
		local z = z0
		while z + 1.2 <= z1 + 0.01 do
			local zc = z + 0.6
			Kit.parte(m, c(x - s * 0.4, 3.72, zc), Vector3.new(0.82, 0.1, 1.1), LONA, M.Fabric, LUZ)
			Kit.parte(m, c(x + s * 0.02, 4.9, zc), Vector3.new(0.08, 2.2, 1.1), LONA, M.Fabric, LUZ)
			for _, dz in { -0.3, 0.3 } do
				Kit.parte(m, c(x - s * 0.03, 4.9, zc + dz), Vector3.new(0.06, 2.2, 0.08), CINCHA, M.Fabric, LUZ)
			end
			Kit.cilindro(
				m,
				p(x - s * 0.75, Y_SUELO, zc - 0.5),
				p(x - s * 0.75, 3.7, zc - 0.5),
				0.1,
				CROMO,
				M.Metal,
				LUZ
			)
			z += 1.25
		end
	end
	banco(-1, -6.4, 3.6)
	banco(1, -0.9, 3.6)
	-- carga amarrada al fondo
	for _, d in
		{ { -1.1, 0.55, 3.8, 1.6, 1.1, 1.3 }, { 0.7, 0.45, 3.9, 1.3, 0.9, 1.1 }, { -0.9, 1.45, 3.85, 1.2, 0.7, 1.0 } }
	do
		Kit.parte(m, c(d[1], Y_SUELO + d[2], d[3]), Vector3.new(d[4], d[5], d[6]), CAJA, M.WoodPlanks, LUZ)
		Kit.parte(m, c(d[1], Y_SUELO + d[2], d[3]), Vector3.new(d[4] + 0.04, d[5] + 0.04, 0.12), CINCHA, M.Fabric, LUZ)
	end
	-- tubos y lámparas del techo
	for _, x in { -1.6, 1.6 } do
		Kit.cilindro(m, p(x, 7.95, -6.6), p(x, 7.95, 4.6), 0.18, GRIS, M.Metal, LUZ)
	end
	for _, z in { -4.6, -1.0, 2.6 } do
		Kit.parte(m, c(0, 7.95, z), Vector3.new(0.7, 0.14, 0.4), GRIS, M.Metal, LUZ)
		local lampara =
			Kit.parte(m, c(0, 7.86, z), Vector3.new(0.5, 0.05, 0.28), Color3.fromRGB(255, 232, 190), M.Neon, LUZ)
		if z == -1.0 then
			Kit.luz(lampara, Color3.fromRGB(255, 220, 170), 13, 0.9)
		end
	end

	-- ── interior: cabina de pilotos ──────────────────────────────────────────
	for _, s in { 1, -1 } do
		local x = s * 1.2
		Kit.parte(m, c(x, 2.9, -9.9), Vector3.new(0.7, 0.7, 0.7), GRIS, M.Metal, LUZ)
		Kit.parte(m, c(x, 3.35, -9.9), Vector3.new(1.15, 0.3, 1.1), CUERO, M.Fabric, LUZ)
		Kit.parte(
			m,
			c(x, 4.6, -9.35) * CFrame.Angles(math.rad(-10), 0, 0),
			Vector3.new(1.15, 2.4, 0.28),
			CUERO,
			M.Fabric,
			LUZ
		)
		Kit.parte(m, c(x, 6.0, -9.12), Vector3.new(0.8, 0.5, 0.25), CUERO, M.Fabric, LUZ)
		Kit.cilindro(m, p(x, 2.5, -11.0), p(x, 4.0, -10.75), 0.1, NEGRO, M.Metal, LUZ)
	end
	Kit.parte(m, c(0, 3.2, -10.5), Vector3.new(0.7, 1.4, 2.0), GRIS, M.Metal, LUZ)
	local tablero = c(0, 4.3, -11.9) * CFrame.Angles(math.rad(25), 0, 0)
	Kit.parte(m, tablero, Vector3.new(4.6, 1.3, 0.8), NEGRO, LISO, LUZ)
	Kit.parte(m, c(0, 5.0, -11.7), Vector3.new(4.7, 0.16, 1.0), GRIS, LISO, LUZ)
	-- pantallas apagadas: cristal oscuro, sin neón
	for _, x in { -1.5, -0.5, 0.5, 1.5 } do
		Kit.parte(
			m,
			tablero * CFrame.new(x, 0.05, 0.41),
			Vector3.new(0.75, 0.55, 0.03),
			if math.abs(x) > 1 then Color3.fromRGB(46, 92, 62) else Color3.fromRGB(104, 76, 38),
			M.Glass,
			LUZ
		)
	end
	Kit.parte(m, c(0, 7.75, -10.0), Vector3.new(2.2, 0.3, 1.6), NEGRO, LISO, LUZ)

	-- ── colisión simple y punto de embarque ──────────────────────────────────
	local invisible = { transparencia = 1, sombra = false, nombre = "Colision" } :: Kit.Opciones
	Kit.parte(m, c(0, 5, -2.4), Vector3.new(7.6, 6.8, 23.6), Color3.new(), LISO, invisible)
	Kit.parte(m, c(0, 7.8, 16), Vector3.new(2.6, 2.4, 16), Color3.new(), LISO, invisible)

	local cabina = Instance.new("Attachment")
	cabina.Name = "Cabina"
	cabina.Parent = Kit.parte(m, c(0, 4.6, (PUERTA_Z0 + PUERTA_Z1) / 2 - 0.4), Vector3.one, Color3.new(), LISO, {
		transparencia = 1,
		colision = false,
		consulta = false,
		nombre = "Interior",
	})
	return m
end

return Transporte
