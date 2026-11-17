--!strict
-- Botánica nativa: partes, materiales del motor y hojas opacas. Sin assets externos.
-- Los modelos se construyen a escala de referencia; Vegetacion los clona y escala.
local Kit = require(script.Parent.Kit)
local Triangulos = require(script.Parent.Triangulos)

local Botanica = {}
local M = Enum.Material
local TAU = math.pi * 2
local VERDES = { Color3.fromRGB(39, 65, 38), Color3.fromRGB(53, 81, 43), Color3.fromRGB(66, 88, 47) }
local CORTEZA = Color3.fromRGB(83, 73, 59)
local MUSGO = Color3.fromRGB(54, 72, 40)
local HOJA = { colision = false, consulta = false, sombra = false }
local RAMA = { colision = false, consulta = false }

local function radial(a: number): Vector3
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- Hoja lanceolada por secciones: nervio central elevado y bordes curvados.
-- El ancho y la caída de las puntas rompen la silueta rectangular de las plantas antiguas.
function Botanica.hoja(m: Model, a: Vector3, b: Vector3, ancho: number, color: Color3, detalle: boolean?)
	local eje = b - a
	local lateral = eje:Cross(Vector3.yAxis)
	if lateral.Magnitude < 0.01 then
		lateral = Vector3.xAxis
	end
	lateral = lateral.Unit
	local vertices: { number } = {}
	local caras: { number } = {}
	local segmentos = if detalle then 4 else 2
	for i = 0, segmentos do
		local t = i / segmentos
		local centro = a:Lerp(b, t) + Vector3.yAxis * math.sin(t * math.pi) * ancho * 0.18
		local semiancho = math.max(0.015, math.sin(t * math.pi) ^ 0.8 * ancho * 0.5)
		for lado = -1, 1 do
			local p = centro + lateral * lado * semiancho - Vector3.yAxis * math.abs(lado) * semiancho * 0.18
			table.insert(vertices, p.X)
			table.insert(vertices, p.Y)
			table.insert(vertices, p.Z)
		end
	end
	local function triangulo(x: number, y: number, z: number)
		for _, n in { x, y, z, 255, 255, 255 } do
			table.insert(caras, n)
		end
	end
	for i = 0, segmentos - 1 do
		local k = i * 3 + 1
		for lado = 0, 1 do
			triangulo(k + lado, k + lado + 3, k + lado + 1)
			triangulo(k + lado + 1, k + lado + 3, k + lado + 4)
		end
	end
	Triangulos.construir(
		m,
		{ v = vertices, t = caras },
		function(p)
			return p
		end,
		0.045,
		function(_, normal)
			return color:Lerp(Color3.fromRGB(103, 117, 61), if normal.Y > 0 then 0.08 else 0), M.Grass
		end,
		HOJA
	)
end

-- Copas continuas de lóbulos desiguales. Las masas grandes tapan las ramas y las
-- pequeñas rompen el contorno: ninguna esfera suelta ni rombos gigantes flotando.
local function copa(m: Model, rng: Random, centro: Vector3, radio: number)
	local color = Kit.elegir(rng, VERDES)
	for j = 1, 5 do
		local a = j * 2.39996 + rng:NextNumber(-0.25, 0.25)
		local p = centro
			+ radial(a) * radio * rng:NextNumber(0.15, 0.42)
			+ Vector3.yAxis * rng:NextNumber(-radio * 0.08, radio * 0.16)
		Kit.ovoide(
			m,
			CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), a, 0),
			Vector3.new(radio * 1.65, radio * rng:NextNumber(0.5, 0.7), radio * 1.15),
			Kit.variar(color, rng, 0.025),
			M.LeafyGrass,
			RAMA
		)
	end
	for j = 1, 12 do
		local a = j * 2.39996
		local p = centro
			+ radial(a) * radio * rng:NextNumber(0.55, 0.9)
			+ Vector3.yAxis * rng:NextNumber(-radio * 0.1, radio * 0.18)
		local r = radio * rng:NextNumber(0.25, 0.4)
		Kit.ovoide(
			m,
			CFrame.new(p) * CFrame.Angles(-0.2, a, 0),
			Vector3.new(r * 2, r * 0.65, r * 1.35),
			Kit.variar(color, rng, 0.035),
			M.LeafyGrass,
			RAMA
		)
	end
end

local function tronco(m: Model, rng: Random, alto: number, diametro: number): Vector3
	local anterior = Vector3.new(0, -1, 0)
	local curva = radial(rng:NextNumber(0, TAU)) * alto * 0.06
	for i = 1, 5 do
		local t = i / 5
		local p = Vector3.yAxis * alto * t + curva * t * t
		local d = diametro * (1 - t * 0.64)
		Kit.cilindro(m, anterior, p, d, Kit.variar(CORTEZA, rng, 0.025), M.Wood)
		-- Contrafuertes y costillas longitudinales en la zona que ve el jugador.
		if i <= 2 then
			for k = 1, 3 do
				local o = radial(k / 3 * TAU) * d * 0.4
				Kit.cilindro(
					m,
					anterior + o,
					p + o * 0.82,
					d * 0.18,
					if k == 1 then MUSGO else CORTEZA,
					if k == 1 then M.Grass else M.Wood,
					RAMA
				)
			end
		end
		anterior = p
	end
	for i = 1, 5 do
		local dir = radial(i / 5 * TAU + rng:NextNumber(-0.2, 0.2))
		local pie = dir * diametro * rng:NextNumber(1, 1.7) - Vector3.yAxis * 0.5
		Kit.cilindro(
			m,
			pie,
			Vector3.yAxis * diametro * 1.6 + dir * diametro * 0.2,
			diametro * 0.32,
			CORTEZA,
			M.Wood,
			RAMA
		)
	end
	return anterior
