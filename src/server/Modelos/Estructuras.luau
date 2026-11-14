--!strict
--[[
	Estructuras del mapa y del lobby construidas con partes: chozas sobre pilotes, malocas,
	antorchas, puentes, restos del helicóptero, portada de la salida, etc.
	Convención: `cf` está en el suelo y el frente del modelo mira hacia -Z.
	Los pueblos son fantasmas: abandonados, con tablas rotas, pero sin rastro de sus habitantes.
]]

local Kit = require(script.Parent.Kit)

local M = Enum.Material
local BOLA = Enum.PartType.Ball
local CIL = Enum.PartType.Cylinder

local MADERA = Color3.fromRGB(96, 74, 52)
local TABLA = Color3.fromRGB(118, 92, 64)
local PAJA = Color3.fromRGB(150, 124, 78)
local PIEDRA = Color3.fromRGB(92, 96, 92)
local FUEGO = Color3.fromRGB(255, 150, 60)
local LUZ_FUEGO = Color3.fromRGB(255, 160, 90)
local GLIFO = Color3.fromRGB(80, 225, 205)

local Estructuras = {}

local function punto(cf: CFrame, x: number, y: number, z: number): Vector3
	return cf:PointToWorldSpace(Vector3.new(x, y, z))
end

-- Choza sobre pilotes (palafito) con techo de paja a dos aguas. Algunas tablas faltan.
function Estructuras.choza(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Choza", padre)
	local W, D = rng:NextNumber(12, 16), rng:NextNumber(10, 13)
	local piso = rng:NextNumber(3.5, 5.5)
	local pared = 6.5
	cf *= CFrame.Angles(rng:NextNumber(-0.03, 0.03), 0, rng:NextNumber(-0.04, 0.04))
	local madera = Kit.variar(MADERA, rng, 0.05)
	local tabla = Kit.variar(TABLA, rng, 0.06)
	local paja = Kit.variar(PAJA, rng, 0.05)

	for _, x in { -W / 2 + 0.8, 0, W / 2 - 0.8 } do
		for _, z in { -D / 2 + 0.8, D / 2 - 0.8 } do
			Kit.cilindro(m, punto(cf, x, -2, z), punto(cf, x, piso, z), 0.9, madera, M.Wood)
		end
	end
	for _, z in { -D / 2 + 0.8, D / 2 - 0.8 } do
		Kit.parte(m, cf * CFrame.new(0, piso - 0.6, z), Vector3.new(W, 0.8, 0.8), madera, M.Wood)
	end
	local nt = math.floor(W / 1.25)
	for i = 0, nt - 1 do
		if rng:NextNumber() > 0.08 then
			local x = -W / 2 + 0.62 + i * 1.25
			Kit.parte(
				m,
				cf * CFrame.new(x, piso, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.03, 0.03)),
				Vector3.new(1.15, 0.35, D),
				Kit.variar(tabla, rng, 0.04),
				M.WoodPlanks
			)
		end
	end

	-- postes de esquina
	for _, x in { -W / 2 + 0.3, W / 2 - 0.3 } do
		for _, z in { -D / 2 + 0.3, D / 2 - 0.3 } do
			Kit.parte(m, cf * CFrame.new(x, piso + pared / 2, z), Vector3.new(0.7, pared, 0.7), madera, M.Wood)
		end
	end

	-- paredes de tablas verticales con huecos, ventana lateral y puerta al frente
	local function tablon(c: CFrame, ancho: number, alto: number)
		Kit.parte(
			m,
			c * CFrame.new(0, alto / 2, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.04, 0.04)),
			Vector3.new(ancho, alto, 0.3),
			Kit.variar(tabla, rng, 0.05),
			M.WoodPlanks
		)
	end
	local ventana = rng:NextInteger(1, 2)
	for _, lado in { -1, 1 } do
		-- frente y fondo
		local z = lado * (D / 2 - 0.3)
		local x = -W / 2 + 1
		while x < W / 2 - 0.6 do
			local puerta = lado == -1 and math.abs(x) < 1.7
			if not puerta and rng:NextNumber() > 0.12 then
				local alto = if rng:NextNumber() < 0.15 then pared * rng:NextNumber(0.4, 0.8) else pared
				tablon(cf * CFrame.new(x, piso + 0.2, z), 1.05, alto)
			end
			x += 1.15
		end
		-- laterales
		local xl = lado * (W / 2 - 0.3)
		local zl = -D / 2 + 1
		while zl < D / 2 - 0.6 do
			local hueco = (lado == -1 and ventana == 1 or lado == 1 and ventana == 2) and math.abs(zl) < 1.6
			if rng:NextNumber() > 0.12 then
				if hueco then
					tablon(cf * CFrame.new(xl, piso + 0.2, zl) * CFrame.Angles(0, math.pi / 2, 0), 1.05, 2.4)
				else
					local alto = if rng:NextNumber() < 0.15 then pared * rng:NextNumber(0.4, 0.8) else pared
					tablon(cf * CFrame.new(xl, piso + 0.2, zl) * CFrame.Angles(0, math.pi / 2, 0), 1.05, alto)
				end
			end
			zl += 1.15
		end
	end

	-- techo a dos aguas; a veces le falta un tramo
	local subida = D * 0.38
	local angulo = math.atan(subida / (D / 2))
	local largo = math.sqrt((D / 2) ^ 2 + subida ^ 2) + 1.8
	local tope = piso + pared
	local tramoRoto = if rng:NextNumber() < 0.45 then rng:NextInteger(1, 6) else 0
	local anchoTramo = (W + 2.4) / 3
	local k = 0
	for _, lado in { -1, 1 } do
		for t = 0, 2 do
			k += 1
			if k ~= tramoRoto then
				local x = -(W + 2.4) / 2 + anchoTramo * (t + 0.5)
				Kit.parte(
					m,
					cf
						* CFrame.new(x, tope + subida / 2, lado * D / 4)
						* CFrame.Angles(lado * angulo + rng:NextNumber(-0.03, 0.03), 0, 0),
					Vector3.new(anchoTramo + 0.05, 0.7, largo),
					Kit.variar(paja, rng, 0.04),
					M.Grass
				)
			end
		end
	end
	Kit.cilindro(
		m,
		punto(cf, -W / 2 - 1.2, tope + subida, 0),
		punto(cf, W / 2 + 1.2, tope + subida, 0),
		0.6,
		madera,
		M.Wood
	)

	-- escalones hasta la puerta
	local n = math.max(2, math.ceil(piso / 1.1))
	for e = 1, n do
		local y = e * piso / n
		local z = -D / 2 - 0.6 - (n - e) * 1.1
		Kit.parte(
			m,
			cf * CFrame.new(0, y - 0.25, z),
			Vector3.new(3, 0.5, 1.2),
			Kit.variar(tabla, rng, 0.05),
			M.WoodPlanks
		)
	end
	Kit.cilindro(m, punto(cf, -1.4, -1, -D / 2 - n * 1.1), punto(cf, -1.4, piso, -D / 2 - 0.4), 0.35, madera, M.Wood)
	Kit.cilindro(m, punto(cf, 1.4, -1, -D / 2 - n * 1.1), punto(cf, 1.4, piso, -D / 2 - 0.4), 0.35, madera, M.Wood)
	return m
