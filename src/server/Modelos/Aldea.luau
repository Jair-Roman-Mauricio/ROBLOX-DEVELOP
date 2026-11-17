--!strict
--[[
	Piezas de las tres aldeas abandonadas a toda prisa (docs/SELVA-CULTO.md): hamacas, vasijas
	volcadas, enseres tirados, puertas rotas, lianas que se tragan las chozas, palafitos sobre
	el lago negro con pasarelas caídas, el pozo y la sala de reuniones en ruinas.

	Nada vivo y ningún rastro de los habitantes: solo lo que dejaron al huir.
	Convención de Estructuras: `cf` está en el suelo y el frente mira hacia -Z.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Estructuras = require(script.Parent.Estructuras)
local Kit = require(script.Parent.Kit)

local CU = Config.Mapa.Culto
local M = Enum.Material
local CIL = Enum.PartType.Cylinder

local MADERA = Color3.fromRGB(86, 66, 46)
local PODRIDA = Color3.fromRGB(70, 60, 44)
local BARRO = Color3.fromRGB(122, 78, 52)
local FIBRA = Color3.fromRGB(140, 116, 76)
local LIANA = Color3.fromRGB(46, 70, 34)
local TELAS = { Color3.fromRGB(120, 44, 32), Color3.fromRGB(70, 82, 96), Color3.fromRGB(150, 120, 70) }

local DECOR = Kit.FOLLAJE

local Aldea = {}

local function punto(cf: CFrame, x: number, y: number, z: number): Vector3
	return cf:PointToWorldSpace(Vector3.new(x, y, z))
end

-- Hamaca colgada entre dos postes; a veces rota por un extremo y arrastrando.
function Aldea.hamaca(rng: Random, desde: Vector3, hasta: Vector3, padre: Instance): Model
	local m = Kit.modelo("Hamaca", padre)
	for _, p in { desde, hasta } do
		Kit.cilindro(m, p - Vector3.yAxis, p + Vector3.yAxis * 5, 0.5, Kit.variar(MADERA, rng, 0.05), M.Wood)
	end
	local a, b = desde + Vector3.yAxis * 3.8, hasta + Vector3.yAxis * 3.8
	if rng:NextNumber() < 0.4 then
		b = hasta + Vector3.new(rng:NextNumber(-1, 1), 0.2, rng:NextNumber(-1, 1))
	end
	local tela = Kit.elegir(rng, TELAS)
	local prev = a
	for k = 1, 4 do
		local t = k / 4
		local p = a:Lerp(b, t) - Vector3.yAxis * math.sin(t * math.pi) * 1.8
		Kit.viga(m, prev, p, 2.2, 0.12, Kit.variar(tela, rng, 0.05), M.Fabric, DECOR)
		prev = p
	end
	return m
end

-- Vasija de barro, de pie o volcada con trozos rotos alrededor.
function Aldea.vasija(rng: Random, cf: CFrame, padre: Instance, volcada: boolean): Model
	local m = Kit.modelo("Vasija", padre)
	local alto = rng:NextNumber(1.6, 2.6)
	local color = Kit.variar(BARRO, rng, 0.06)
	local c = if volcada
		then cf * CFrame.new(0, alto * 0.38, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(
			math.pi / 2,
			0,
			0
		)
		else cf * CFrame.new(0, alto / 2, 0)
	Kit.ovoide(m, c, Vector3.new(alto * 0.8, alto, alto * 0.8), color, M.Slate, { colision = true })
	Kit.parte(
		m,
		c * CFrame.new(0, alto * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(alto * 0.25, alto * 0.42, alto * 0.42),
		color,
		M.Slate,
		{ forma = CIL, colision = false, consulta = false, sombra = false }
	)
	if volcada then
		for _ = 1, rng:NextInteger(2, 4) do
			Kit.parte(
				m,
				cf
					* CFrame.new(rng:NextNumber(-2, 2), 0.1, rng:NextNumber(-2, 2))
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), 0),
				Vector3.new(rng:NextNumber(0.4, 0.8), 0.12, rng:NextNumber(0.3, 0.6)),
				color,
				M.Slate,
				DECOR
			)
		end
	end
	return m
end

-- Lo que dejaron al huir: vasijas volcadas, una cesta, un petate, ropa tirada, un cuenco.
function Aldea.enseres(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Enseres", padre)
	for _ = 1, rng:NextInteger(3, 6) do
		local c = cf
			* CFrame.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		local r = rng:NextNumber()
		if r < 0.35 then
			Aldea.vasija(rng, c, m, rng:NextNumber() < 0.7)
		elseif r < 0.55 then
			-- cesta tumbada
			Kit.parte(
				m,
				c * CFrame.new(0, 0.8, 0),
				Vector3.new(1.8, 1.6, 1.6),
				Kit.variar(FIBRA, rng, 0.06),
				M.Fabric,
				{ forma = CIL, colision = false, consulta = false, sombra = false }
			)
		elseif r < 0.7 then
			-- petate enrollado a medias
			Kit.parte(
				m,
				c * CFrame.new(0, 0.06, 0),
				Vector3.new(3.4, 0.1, 2.2),
				Kit.variar(FIBRA, rng, 0.05),
				M.Fabric,
				DECOR
			)
		elseif r < 0.88 then
			-- ropa tirada en el barro
			Kit.parte(
				m,
				c * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)),
				Vector3.new(rng:NextNumber(1.6, 2.6), 0.08, rng:NextNumber(1.2, 2)),
				Kit.variar(Kit.elegir(rng, TELAS), rng, 0.08),
				M.Fabric,
				DECOR
			)
		else
			Kit.parte(
				m,
				c * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Vector3.new(0.5, 1.4, 1.4),
				Kit.variar(BARRO, rng, 0.06),
				M.Slate,
				{ forma = CIL, colision = false, consulta = false, sombra = false }
			)
		end
	end
	return m
end

-- Puerta arrancada, apoyada contra la pared o tirada delante de la entrada.
function Aldea.puertaRota(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("PuertaRota", padre)
	local tirada = rng:NextNumber() < 0.5
	local c = if tirada
		then cf * CFrame.new(rng:NextNumber(-1, 1), 0.2, -1.5) * CFrame.Angles(
			math.pi / 2 - 0.05,
			rng:NextNumber(-0.4, 0.4),
			0
		)
		else cf * CFrame.new(2.6, 2.6, 0) * CFrame.Angles(-0.25, 0, rng:NextNumber(-0.12, 0.12))
	for k = -1, 1 do
		if k ~= 1 or rng:NextNumber() > 0.4 then
			Kit.parte(
				m,
				c * CFrame.new(k * 0.75, 0, 0),
				Vector3.new(0.7, 5.2 - math.abs(k) * rng:NextNumber(0, 1.2), 0.25),
				Kit.variar(PODRIDA, rng, 0.06),
				M.WoodPlanks,
				DECOR
			)
		end
	end
	Kit.parte(m, c * CFrame.new(0, 1.2, -0.18), Vector3.new(2.3, 0.4, 0.2), PODRIDA, M.Wood, DECOR)
	return m
end

-- Lianas que caen desde `desde` hasta el suelo (las que se tragan las chozas).
function Aldea.lianas(rng: Random, desde: Vector3, suelo: number, padre: Instance)
	for _ = 1, rng:NextInteger(3, 6) do
		local a = desde + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		local b = Vector3.new(a.X + rng:NextNumber(-3, 3), suelo, a.Z + rng:NextNumber(-3, 3))
		local medio = a:Lerp(b, 0.5) + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		Kit.cilindro(padre, a, medio, 0.28, Kit.variar(LIANA, rng, 0.06), M.Grass, DECOR)
		Kit.cilindro(padre, medio, b, 0.24, Kit.variar(LIANA, rng, 0.06), M.Grass, DECOR)
		-- hojas sueltas a lo largo
		Kit.parte(
			padre,
			CFrame.new(a:Lerp(medio, rng:NextNumber(0.2, 0.9)))
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Vector3.new(1.2, 0.08, 0.7),
			Kit.variar(LIANA, rng, 0.1),
			M.Grass,
			DECOR
		)
	end
end

-- Choza sobre el agua: la choza normal subida en pilotes que bajan hasta el lecho.
-- `hundida`: medio sumergida y ladeada, como si los pilotes hubieran cedido.
function Aldea.palafito(rng: Random, cf: CFrame, lecho: number, padre: Instance, hundida: boolean): Model
	local m = Kit.modelo("Palafito", padre)
	local c = cf * CFrame.new(0, 2.5, 0)
	if hundida then
		c = cf
			* CFrame.new(0, -3.5, 0)
			* CFrame.Angles(rng:NextNumber(0.12, 0.25) * Kit.elegir(rng, { -1, 1 }), 0, rng:NextNumber(-0.25, 0.25))
	end
	Estructuras.choza(rng, c, m, hundida or rng:NextNumber() < 0.4)
	for _, x in { -6, 0, 6 } do
		for _, z in { -5, 5 } do
			local arriba = punto(c, x, -1.5, z)
			Kit.cilindro(
				m,
				Vector3.new(arriba.X, lecho - 1, arriba.Z),
				arriba,
				0.9,
				Kit.variar(MADERA, rng, 0.05),
				M.Wood
			)
		end
	end
	return m
end

-- Pasarela de tablas sobre pilotes entre dos puntos. `rota`: falta el tramo del medio y
-- algunas tablas cuelgan hacia el agua.
function Aldea.pasarela(
	rng: Random,
	desde: Vector3,
	hasta: Vector3,
	lecho: number,
	padre: Instance,
	rota: boolean
): Model
	local m = Kit.modelo("Pasarela", padre)
	local dir = hasta - desde
	local largo = dir.Magnitude
	local plano = Vector3.new(dir.X, 0, dir.Z).Unit
	local lado = Vector3.new(-plano.Z, 0, plano.X)
	local n = math.max(2, math.floor(largo / 1.1))
	local hueco0, hueco1 = 0.4, 0.62
	for i = 1, n do
		local t = (i - 0.5) / n
		local p = desde:Lerp(hasta, t)
		local enHueco = rota and t > hueco0 and t < hueco1
		if enHueco then
			if rng:NextNumber() < 0.3 then
				-- tabla colgando de un extremo
				Kit.parte(
					m,
					CFrame.lookAt(p, p + plano)
						* CFrame.new(0, -1.3, 0)
						* CFrame.Angles(rng:NextNumber(0.9, 1.3), 0, rng:NextNumber(-0.3, 0.3)),
					Vector3.new(3, 0.3, 1),
					Kit.variar(PODRIDA, rng, 0.06),
					M.WoodPlanks,
					DECOR
				)
			end
		elseif rng:NextNumber() > 0.1 then
			Kit.parte(
				m,
				CFrame.lookAt(p, p + plano) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.04, 0.04)),
				Vector3.new(3.2, 0.3, 1),
				Kit.variar(PODRIDA, rng, 0.07),
				M.WoodPlanks
			)
		end
	end
	-- largueros: continuos fuera del hueco
	for _, s in { -1, 1 } do
		local tramos: { { number } } = if rota then { { 0, hueco0 }, { hueco1, 1 } } else { { 0, 1 } }
		for _, tr in tramos do
			Kit.viga(
				m,
				desde:Lerp(hasta, tr[1]) + lado * s * 1.3 - Vector3.yAxis * 0.4,
				desde:Lerp(hasta, tr[2]) + lado * s * 1.3 - Vector3.yAxis * 0.4,
				0.5,
				0.5,
				MADERA,
				M.Wood
			)
		end
	end
	local postes = math.max(1, math.floor(largo / 5))
	for i = 0, postes do
		local p = desde:Lerp(hasta, i / postes)
		for _, s in { -1, 1 } do
			local b = p + lado * s * 1.5
			Kit.cilindro(
				m,
				Vector3.new(b.X, lecho - 1, b.Z),
				b + Vector3.yAxis * (if rng:NextNumber() < 0.5 then 2.4 else 0.2),
				0.5,
				MADERA,
				M.Wood
			)
		end
	end
	return m
