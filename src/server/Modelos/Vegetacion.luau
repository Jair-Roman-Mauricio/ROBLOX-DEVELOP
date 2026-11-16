--!strict
--[[
	Vegetación de selva construida con partes. Cada función recibe el punto del suelo y
	devuelve un Model. Las copas no colisionan ni reciben raycasts para no estorbar.
	Las rocas, los peñascos y las ceibas son copias hechas con partes de dos modelos 3D (ver
	Datos/ModelosSelva y Triangulos): no usan mallas subidas a Roblox, así que cargan para todos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Datos = require(script.Parent.Datos.ModelosSelva)
local Triangulos = require(script.Parent.Triangulos)

local V = Config.Mapa.Vegetacion

local M = Enum.Material
local BOLA = Enum.PartType.Ball

local HOJAS = {
	Color3.fromRGB(34, 70, 36),
	Color3.fromRGB(46, 86, 40),
	Color3.fromRGB(28, 60, 42),
	Color3.fromRGB(62, 100, 46),
	Color3.fromRGB(40, 78, 54),
}
local HOJAS_PALMA = { Color3.fromRGB(58, 102, 48), Color3.fromRGB(72, 112, 52), Color3.fromRGB(48, 90, 44) }
local HOJAS_CLARAS = { Color3.fromRGB(70, 122, 56), Color3.fromRGB(86, 132, 60), Color3.fromRGB(60, 110, 62) }
local CORTEZA = {
	Color3.fromRGB(84, 66, 50),
	Color3.fromRGB(98, 80, 60),
	Color3.fromRGB(72, 62, 52),
	Color3.fromRGB(112, 102, 86),
}
local LIANA = Color3.fromRGB(52, 72, 40)
local MUSGO = Color3.fromRGB(70, 96, 52)
local FLOR = { Color3.fromRGB(196, 52, 40), Color3.fromRGB(220, 120, 40), Color3.fromRGB(180, 40, 70) }

local Vegetacion = {}

local function lianas(m: Model, rng: Random, desde: Vector3, radio: number, cantidad: number)
	for _ = 1, cantidad do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radio)
		local p = desde + Vector3.new(math.cos(a) * r, rng:NextNumber(-2, 1), math.sin(a) * r)
		local largo = rng:NextNumber(8, 22)
		local fin = p + Vector3.new(rng:NextNumber(-1, 1), -largo, rng:NextNumber(-1, 1))
		Kit.cilindro(m, p, fin, rng:NextNumber(0.18, 0.32), LIANA, M.Grass, Kit.FOLLAJE)
	end
end

-- Ceiba gigante: tronco ancho, raíces tablares, copa amplia y lianas. Punto de referencia visual.
-- Lleva un árbol de partes, construido con `alto` studs, a la altura de selva pedida en Config:
-- lo escala entero desde el pie para que tronco, ramas y copa crezcan en proporción.
local function crecer(m: Model, suelo: Vector3, alto: number, rango: { number }, rng: Random): Model
	m.WorldPivot = CFrame.new(suelo)
	m:ScaleTo(rng:NextNumber(rango[1], rango[2]) / alto)
	return m
end

-- Moldes de las copias con partes: se construyen una vez, sin padre, y luego se clonan. Cada
-- molde tiene el pie en su pivote y mide `medida` studs (alto en la ceiba, ancho en las rocas).
local moldes: { [string]: Model } = {}

local function clonar(nombre: string, hacer: (Model) -> ()): Model
	local molde = moldes[nombre]
	if molde then
		return molde:Clone()
	end
	local nuevo = Instance.new("Model")
	nuevo.Name = nombre
	hacer(nuevo)
	nuevo.WorldPivot = CFrame.new()
	moldes[nombre] = nuevo
	return nuevo:Clone()
end

-- Coloca una copia del molde escalada por `k`, girada al azar, con el pie en `pie`.
local function plantar(m: Model, rng: Random, pie: Vector3, k: number, padre: Instance): Model
	m:ScaleTo(k)
	m:PivotTo(CFrame.new(pie) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m.Parent = padre
	return m
end

local ALTO_MOLDE_CEIBA = 100

-- Ceiba copiada del árbol 3D: una piel de triángulos con la silueta real (raíces tablares,
-- tronco, ramas y masas de la copa) y el color del original en cada cara, bolas de relleno
-- dentro de la copa para que no se vea hueca, y lianas colgando.
local function moldeCeiba(m: Model)
	local k = ALTO_MOLDE_CEIBA
	local rng = Random.new(11)
	Triangulos.construir(
		m,
		Datos.Ceiba,
		function(p)
			return p * k
		end,
		2.2,
		function(color, _normal)
			-- verde = hojas o musgo; pardo = corteza
			if color.G > color.R * 1.05 and color.G > color.B * 1.2 then
				return color, if color.G > 0.42 then M.LeafyGrass else M.Grass
			end
			return color, M.Wood
		end,
		{ consulta = false }
	)

	local h = Datos.Ceiba.hojas
	local masas: { { p: Vector3, r: number } } = {}
	for i = 1, #h, 7 do
		local p, r = Vector3.new(h[i], h[i + 1], h[i + 2]) * k, h[i + 3] * k
		table.insert(masas, { p = p, r = r })
		Kit.parte(
			m,
			CFrame.new(p),
			Vector3.one * r * 2,
			Color3.fromRGB(h[i + 4], h[i + 5], h[i + 6]),
			M.LeafyGrass,
			{ forma = BOLA, colision = false, consulta = false }
		)
	end
	for _ = 1, 14 do
		local masa = masas[rng:NextInteger(1, #masas)]
		local a, r = rng:NextNumber(0, math.pi * 2), masa.r * rng:NextNumber(0.5, 1.1)
		local arriba = masa.p + Vector3.new(math.cos(a) * r, -masa.r * 0.4, math.sin(a) * r)
		local largo = math.min(arriba.Y - k * 0.1, k * rng:NextNumber(0.1, 0.3))
		if largo > 4 then
			Kit.cilindro(m, arriba, arriba - Vector3.new(0, largo, 0), 0.45, LIANA, M.Grass, Kit.FOLLAJE)
		end
	end
end

function Vegetacion.ceiba(rng: Random, suelo: Vector3, padre: Instance): Model
	local alto = rng:NextNumber(V.ALTO_CEIBA[1], V.ALTO_CEIBA[2])
	-- las raíces se hunden un poco para que no asomen por debajo en las laderas
	return plantar(
		clonar("Ceiba", moldeCeiba),
		rng,
		suelo - Vector3.new(0, alto * 0.03, 0),
		alto / ALTO_MOLDE_CEIBA,
		padre
	)
end

function Vegetacion.arbol(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("Arbol", padre)
	local alto = rng:NextNumber(20, 34)
	local d = rng:NextNumber(1.6, 2.8)
	local corteza = Kit.variar(Kit.elegir(rng, CORTEZA), rng, 0.05)
	local cima = suelo + Vector3.new(rng:NextNumber(-3, 3), alto, rng:NextNumber(-3, 3))
	Kit.cilindro(m, suelo - Vector3.new(0, 1.5, 0), cima, d, corteza, M.Wood)

	local n = rng:NextInteger(4, 6)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(3, 7.5)
		local punta = cima + Vector3.new(math.cos(a) * r, rng:NextNumber(-5, 2), math.sin(a) * r)
		if i <= 3 then
			Kit.cilindro(m, suelo:Lerp(cima, rng:NextNumber(0.6, 0.8)), punta, d * 0.4, corteza, M.Wood, Kit.COPA)
		end
		local dh = rng:NextNumber(8, 14)
		Kit.parte(
			m,
			CFrame.new(punta + Vector3.new(0, dh * 0.15, 0)),
			Vector3.one * dh,
			Kit.variar(Kit.elegir(rng, HOJAS), rng, 0.05),
			if rng:NextNumber() < 0.5 then M.Grass else M.LeafyGrass,
			{ forma = BOLA, colision = false, consulta = false }
		)
	end
	if rng:NextNumber() < 0.45 then
		lianas(m, rng, cima, 6, rng:NextInteger(2, 5))
	end
	return crecer(m, suelo, alto, V.ALTO_ARBOL, rng)
end

function Vegetacion.palmera(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("Palmera", padre)
	local alto = rng:NextNumber(16, 30)
	local curva = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(2, 8)
	local c1 = Kit.variar(Color3.fromRGB(110, 94, 70), rng, 0.05)
	local c2 = Kit.variar(Color3.fromRGB(92, 78, 58), rng, 0.05)
	local prev = suelo - Vector3.new(0, 1, 0)
	local segmentos = 6
	for i = 1, segmentos do
		local t = i / segmentos
		local p = suelo + Vector3.new(0, alto * t, 0) + curva * (t * t)
		Kit.cilindro(m, prev, p, 1.75 - 0.6 * t, if i % 2 == 0 then c1 else c2, M.Wood)
		prev = p
	end
	local cima = prev
	for _ = 1, rng:NextInteger(2, 4) do
		local o = Vector3.new(rng:NextNumber(-0.8, 0.8), -rng:NextNumber(0.6, 1.2), rng:NextNumber(-0.8, 0.8))
		Kit.parte(
			m,
			CFrame.new(cima + o),
			Vector3.one * 1.1,
			Color3.fromRGB(86, 66, 40),
			M.Wood,
			{ forma = BOLA, colision = false, consulta = false, sombra = false }
		)
	end
	local n = rng:NextInteger(8, 11)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dirH = Vector3.new(math.cos(a), 0, math.sin(a))
		local p1 = cima + dirH * rng:NextNumber(5, 7) + Vector3.new(0, rng:NextNumber(0.5, 2.4), 0)
		local p2 = p1 + dirH * rng:NextNumber(5, 7) - Vector3.new(0, rng:NextNumber(3, 5.5), 0)
		local color = Kit.variar(Kit.elegir(rng, HOJAS_PALMA), rng, 0.05)
		Kit.viga(m, cima, p1, 2.6, 0.2, color, M.Grass, Kit.COPA)
		Kit.viga(m, p1, p2, 2.1, 0.2, color, M.Grass, Kit.COPA)
	end
	return crecer(m, suelo, alto, V.ALTO_PALMERA, rng)
end

function Vegetacion.seco(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("ArbolSeco", padre)
	local alto = rng:NextNumber(14, 26)
	local corteza = Kit.variar(Color3.fromRGB(104, 96, 84), rng, 0.05)
	local cima = suelo + Vector3.new(rng:NextNumber(-2, 2), alto, rng:NextNumber(-2, 2))
	local d = rng:NextNumber(1.4, 2.4)
	Kit.cilindro(m, suelo - Vector3.new(0, 1, 0), cima, d, corteza, M.Wood)
	for _ = 1, rng:NextInteger(3, 5) do
		local desde = suelo:Lerp(cima, rng:NextNumber(0.45, 0.95))
		local a = rng:NextNumber(0, math.pi * 2)
		local punta = desde + Vector3.new(math.cos(a), rng:NextNumber(0.3, 1), math.sin(a)) * rng:NextNumber(4, 9)
		Kit.cilindro(m, desde, punta, d * 0.35, corteza, M.Wood, Kit.COPA)
		if rng:NextNumber() < 0.5 then
			local rama = punta + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(1, 3), rng:NextNumber(-3, 3))
			Kit.cilindro(m, punta, rama, d * 0.2, corteza, M.Wood, Kit.FOLLAJE)
		end
		if rng:NextNumber() < 0.6 then
			Kit.parte(m, CFrame.new(desde), Vector3.one * rng:NextNumber(1.2, 2.2), MUSGO, M.Grass, {
				forma = BOLA,
				colision = false,
				consulta = false,
				sombra = false,
			})
		end
	end
	lianas(m, rng, cima - Vector3.new(0, 2, 0), 4, rng:NextInteger(1, 4))
	return crecer(m, suelo, alto, V.ALTO_SECO, rng)
end

function Vegetacion.helecho(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("Helecho", padre)
	local escala = rng:NextNumber(0.8, 1.7)
	local color = Kit.variar(Kit.elegir(rng, HOJAS_CLARAS), rng, 0.05)
	local base = suelo + Vector3.new(0, 0.2, 0)
	local n = rng:NextInteger(7, 10)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p1 = base + dir * rng:NextNumber(1.4, 2.4) * escala + Vector3.new(0, rng:NextNumber(1.2, 2.2) * escala, 0)
		local p2 = p1 + dir * rng:NextNumber(1.4, 2.4) * escala - Vector3.new(0, 0.9 * escala, 0)
		Kit.viga(m, base, p1, 0.95 * escala, 0.12, color, M.Grass, Kit.FOLLAJE)
		Kit.viga(m, p1, p2, 0.75 * escala, 0.12, color, M.Grass, Kit.FOLLAJE)
	end
	return m
end

function Vegetacion.arbusto(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("Arbusto", padre)
	for _ = 1, rng:NextInteger(2, 4) do
		local dh = rng:NextNumber(3, 6.5)
		local o = Vector3.new(rng:NextNumber(-2, 2), dh * 0.3, rng:NextNumber(-2, 2))
		Kit.parte(
			m,
			CFrame.new(suelo + o),
			Vector3.one * dh,
			Kit.variar(Kit.elegir(rng, HOJAS), rng, 0.05),
			M.LeafyGrass,
			{ forma = BOLA, colision = false, consulta = false, sombra = false }
		)
	end
	return m
end

-- Plantas de hoja grande (tipo oreja de elefante) y a veces heliconias rojas.
function Vegetacion.hojaGrande(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("HojaGrande", padre)
	local color = Kit.variar(Color3.fromRGB(44, 96, 48), rng, 0.05)
	local tallo = Color3.fromRGB(62, 96, 44)
	for _ = 1, rng:NextInteger(3, 5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local alto = rng:NextNumber(2.5, 5)
		local p1 = suelo + dir * rng:NextNumber(0.5, 1.5) + Vector3.new(0, alto, 0)
		Kit.cilindro(m, suelo, p1, 0.25, tallo, M.Grass, Kit.FOLLAJE)
		local p2 = p1 + dir * rng:NextNumber(3.5, 5.5) - Vector3.new(0, rng:NextNumber(0.5, 2), 0)
		Kit.viga(m, p1, p2, rng:NextNumber(2.8, 3.8), 0.15, color, M.Grass, Kit.FOLLAJE)
	end
	if rng:NextNumber() < 0.3 then
		local flor = Kit.elegir(rng, FLOR)
		for _ = 1, rng:NextInteger(2, 4) do
			local p = suelo + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(2.5, 4.5), rng:NextNumber(-1, 1))
			Kit.parte(
				m,
				CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), 0),
				Vector3.new(0.5, 1.6, 0.8),
				flor,
				M.SmoothPlastic,
				{ cuna = true, colision = false, consulta = false, sombra = false }
			)
		end
	end
	return m
end

local MUSGO_ROCA = Color3.fromRGB(62, 84, 48)

-- Color de la textura original; las caras que miran al cielo crían musgo.
local function pintarRoca(color: Color3, normal: Vector3): (Color3, Enum.Material)
	if normal.Y > 0.82 then
		return color:Lerp(MUSGO_ROCA, 0.7), M.LeafyGrass
	elseif normal.Y > 0.55 then
		return color:Lerp(MUSGO_ROCA, 0.3), M.Rock
	end
	return color, if normal.Y < -0.3 then M.Slate else M.Rock
end

local ANCHO_MOLDE_ROCA = 12

-- Roca suelta: la silueta del peñasco con pocos triángulos. Tres variantes estiradas distinto.
local function moldeRoca(variante: number): (Model) -> ()
	return function(m: Model)
		local rng = Random.new(100 + variante)
		local k = ANCHO_MOLDE_ROCA
		local estirar = Vector3.new(rng:NextNumber(0.8, 1.15), rng:NextNumber(0.75, 1.3), rng:NextNumber(0.8, 1.15)) * k
		Triangulos.construir(m, Datos.Roca, function(p)
			return p * estirar
		end, 1.4, pintarRoca)
	end
end

-- Peñasco copiado del modelo 3D: la piedra con sus picos (triángulos con el color de la textura),
-- los troncos y raíces que la recorren y una mata por cada masa de hojas del original.
local function moldePenasco(m: Model)
	local rng = Random.new(23)
	Triangulos.construir(m, Datos.Penasco, function(p)
		return p
	end, 1.5, pintarRoca)
	local t = Datos.Penasco.troncos
	for i = 1, #t, 7 do
		Kit.cilindro(
			m,
			Vector3.new(t[i], t[i + 1], t[i + 2]),
			Vector3.new(t[i + 3], t[i + 4], t[i + 5]),
			t[i + 6] * 2,
			Kit.variar(Kit.elegir(rng, CORTEZA), rng, 0.05),
			M.Wood,
			Kit.FOLLAJE
		)
	end
	local h = Datos.Penasco.hojas
	for i = 1, #h, 4 do
		local centro, r = Vector3.new(h[i], h[i + 1], h[i + 2]), h[i + 3]
		-- cada masa de hojas: una bola grande y dos menores alrededor para romper la esfera
		for j = 1, 3 do
			local rj = if j == 1 then r else r * rng:NextNumber(0.5, 0.7)
			local o = if j == 1
				then Vector3.zero
				else Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 0.8), rng:NextNumber(-1, 1)) * r * 0.8
			Kit.parte(
				m,
				CFrame.new(centro + o),
				Vector3.one * rj * 2,
				Kit.variar(Kit.elegir(rng, HOJAS), rng, 0.06),
				if rng:NextNumber() < 0.5 then M.Grass else M.LeafyGrass,
				{ forma = BOLA, colision = false, consulta = false, sombra = false }
			)
		end
	end
end

function Vegetacion.roca(rng: Random, suelo: Vector3, padre: Instance): Model
	local variante = rng:NextInteger(1, 3)
	local ancho = rng:NextNumber(7, 16)
	local m = clonar("Roca" .. variante, moldeRoca(variante))
	m.Name = "Roca"
	-- hundida en el suelo: tapa la base y evita que un lado quede en el aire en las laderas
	local hundir = ancho * Datos.Roca.alto * 0.16
	return plantar(m, rng, suelo - Vector3.new(0, hundir, 0), ancho / ANCHO_MOLDE_ROCA, padre)
end

-- Peñasco con árboles encima: hito del paisaje. Necesita unos 20 studs libres alrededor.
function Vegetacion.rocaGrande(rng: Random, suelo: Vector3, padre: Instance): Model
	local k = rng:NextNumber(24, 40) / Datos.Penasco.ancho
	local m = clonar("Penasco", moldePenasco)
	return plantar(m, rng, suelo - Vector3.new(0, Datos.Penasco.alto * k * 0.2, 0), k, padre)
end

function Vegetacion.tronco(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("TroncoCaido", padre)
	local a = rng:NextNumber(0, math.pi * 2)
	local largo = rng:NextNumber(14, 24)
	local d = rng:NextNumber(2.4, 3.6)
	local dir = Vector3.new(math.cos(a), rng:NextNumber(-0.05, 0.05), math.sin(a))
	local centroT = suelo + Vector3.new(0, d * 0.3, 0)
	local corteza = Kit.variar(Kit.elegir(rng, CORTEZA), rng, 0.05)
	Kit.cilindro(m, centroT - dir * largo / 2, centroT + dir * largo / 2, d, corteza, M.Wood)
	for _ = 1, rng:NextInteger(2, 4) do
		local p = centroT + dir * rng:NextNumber(-largo / 2, largo / 2) + Vector3.new(0, d * 0.45, 0)
		Kit.parte(m, CFrame.new(p), Vector3.one * rng:NextNumber(1.2, 2.4), MUSGO, M.Grass, {
			forma = BOLA,
			colision = false,
			consulta = false,
			sombra = false,
		})
	end
	return m
end

return Vegetacion