end

-- Maloca: casa comunal redonda con techo cónico de paja.
function Estructuras.maloca(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Maloca", padre)
	local R = rng:NextNumber(9, 11)
	local pared = 6.5
	local madera = Kit.variar(MADERA, rng, 0.05)
	local paja = Kit.variar(PAJA, rng, 0.05)
	Kit.parte(
		m,
		cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(1, R * 2 + 1, R * 2 + 1),
		Kit.variar(TABLA, rng, 0.05),
		M.WoodPlanks,
		{ forma = CIL }
	)
	local postes = 12
	local prev: Vector3? = nil
	for i = 0, postes do
		local a = i / postes * math.pi * 2
		local p = punto(cf, math.cos(a) * R, 0, math.sin(a) * R)
		if i < postes then
			Kit.cilindro(m, p - Vector3.new(0, 0.5, 0), p + Vector3.new(0, pared, 0), 0.7, madera, M.Wood)
		end
		-- barandas bajas, abiertas al frente (puerta) y con tramos caídos
		local frente = math.abs(math.sin(a) + 1) < 0.3
		if prev and not frente and rng:NextNumber() > 0.2 then
			for _, y in { 1.4, 3 } do
				Kit.cilindro(m, prev + Vector3.new(0, y, 0), p + Vector3.new(0, y, 0), 0.35, madera, M.Wood)
			end
		end
		prev = p
	end
	local cono = 18
	local largo = R + 3
	local alto = 9
	for i = 1, cono do
		if rng:NextNumber() > 0.06 then
			local a = i / cono * math.pi * 2
			Kit.parte(
				m,
				cf * CFrame.Angles(0, a, 0) * CFrame.new(0, pared + alto / 2, -largo / 2),
				Vector3.new(2 * math.pi * largo / cono * 1.25, alto, largo),
				Kit.variar(paja, rng, 0.04),
				M.Grass,
				{ cuna = true }
			)
		end
	end
	Kit.cilindro(m, punto(cf, 0, 0, 0), punto(cf, 0, pared + alto + 2, 0), 0.9, madera, M.Wood)
	Estructuras.fogon(rng, cf * CFrame.new(0, 0.8, 0), m, false)
	return m
end

-- Círculo de piedras con brasas. Si `encendido`, tiene fuego y luz.
function Estructuras.fogon(rng: Random, cf: CFrame, padre: Instance, encendido: boolean): Model
	local m = Kit.modelo("Fogon", padre)
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		Kit.parte(
			m,
			cf * CFrame.new(math.cos(a) * 2.2, 0.3, math.sin(a) * 2.2) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Vector3.new(1.2, 0.8, 0.9),
			Kit.variar(PIEDRA, rng, 0.06),
			M.Slate
		)
	end
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		Kit.cilindro(
			m,
			punto(cf, math.cos(a) * 1.6, 0.2, math.sin(a) * 1.6),
			punto(cf, -math.cos(a) * 0.3, 1, -math.sin(a) * 0.3),
			0.5,
			Color3.fromRGB(40, 32, 26),
			M.Wood
		)
	end
	local brasas = Kit.parte(
		m,
		cf * CFrame.new(0, 0.3, 0),
		Vector3.new(2, 0.3, 2),
		if encendido then FUEGO else Color3.fromRGB(50, 44, 40),
		if encendido then M.Neon else M.Basalt,
		{ colision = false }
	)
	if encendido then
		local fuego = Instance.new("Fire")
		fuego.Size = 4
		fuego.Heat = 7
		fuego.Color = Color3.fromRGB(255, 140, 50)
		fuego.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fuego.Parent = brasas
		Kit.luz(brasas, LUZ_FUEGO, 32, 2.4, true)
		Kit.etiquetar(brasas, "Antorcha")
	end
	return m
end

function Estructuras.antorcha(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Antorcha", padre)
	local alto = rng:NextNumber(6, 7.5)
	Kit.cilindro(m, punto(cf, 0, -1, 0), punto(cf, 0, alto, 0), 0.45, MADERA, M.Wood)
	Kit.parte(m, cf * CFrame.new(0, alto - 0.6, 0), Vector3.new(0.8, 0.6, 0.8), Color3.fromRGB(60, 46, 34), M.Fabric)
	local llama = Kit.parte(
		m,
		cf * CFrame.new(0, alto + 0.2, 0),
		Vector3.one * 0.9,
		FUEGO,
		M.Neon,
		{ forma = BOLA, colision = false, consulta = false, sombra = false, nombre = "Llama" }
	)
	local fuego = Instance.new("Fire")
	fuego.Size = 2.2
	fuego.Heat = 5
	fuego.Color = Color3.fromRGB(255, 140, 50)
	fuego.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fuego.Parent = llama
	Kit.luz(llama, LUZ_FUEGO, 24, 1.9)
	Kit.etiquetar(llama, "Antorcha")
	return m
end

function Estructuras.caja(rng: Random, cf: CFrame, padre: Instance, tam: number?): BasePart
	local t = tam or rng:NextNumber(2.4, 3.4)
	local color = Kit.variar(Color3.fromRGB(122, 94, 62), rng, 0.06)
	local caja = Kit.parte(padre, cf * CFrame.new(0, t / 2, 0), Vector3.one * t, color, M.WoodPlanks)
	local oscuro = Color3.fromRGB(70, 54, 40)
	for _, y in { -t / 2 + 0.25, t / 2 - 0.25 } do
		Kit.parte(
			padre,
			caja.CFrame * CFrame.new(0, y, 0),
			Vector3.new(t + 0.1, 0.35, t + 0.1),
			oscuro,
			M.Wood,
			Kit.FOLLAJE
		)
	end
	return caja
end

function Estructuras.pilaCajas(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Cajas", padre)
	for i = 1, rng:NextInteger(2, 5) do
		local y = if i > 3 then 3 else 0
		Estructuras.caja(
			rng,
			cf * CFrame.new(rng:NextNumber(-3, 3), y, rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			m
		)
	end
	return m
end

function Estructuras.troncosApilados(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Lena", padre)
	local largo = rng:NextNumber(6, 9)
	local d = 1.3
	for fila = 0, 2 do
		for i = 0, 2 - fila do
			local x = (i - (2 - fila) / 2) * d
			local y = 0.6 + fila * d * 0.85
			Kit.cilindro(
				m,
				punto(cf, x, y, -largo / 2),
				punto(cf, x, y, largo / 2),
				d,
				Kit.variar(Color3.fromRGB(110, 86, 60), rng, 0.06),
				M.Wood
			)
		end
	end
	return m
end

-- Valla rústica entre dos puntos del suelo; algunos travesaños rotos.
function Estructuras.valla(rng: Random, desde: Vector3, hasta: Vector3, padre: Instance): Model
	local m = Kit.modelo("Valla", padre)
	local n = math.max(1, math.floor((hasta - desde).Magnitude / 3.5))
	local prev: Vector3? = nil
	for i = 0, n do
		local p = desde:Lerp(hasta, i / n)
		local alto = rng:NextNumber(3, 3.8)
		Kit.cilindro(m, p - Vector3.new(0, 1, 0), p + Vector3.new(0, alto, 0), 0.4, MADERA, M.Wood)
		if prev and rng:NextNumber() > 0.2 then
			for _, y in { 1.2, 2.6 } do
				if rng:NextNumber() > 0.15 then
					Kit.cilindro(
						m,
						prev + Vector3.new(0, y, 0),
						p + Vector3.new(0, y + rng:NextNumber(-0.3, 0.3), 0),
						0.3,
						MADERA,
						M.Wood
					)
				end
			end
		end
		prev = p
	end
	return m
end

-- Puente colgante de tablones entre dos orillas, con pilotes en el agua y cuerdas.
function Estructuras.puente(rng: Random, desde: Vector3, hasta: Vector3, nivelAgua: number, padre: Instance): Model
	local m = Kit.modelo("Puente", padre)
	desde += Vector3.new(0, 0.6, 0)
	hasta += Vector3.new(0, 0.6, 0)
	local dir = hasta - desde
	local largo = dir.Magnitude
	local plano = Vector3.new(dir.X, 0, dir.Z).Unit
	local lado = Vector3.new(-plano.Z, 0, plano.X)
	local ancho = 7
	local function cubierta(t: number): Vector3
		return desde:Lerp(hasta, t) + Vector3.new(0, 2.2 * math.sin(math.pi * t), 0)
	end
	-- largueros continuos: garantizan el paso aunque falten tablones
	for _, s in { -1, 1 } do
		local prev = cubierta(0)
		for k = 1, 8 do
			local p = cubierta(k / 8)
			Kit.viga(
				m,
				prev + lado * s * 2.4 - Vector3.new(0, 0.5, 0),
				p + lado * s * 2.4 - Vector3.new(0, 0.5, 0),
				0.9,
				0.7,
				MADERA,
				M.Wood
			)
			prev = p
		end
	end
	local n = math.floor(largo / 1.3)
	for i = 1, n do
		if rng:NextNumber() > 0.06 then
			local t = (i - 0.5) / n
			local p = cubierta(t)
			local tangente = cubierta(math.min(1, t + 0.01)) - cubierta(math.max(0, t - 0.01))
			Kit.parte(
				m,
				CFrame.lookAt(p, p + tangente)
					* CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.03, 0.03)),
				Vector3.new(ancho, 0.4, 1.15),
				Kit.variar(TABLA, rng, 0.07),
				M.WoodPlanks
			)
		end
	end
	local cuerda = Color3.fromRGB(150, 128, 90)
	local postes = math.max(2, math.floor(largo / 10))
	local topes: { [number]: Vector3 } = {}
	for i = 0, postes do
		local t = i / postes
		local p = cubierta(t)
		for _, s in { -1, 1 } do
			local b = p + lado * s * (ancho / 2)
			local fondo = if i == 0 or i == postes
				then b - Vector3.new(0, 1.5, 0)
				else Vector3.new(b.X, nivelAgua - 8, b.Z)
			Kit.cilindro(m, fondo, b + Vector3.new(0, 3.6, 0), 0.55, MADERA, M.Wood)
			local tope = b + Vector3.new(0, 3.4, 0)
			local clave = s * 1000 + i
			local anterior = topes[s * 1000 + i - 1]
			if anterior then
				Kit.cilindro(m, anterior, tope, 0.22, cuerda, M.Fabric, Kit.FOLLAJE)
			end
			topes[clave] = tope
		end
	end
	return m
end

-- Lona tendida entre dos palos (campamento improvisado de los turistas).
function Estructuras.lona(rng: Random, cf: CFrame, padre: Instance, color: Color3?): Model
	local m = Kit.modelo("Lona", padre)
	local largo, alto, abierto = 9, 5, 4.5
	local tela = color or Color3.fromRGB(46, 92, 140)
	for _, z in { -largo / 2, largo / 2 } do
		Kit.cilindro(m, punto(cf, 0, -1, z), punto(cf, 0, alto + 0.4, z), 0.35, MADERA, M.Wood)
	end
	Kit.cilindro(
		m,
		punto(cf, 0, alto, -largo / 2 - 0.5),
		punto(cf, 0, alto, largo / 2 + 0.5),
		0.15,
		Color3.fromRGB(150, 128, 90),
		M.Fabric
	)
	for _, s in { -1, 1 } do
		local arribaP = punto(cf, 0, alto, 0)
		local abajo = punto(cf, s * abierto, 0.2, 0)
		local medio = (arribaP + abajo) / 2
		local cfLona = CFrame.lookAt(medio, abajo, cf.LookVector)
		-- el eje Y local queda a lo largo de la lona, el X es su grosor
		Kit.parte(
			m,
			cfLona,
			Vector3.new(0.12, largo, (abajo - arribaP).Magnitude),
			Kit.variar(tela, rng, 0.04),
			M.Fabric
		)
	end
	return m
end

-- Equipaje de los turistas desperdigado.
function Estructuras.maletas(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Equipaje", padre)
	local colores = {
		Color3.fromRGB(180, 50, 46),
		Color3.fromRGB(220, 170, 50),
		Color3.fromRGB(46, 90, 160),
		Color3.fromRGB(210, 110, 40),
		Color3.fromRGB(60, 60, 64),
	}
	for _ = 1, rng:NextInteger(4, 6) do
		local tam = Vector3.new(rng:NextNumber(2, 2.8), rng:NextNumber(1.5, 2.2), rng:NextNumber(0.8, 1.1))
		local p = cf
			* CFrame.new(rng:NextNumber(-8, 8), tam.Z / 2, rng:NextNumber(-8, 8))
			* CFrame.Angles(math.pi / 2, rng:NextNumber(0, 6), 0)
		local maleta = Kit.parte(m, p, tam, Kit.elegir(rng, colores), M.Plastic)
		Kit.parte(
			m,
			maleta.CFrame * CFrame.new(0, tam.Y / 2 + 0.15, 0),
			Vector3.new(0.9, 0.3, 0.2),
			Color3.fromRGB(30, 30, 30),
			M.Plastic,
			Kit.FOLLAJE
		)
	end
	return m
end

-- Bengala clavada en el suelo: luz roja y humo.
function Estructuras.bengala(cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Bengala", padre)
	local llama = Kit.parte(
		m,
		cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(1.6, 0.4, 0.4),
		Color3.fromRGB(255, 60, 50),
		M.Neon,
		{ forma = CIL, colision = false, nombre = "Llama" }
	)
	Kit.luz(llama, Color3.fromRGB(255, 70, 60), 22, 2.2)
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(200, 80, 80)
	humo.Opacity = 0.08
	humo.RiseVelocity = 3
	humo.Size = 3
	humo.Parent = llama
	Kit.etiquetar(llama, "Antorcha")
	return m
end

-- Poste de piedra con un glifo luminoso que marca el límite de un pueblo protegido.
function Estructuras.totem(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Totem", padre)
	local alto = rng:NextNumber(5, 7)
	local piedra = Kit.variar(PIEDRA, rng, 0.05)
	cf *= CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
	Kit.parte(m, cf * CFrame.new(0, alto / 2 - 0.8, 0), Vector3.new(1.6, alto, 1.6), piedra, M.Slate)
	for _, y in { 1.2, alto - 1.6 } do
		Kit.parte(m, cf * CFrame.new(0, y, 0), Vector3.new(1.9, 0.45, 1.9), Kit.variar(piedra, rng, 0.08), M.Slate)
	end
	Kit.parte(m, cf * CFrame.new(0, alto - 0.5, 0), Vector3.new(2.1, 0.6, 2.1), piedra, M.Slate)
	local glifo = Kit.parte(
		m,
		cf * CFrame.new(0, alto / 2, -0.82),
		Vector3.new(0.7, alto * 0.38, 0.08),
		GLIFO,
		M.Neon,
		{ colision = false, consulta = false, sombra = false, transparencia = 0.25, nombre = "Glifo" }
	)
	Kit.etiquetar(glifo, "Glifo")
	if rng:NextNumber() < 0.5 then
		Kit.parte(
			m,
			cf * CFrame.new(0.3, alto * 0.7, -0.5),
			Vector3.new(1.4, 1.2, 0.6),
			Color3.fromRGB(70, 96, 52),
			M.Grass,
			Kit.FOLLAJE
		)
	end
	return m
end

-- Portada de piedra en el paso de salida, con dintel caído y bengalas. Su mecanismo sigue pendiente.
function Estructuras.portadaSalida(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("PortadaSalida", padre)
	local piedra = Color3.fromRGB(104, 104, 96)
	local oro = Color3.fromRGB(255, 196, 96)
	for _, s in { -1, 1 } do
		local base = cf * CFrame.new(s * 8, 0, 0)
		Kit.parte(m, base * CFrame.new(0, 8, 0), Vector3.new(3.4, 18, 3.4), Kit.variar(piedra, rng, 0.04), M.Slate)
		Kit.parte(m, base * CFrame.new(0, 0.6, 0), Vector3.new(5, 1.6, 5), piedra, M.Slate)
		for _, y in { 4, 9, 14 } do
			Kit.parte(m, base * CFrame.new(0, y, 0), Vector3.new(3.9, 0.6, 3.9), Kit.variar(piedra, rng, 0.08), M.Slate)
		end
		local glifo = Kit.parte(
			m,
			base * CFrame.new(0, 11.5, -1.75),
			Vector3.new(1, 3.4, 0.1),
			oro,
			M.Neon,
			{ colision = false, consulta = false, sombra = false, transparencia = 0.2 }
		)
		Kit.etiquetar(glifo, "Glifo")
		Estructuras.bengala(base * CFrame.new(0, 0, -4), m)
	end
	-- dintel partido: una mitad arriba, la otra caída
	Kit.parte(
		m,
		cf * CFrame.new(-3.5, 17.6, 0) * CFrame.Angles(0, 0, -0.06),
		Vector3.new(10, 2.4, 3.6),
		piedra,
		M.Slate
	)
	Kit.parte(
		m,
		cf * CFrame.new(5, 1.4, -4) * CFrame.Angles(0.15, 0.4, 0.5),
		Vector3.new(9, 2.4, 3.6),
		Kit.variar(piedra, rng, 0.06),
		M.Slate
	)
	Kit.parte(
		m,
		cf * CFrame.new(-3, 18.95, 0),
		Vector3.new(8, 0.4, 3),
		Color3.fromRGB(70, 96, 52),
		M.Grass,
		Kit.FOLLAJE
	)
	return m
end

-- Estación de radar junto al helicóptero (decorativa por ahora; su uso está pendiente).
function Estructuras.radar(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Radar", padre)
	local metal = Color3.fromRGB(78, 84, 70)
	cf *= CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05))
	Kit.parte(m, cf * CFrame.new(0, 1.6, 0), Vector3.new(4, 3.2, 3), metal, M.CorrodedMetal)
	local pantalla = Kit.parte(
		m,
		cf * CFrame.new(0, 2, -1.52),
		Vector3.new(2.4, 1.3, 0.08),
		Color3.fromRGB(80, 255, 140),
		M.Neon,
		{ colision = false, transparencia = 0.15 }
	)
	Kit.luz(pantalla, Color3.fromRGB(80, 255, 140), 8, 1)
	Kit.cilindro(m, punto(cf, 0, 3.2, 0.6), punto(cf, 0, 7, 0.6), 0.4, metal, M.Metal)
	local plato = Kit.modelo("Plato", m)
	local eje =
		Kit.parte(plato, cf * CFrame.new(0, 7.2, 0.6), Vector3.new(0.8, 0.6, 0.8), metal, M.Metal, { nombre = "Eje" })
	plato.PrimaryPart = eje
	Kit.parte(
		plato,
		cf * CFrame.new(0, 8.4, 0.6) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.4, 6, 6),
		Color3.fromRGB(180, 182, 176),
		M.Metal,
		{ forma = CIL }
	)
	Kit.cilindro(m, punto(cf, 1.6, 3.2, 1), punto(cf, 1.6, 10, 1), 0.15, metal, M.Metal)
	local baliza = Kit.parte(
		m,
		cf * CFrame.new(1.6, 10.2, 1),
		Vector3.one * 0.5,
		Color3.fromRGB(255, 60, 50),
		M.Neon,
		{ forma = BOLA, colision = false }
	)
	Kit.luz(baliza, Color3.fromRGB(255, 60, 50), 10, 1.5)
	Kit.etiquetar(baliza, "Baliza")
	Kit.etiquetar(plato, "PlatoRadar")
	return m
end

function Estructuras.barril(rng: Random, cf: CFrame, padre: Instance, tumbado: boolean?): BasePart
	local color = Kit.variar(Color3.fromRGB(150, 50, 40), rng, 0.08)
	local c = if tumbado
		then cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
		else cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local barril = Kit.parte(padre, c, Vector3.new(3.2, 2.2, 2.2), color, M.CorrodedMetal, { forma = CIL })
	return barril
end

-- Helicóptero turístico. `estrellado` lo inclina, rompe el rotor y añade humo, fuego y restos.
function Estructuras.helicoptero(rng: Random, cf: CFrame, padre: Instance, estrellado: boolean): Model
	local m = Kit.modelo(if estrellado then "HelicopteroEstrellado" else "Helicoptero", padre)
	local CUERPO = Color3.fromRGB(88, 94, 60)
	local OSCURO = Color3.fromRGB(46, 50, 40)
	local FRANJA = Color3.fromRGB(205, 98, 40)
	local VIDRIO = Color3.fromRGB(70, 95, 105)
	local MET = M.Metal
	local base = cf
	if estrellado then
		base = cf * CFrame.new(0, -1.3, 0) * CFrame.Angles(math.rad(-7), 0, math.rad(16))
	end
	local function c(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local function p(x: number, y: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end

	Kit.parte(m, c(0, 4.6, 0.5), Vector3.new(7, 6.4, 12), CUERPO, MET)
	Kit.parte(m, c(0, 4.3, -5.6), Vector3.one * 6.6, CUERPO, MET, { forma = BOLA })
	Kit.parte(
		m,
		c(0, 6.3, -6.2),
		Vector3.new(6.2, 3.4, 4.6),
		VIDRIO,
		M.Glass,
		{ cuna = true, transparencia = 0.35, reflejo = 0.15 }
	)
	Kit.parte(m, c(0, 3.2, 0.5), Vector3.new(7.1, 0.8, 12.1), FRANJA, M.SmoothPlastic)
	for _, s in { -1, 1 } do
		Kit.parte(
			m,
			c(s * 3.52, 5.7, -1.5),
			Vector3.new(0.1, 2, 3),
			VIDRIO,
			M.Glass,
			{ transparencia = 0.3, reflejo = 0.1 }
		)
		Kit.parte(
			m,
			c(s * 3.52, 5.7, 2.6),
			Vector3.new(0.1, 2, 2.4),
			VIDRIO,
			M.Glass,
			{ transparencia = 0.3, reflejo = 0.1 }
		)
		-- patines
		Kit.cilindro(m, p(s * 3.6, 0.5, -6), p(s * 3.6, 0.5, 6), 0.6, OSCURO, MET)
		Kit.cilindro(m, p(s * 3.6, 0.5, -6), p(s * 3.6, 1.4, -7.4), 0.6, OSCURO, MET)
		for _, z in { -3, 3 } do
			Kit.cilindro(m, p(s * 3.6, 0.5, z), p(s * 2.8, 2.2, z), 0.4, OSCURO, MET)
		end
		Kit.cilindro(m, p(s * 1.2, 8.8, 4.6), p(s * 1.2, 8.8, 6.2), 1.1, OSCURO, M.CorrodedMetal)
	end
	local motor = Kit.parte(m, c(0, 8.6, 1.2), Vector3.new(4.4, 2.2, 7), OSCURO, MET)
	Kit.cilindro(m, p(0, 9.6, 0.4), p(0, 11.2, 0.4), 0.9, OSCURO, MET)

	-- cola
	local colaBase = if estrellado then 15 else 21
	Kit.cilindro(m, p(0, 5.6, 6), p(0, 6.6, 15), 2.6, CUERPO, MET)
	if not estrellado then
		Kit.cilindro(m, p(0, 6.6, 15), p(0, 7.2, 21), 1.7, CUERPO, MET)
	end
	Kit.parte(m, c(0, 9.4, colaBase), Vector3.new(0.5, 5, 2.6), CUERPO, MET)
	Kit.parte(m, c(0, 7.1, colaBase - 1.8), Vector3.new(6, 0.35, 1.8), CUERPO, MET)
	Kit.parte(m, c(0.6, 9.4, colaBase + 0.2), Vector3.new(0.2, 5, 0.6), OSCURO, MET)
	Kit.parte(m, c(0.6, 9.4, colaBase + 0.2), Vector3.new(0.2, 0.6, 5), OSCURO, MET)

	-- rotor principal (modelo aparte para poder girarlo en el lobby)
	local rotor = Kit.modelo("Rotor", m)
	local eje = Kit.parte(rotor, c(0, 11.4, 0.4), Vector3.new(1.6, 0.7, 1.6), OSCURO, MET, { nombre = "Eje" })
	rotor.PrimaryPart = eje
	for i = 1, 4 do
		if not (estrellado and i >= 3) then
			local a = i / 4 * math.pi * 2
			local largo = if estrellado and i == 2 then 7 else 15
			Kit.parte(
				rotor,
				c(0, 11.5, 0.4) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -largo / 2 - 0.6),
				Vector3.new(1.3, 0.22, largo),
				OSCURO,
				MET
			)
		end
	end

	if estrellado then
		-- la cola arrancada y una pala clavada en el suelo
		local cola = cf
			* CFrame.new(rng:NextNumber(5, 9), 1.2, rng:NextNumber(20, 26))
			* CFrame.Angles(0.2, rng:NextNumber(-0.6, 0.6), 0.5)
		Kit.cilindro(m, cola.Position, (cola * CFrame.new(0, 0, 7)).Position, 1.7, CUERPO, MET)
		Kit.parte(m, cola * CFrame.new(0, 2.5, 6.5), Vector3.new(0.5, 5, 2.6), CUERPO, MET)
		Kit.parte(
			m,
			cf
				* CFrame.new(rng:NextNumber(-15, -10), 2.5, rng:NextNumber(-6, 6))
				* CFrame.Angles(0.9, rng:NextNumber(0, 6), 0.2),
			Vector3.new(1.3, 0.22, 13),
			OSCURO,
			MET
		)
		for _ = 1, 7 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(8, 20)
			Kit.parte(
				m,
				cf
					* CFrame.new(math.cos(a) * r, 0.3, math.sin(a) * r)
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)),
				Vector3.new(rng:NextNumber(1, 3.5), 0.2, rng:NextNumber(1, 3)),
				if rng:NextNumber() < 0.5 then CUERPO else OSCURO,
				M.CorrodedMetal
			)
		end
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
		Kit.luz(motor, LUZ_FUEGO, 22, 1.6)
		Kit.etiquetar(motor, "Antorcha")
		local baliza = Kit.parte(
			m,
			c(0, 12.1, colaBase),
			Vector3.one * 0.6,
			Color3.fromRGB(255, 50, 40),
			M.Neon,
			{ forma = BOLA, colision = false }
		)
		Kit.luz(baliza, Color3.fromRGB(255, 50, 40), 18, 2)
		Kit.etiquetar(baliza, "Baliza")
	end
	return m
end

return Estructuras