end

-- Pozo de piedra con su travesaño, la cuerda cortada y el balde tirado al lado.
function Aldea.pozo(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Pozo", padre)
	local n = 12
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		Kit.parte(
			m,
			cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.2, -3.3) * CFrame.Angles(0, 0, rng:NextNumber(-0.04, 0.04)),
			Vector3.new(1.9, 2.6 - (if rng:NextNumber() < 0.15 then 1 else 0), 1.1),
			Kit.variar(CU.PIEDRA, rng, 0.05),
			M.Slate
		)
	end
	Kit.parte(
		m,
		cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.1, 5.4, 5.4),
		Color3.fromRGB(8, 12, 12),
		M.SmoothPlastic,
		{ forma = CIL, colision = true, consulta = true, sombra = false, reflejo = 0.2 }
	)
	for _, x in { -3.6, 3.6 } do
		Kit.cilindro(m, punto(cf, x, 0, 0), punto(cf, x, 7, 0), 0.6, MADERA, M.Wood)
	end
	Kit.cilindro(m, punto(cf, -4, 6.6, 0), punto(cf, 4, 6.6, 0), 0.5, MADERA, M.Wood)
	Kit.cilindro(m, punto(cf, 0, 6.4, 0), punto(cf, 0, 3.4, 0), 0.12, FIBRA, M.Fabric, DECOR)
	Kit.parte(
		m,
		cf * CFrame.new(4.4, 0.6, -2.2) * CFrame.Angles(math.pi / 2, 0.4, 0),
		Vector3.new(1.2, 1.2, 1.2),
		MADERA,
		M.WoodPlanks,
		{ forma = CIL, colision = false, consulta = false, sombra = false }
	)
	-- musgo y raíces en el brocal
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		Kit.parte(
			m,
			cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.55, -3.3),
			Vector3.new(rng:NextNumber(1, 2.4), 0.2, 1.2),
			Kit.variar(CU.MUSGO, rng, 0.05),
			M.Grass,
			DECOR
		)
	end
	return m