end

function Botanica.arbol(m: Model, rng: Random, gigante: boolean)
	local alto = if gigante then 100 else 80
	local d = if gigante then 8 else rng:NextNumber(3, 4.5)
	local cima = tronco(m, rng, alto * 0.83, d)
	local n = if gigante then 7 else 5
	for i = 1, n do
		local a = i / n * TAU + rng:NextNumber(-0.4, 0.4)
		local salida = cima - Vector3.yAxis * rng:NextNumber(5, 22)
		local codo = salida + radial(a) * alto * 0.12 + Vector3.yAxis * alto * 0.1
		local punta = codo + radial(a + 0.3) * alto * 0.12 + Vector3.yAxis * rng:NextNumber(0, 6)
		Kit.cilindro(m, salida, codo, d * 0.45, CORTEZA, M.Wood, RAMA)
		Kit.cilindro(m, codo, punta, d * 0.22, CORTEZA, M.Wood, RAMA)
		copa(m, rng, punta, alto * rng:NextNumber(0.15, 0.2))
		if i % 2 == 0 then
			local p = punta
			for j = 1, 3 do
				local q = p + Vector3.new(math.sin(j + a) * 1.4, -alto * 0.055, math.cos(j + a))
				Kit.cilindro(m, p, q, 0.18, MUSGO, M.Grass, HOJA)
				p = q
			end
		end
	end
	copa(m, rng, cima + Vector3.yAxis * alto * 0.09, alto * 0.2)
end

-- Raquis curvo y foliolos separados: se lee como una fronda, no como dos tablas.
function Botanica.fronda(m: Model, rng: Random, base: Vector3, dir: Vector3, largo: number, pares: number)
	local color = Kit.elegir(rng, VERDES)
	local lado = Vector3.new(-dir.Z, 0, dir.X)
	local function punto(t: number): Vector3
		return base + dir * largo * t + Vector3.yAxis * largo * (0.42 * math.sin(t * math.pi) - t * 0.15)
	end
	local previo = base
	for i = 1, 3 do
		local p = punto(i / 3)
		Kit.cilindro(m, previo, p, math.max(0.055, largo * 0.012), color, M.SmoothPlastic, HOJA)
		previo = p
	end
	for i = 1, pares do
		local t = i / (pares + 1)
		local p = punto(t)
		for _, signo in { -1, 1 } do
			local punta = p + (lado * signo * 0.65 + dir * 0.45) * largo * (1 - t * 0.75) * 0.34
			-- Foliolos finos, opacos: una sola parte por foliolo, sin transparencia ni overdraw.
			Kit.ovoide(
				m,
				CFrame.lookAt((p + punta) / 2, punta),
				Vector3.new(largo * 0.065 * (1 - t * 0.4), 0.055, (punta - p).Magnitude),
				Kit.variar(color, rng, 0.025),
				M.SmoothPlastic,
				{ colision = false, consulta = false, sombra = false }
			)
		end
	end
end

function Botanica.palmera(m: Model, rng: Random)
	local curva = radial(rng:NextNumber(0, TAU)) * rng:NextNumber(5, 10)
	local previo = Vector3.new(0, -0.5, 0)
	for i = 1, 9 do
		local t = i / 9
		local p = Vector3.yAxis * t * 45 + curva * t * t
		Kit.cilindro(m, previo, p, 2.5 - t, CORTEZA, M.Wood)
		-- Cicatrices anulares: discontinuidades de color y diámetro, no anillos añadidos.
		previo = p
	end
	for i = 1, 9 do
		Botanica.fronda(m, rng, previo, radial(i / 9 * TAU), rng:NextNumber(14, 20), 6)
	end
end

function Botanica.helecho(m: Model, rng: Random)
	for i = 1, 5 do
		Botanica.fronda(
			m,
			rng,
			Vector3.new(0, 0.5, 0),
			radial(i / 5 * TAU + rng:NextNumber(-0.15, 0.15)),
			rng:NextNumber(3, 4.5),
			3
		)
	end
end

function Botanica.arbusto(m: Model, rng: Random)
	for i = 1, 3 do
		local dir = radial(i / 3 * TAU)
		local punta = dir * 1.2 + Vector3.yAxis * rng:NextNumber(2.5, 4.5)
		Kit.cilindro(m, Vector3.zero, punta, 0.13, CORTEZA, M.Wood, HOJA)
		for j = 1, 2 do
			local base = punta * (j / 3)
			local lado = radial(i * 1.7 + j * 2.4)
			Botanica.hoja(m, base, base + lado * 1.5 + Vector3.yAxis * 0.3, 0.9, Kit.elegir(rng, VERDES))
		end
	end
end

function Botanica.hojaGrande(m: Model, rng: Random)
	for i = 1, 4 do
		local dir = radial(i / 4 * TAU + rng:NextNumber(-0.3, 0.3))
		local base = dir * 0.5 + Vector3.yAxis * rng:NextNumber(3, 5)
		local punta = base + dir * rng:NextNumber(3, 4.5) - Vector3.yAxis * 0.6
		Kit.cilindro(m, Vector3.zero, base, 0.16, MUSGO, M.SmoothPlastic, HOJA)
		Botanica.hoja(m, base, punta, rng:NextNumber(1.5, 2.6), Kit.elegir(rng, VERDES), true)
		Kit.cilindro(m, base, punta, 0.055, MUSGO, M.SmoothPlastic, HOJA)
	end
end

return Botanica
