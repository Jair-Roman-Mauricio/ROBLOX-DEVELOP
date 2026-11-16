--!strict
--[[
	Vegetación de selva construida con partes. Cada función recibe el punto del suelo y
	devuelve un Model. Las copas no colisionan ni reciben raycasts para no estorbar.
	Las rocas usan el modelo importado RocaSelva cuando sus mallas cargan (ver Mallas).
]]

local Kit = require(script.Parent.Kit)
local Mallas = require(script.Parent.Mallas)

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
function Vegetacion.ceiba(rng: Random, suelo: Vector3, padre: Instance): Model
	local m = Kit.modelo("Ceiba", padre)
	local alto = rng:NextNumber(50, 72)
	local d = rng:NextNumber(5.5, 8)
	local corteza = Kit.variar(Kit.elegir(rng, CORTEZA), rng, 0.04)
	local cima = suelo + Vector3.new(rng:NextNumber(-2, 2), alto, rng:NextNumber(-2, 2))
	Kit.cilindro(m, suelo - Vector3.new(0, 3, 0), cima, d, corteza, M.Wood)
	Kit.cilindro(m, suelo - Vector3.new(0, 3, 0), suelo:Lerp(cima, 0.25), d * 1.35, corteza, M.Wood)

	local base = CFrame.new(suelo)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local largo, altoR = rng:NextNumber(7, 12), rng:NextNumber(8, 14)
		local cf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, altoR / 2 - 1, -(d / 2 + largo / 2 - 1.5))
		Kit.parte(m, cf, Vector3.new(1.3, altoR, largo), corteza, M.Wood, { cuna = true })
	end

	for _ = 1, rng:NextInteger(6, 8) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 18)
		local y = rng:NextNumber(-8, 3)
		local punta = cima + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		Kit.cilindro(m, suelo:Lerp(cima, 0.82), punta, d * 0.32, corteza, M.Wood)
		local dh = rng:NextNumber(15, 24)
		Kit.parte(
			m,
			CFrame.new(punta + Vector3.new(0, dh * 0.2, 0)),
			Vector3.one * dh,
			Kit.variar(Kit.elegir(rng, HOJAS), rng, 0.04),
			if rng:NextNumber() < 0.5 then M.Grass else M.LeafyGrass,
			{ forma = BOLA, colision = false, consulta = false }
		)
	end
	Kit.parte(
		m,
		CFrame.new(cima + Vector3.new(0, 6, 0)),
		Vector3.one * rng:NextNumber(20, 26),
		Kit.elegir(rng, HOJAS),
		M.Grass,
		{ forma = BOLA, colision = false, consulta = false }
	)
	lianas(m, rng, cima - Vector3.new(0, 4, 0), 16, rng:NextInteger(6, 10))
	return m
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
	return m
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
	return m
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
	return m
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

-- Roca de partes: la que se usa cuando el modelo RocaSelva no existe o no carga.
local function rocaPartes(rng: Random, suelo: Vector3, padre: Instance, escala: number): Model
	local m = Kit.modelo("Roca", padre)
	local color = Kit.variar(Color3.fromRGB(96, 100, 92), rng, 0.06)
	for _ = 1, rng:NextInteger(1, 3) do
		local tam = Vector3.new(rng:NextNumber(3, 9), rng:NextNumber(2, 6), rng:NextNumber(3, 9)) * escala
		local o = Vector3.new(rng:NextNumber(-3, 3) * escala, tam.Y * 0.2, rng:NextNumber(-3, 3) * escala)
		local cf = CFrame.new(suelo + o)
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
		Kit.parte(m, cf, tam, color, if rng:NextNumber() < 0.5 then M.Rock else M.Slate)
		if rng:NextNumber() < 0.5 then
			Kit.parte(
				m,
				cf * CFrame.new(0, tam.Y / 2, 0),
				Vector3.new(tam.X * 0.8, 0.4, tam.Z * 0.8),
				MUSGO,
				M.LeafyGrass,
				Kit.FOLLAJE
			)
		end
	end
	return m
end

-- Medidas del molde RocaSelva: base de la piedra respecto al pivote y lado mayor en planta.
type MedidasRoca = { base: CFrame, ancho: number, alto: number }
local medidasRoca: MedidasRoca? = nil

local function medirRoca(molde: Model): MedidasRoca?
	if medidasRoca then
		return medidasRoca
	end
	local piedra = molde:FindFirstChild("Roca", true)
	if not piedra or not piedra:IsA("BasePart") then
		warn("[Selva] RocaSelva sin MeshPart 'Roca'; se usan rocas de partes")
		return nil
	end
	-- caja alineada con el mundo de la piedra, aunque el importador la haya dejado girada
	local cf, t = piedra.CFrame, piedra.Size / 2
	local r, u, f = cf.RightVector, cf.UpVector, cf.LookVector
	local mitad = Vector3.new(
		math.abs(r.X) * t.X + math.abs(u.X) * t.Y + math.abs(f.X) * t.Z,
		math.abs(r.Y) * t.X + math.abs(u.Y) * t.Y + math.abs(f.Y) * t.Z,
		math.abs(r.Z) * t.X + math.abs(u.Z) * t.Y + math.abs(f.Z) * t.Z
	)
	local pie = cf.Position - Vector3.new(0, mitad.Y, 0)
	local medidas: MedidasRoca = {
		base = molde:GetPivot():ToObjectSpace(CFrame.new(pie)),
		ancho = math.max(mitad.X, mitad.Z) * 2,
		alto = mitad.Y * 2,
	}
	medidasRoca = medidas
	return medidas
end

-- Copia del modelo RocaSelva con `ancho` studs de lado mayor. `vegetacion` conserva los
-- árboles y raíces que crecen sobre la piedra; sin ella queda solo la piedra (más barata).
local function rocaMalla(rng: Random, suelo: Vector3, padre: Instance, ancho: number, vegetacion: boolean): Model?
	local molde = Mallas.obtener("RocaSelva")
	local medidas = if molde then medirRoca(molde) else nil
	if not molde or not medidas then
		return nil
	end
	local m = molde:Clone()
	m.Name = "Roca"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local piedra = d.Name == "Roca"
			if not piedra and not vegetacion then
				d:Destroy()
				continue
			end
			d.Anchored = true
			d.CanTouch = false
			d.CanCollide = piedra
			d.CanQuery = piedra
			d.CastShadow = d.Name ~= "Hojas"
		end
	end
	local k = ancho / medidas.ancho
	m:ScaleTo(k)
	-- hundida en el suelo: tapa la base y evita que un lado quede en el aire en las laderas
	local hundir = medidas.alto * k * (if vegetacion then 0.2 else 0.16)
	local destino = CFrame.new(suelo - Vector3.new(0, hundir, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = medidas.base.Rotation + medidas.base.Position * k
	m:PivotTo(destino * base:Inverse())
	m.Parent = padre
	return m
end

function Vegetacion.roca(rng: Random, suelo: Vector3, padre: Instance): Model
	return rocaMalla(rng, suelo, padre, rng:NextNumber(7, 15), false) or rocaPartes(rng, suelo, padre, 1)
end

-- Peñasco con árboles encima: hito del paisaje. Necesita unos 20 studs libres alrededor.
function Vegetacion.rocaGrande(rng: Random, suelo: Vector3, padre: Instance): Model
	return rocaMalla(rng, suelo, padre, rng:NextNumber(22, 36), true) or rocaPartes(rng, suelo, padre, 2.2)
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