end

-- Sala de reuniones de piedra en ruinas: muros a medio caer, columnas partidas al frente,
-- vigas del techo caídas dentro y escombros.
function Aldea.sala(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("SalaReuniones", padre)
	local W, D, alto = 28, 18, 9
	local function muro(desde: Vector3, hasta: Vector3, puerta: boolean)
		local largo = (hasta - desde).Magnitude
		local n = math.floor(largo / 3)
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			local enPuerta = puerta and math.abs(t - 0.5) < 0.12
			if not enPuerta then
				-- algunos tramos se cayeron: muro bajo y bloques en el suelo
				local h = if rng:NextNumber() < 0.35 then rng:NextNumber(1.5, 4) else alto * rng:NextNumber(0.75, 1)
				local p = desde:Lerp(hasta, t)
				Kit.parte(
					m,
					CFrame.lookAt(p, p + (hasta - desde)) * CFrame.new(0, h / 2 - 0.4, 0),
					Vector3.new(1.6, h, largo / n + 0.05),
					Kit.variar(CU.PIEDRA, rng, 0.05),
					M.Slate
				)
				if h < alto * 0.5 and rng:NextNumber() < 0.7 then
					local q = p + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
					Kit.parte(
						m,
						CFrame.new(q + Vector3.yAxis * 0.6)
							* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
						Vector3.new(rng:NextNumber(1.5, 2.8), 1.2, rng:NextNumber(1, 1.8)),
						Kit.variar(CU.PIEDRA, rng, 0.06),
						M.Slate
					)
				end
			end
		end
	end
	local esq = {
		punto(cf, -W / 2, 0, -D / 2),
		punto(cf, W / 2, 0, -D / 2),
		punto(cf, W / 2, 0, D / 2),
		punto(cf, -W / 2, 0, D / 2),
	}
	muro(esq[1], esq[2], true)
	muro(esq[2], esq[3], false)
	muro(esq[3], esq[4], false)
	muro(esq[4], esq[1], false)
	-- columnas del pórtico, dos partidas
	for k = 0, 3 do
		local x = -W / 2 + 3 + k * (W - 6) / 3
		local partida = k == 1 or (k == 3 and rng:NextNumber() < 0.5)
		local h = if partida then rng:NextNumber(2.5, 4.5) else alto + 1
		Kit.parte(
			m,
			cf * CFrame.new(x, h / 2 - 0.4, -D / 2 - 4) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Vector3.new(1.8, h, 1.8),
			Kit.variar(CU.PIEDRA, rng, 0.04),
			M.Slate
		)
		if partida then
			Kit.parte(
				m,
				cf
					* CFrame.new(x + rng:NextNumber(-2, 2), 0.6, -D / 2 - 7.5)
					* CFrame.Angles(0, rng:NextNumber(0, 6), math.pi / 2),
				Vector3.new(alto - h, 1.7, 1.7),
				Kit.variar(CU.PIEDRA, rng, 0.04),
				M.Slate
			)
		end
	end
	-- vigas del techo caídas dentro, con paja podrida
	for _ = 1, 4 do
		local a = punto(cf, rng:NextNumber(-W / 2 + 2, W / 2 - 2), rng:NextNumber(0.4, 4), -D / 2 + 1)
		local b = punto(cf, rng:NextNumber(-W / 2 + 2, W / 2 - 2), 0.4, D / 2 - 1)
		Kit.cilindro(m, a, b, 0.9, Kit.variar(PODRIDA, rng, 0.05), M.Wood)
	end
	for _ = 1, 3 do
		Kit.parte(
			m,
			cf
				* CFrame.new(rng:NextNumber(-W / 3, W / 3), 0.2, rng:NextNumber(-D / 3, D / 3))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Vector3.new(rng:NextNumber(4, 7), 0.4, rng:NextNumber(3, 5)),
			Kit.variar(Color3.fromRGB(110, 92, 60), rng, 0.06),
			M.Grass,
			DECOR
		)
	end
	-- bancos de piedra en círculo: aquí se reunían
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Kit.parte(
			m,
			cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.6, -5.5),
			Vector3.new(3.4, 1.2, 1.2),
			Kit.variar(CU.PIEDRA, rng, 0.05),
			M.Slate
		)
	end
	return m
end

-- Choza de piedra en ruinas: solo quedan muros bajos.
function Aldea.ruina(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Ruina", padre)
	local w, d = rng:NextNumber(8, 11), rng:NextNumber(7, 9)
	for _, s in
		{
			{ Vector3.new(0, 0, -d / 2), Vector3.new(w, 0, 0) },
			{ Vector3.new(0, 0, d / 2), Vector3.new(w, 0, 0) },
			{ Vector3.new(-w / 2, 0, 0), Vector3.new(0, 0, d) },
			{ Vector3.new(w / 2, 0, 0), Vector3.new(0, 0, d) },
		}
	do
		local centro, eje = s[1], s[2]
		local n = 3
		for i = 0, n - 1 do
			local t = (i + 0.5) / n - 0.5
			if not (centro.Z < 0 and math.abs(t) < 0.2) and rng:NextNumber() > 0.15 then
				local h = rng:NextNumber(1.2, 4.5)
				local tam = if eje.X > 0
					then Vector3.new(eje.X / n + 0.05, h, 1.2)
					else Vector3.new(1.2, h, eje.Z / n + 0.05)
				Kit.parte(
					m,
					cf * CFrame.new(centro + eje * t + Vector3.yAxis * (h / 2 - 0.4)),
					tam,
					Kit.variar(CU.PIEDRA, rng, 0.06),
					M.Slate
				)
			end
		end
	end
	return m
end

return Aldea
