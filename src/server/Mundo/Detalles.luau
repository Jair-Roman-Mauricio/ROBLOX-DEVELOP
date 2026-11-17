--!strict
--[[
	La última pasada de la generación: atmósfera y detalles inquietantes, pocos y bien puestos
	(docs/SELVA-CULTO.md).

	Atmósfera   niebla baja sobre el agua y en los fondos de valle, haces de luna fría en los
	            claros y sobre el lago negro, sonido de los arroyos
	Agua        nenúfares en el lago negro, rocas que asoman en los rápidos, raíces al aire en
	            las orillas del río
	Senderos    raíces mojadas que cruzan el paso y charcos
	Terror      arañazos frescos en troncos, pieles mudadas colgando, el rastro de ofrendas que
	            lleva de la salida al templo y hongos que brillan en troncos podridos cerca de
	            los senderos, como guía discreta

	Nada de esto colisiona ni proyecta sombra.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Atmosfera = require(script.Parent.Parent.Modelos.Atmosfera)
local Culto = require(script.Parent.Parent.Modelos.Culto)
local Disposicion = require(script.Parent.Disposicion)
local Kit = require(script.Parent.Parent.Modelos.Kit)
local Terreno = require(script.Parent.Terreno)
local Vegetacion = require(script.Parent.Parent.Modelos.Vegetacion)

local C = Config.Mapa
local AT = C.Atmosfera
local CU = C.Culto
local MITAD = C.TAMANO / 2
local M = Enum.Material
local CIL = Enum.PartType.Cylinder
local BOLA = Enum.PartType.Ball
local DECOR = Kit.FOLLAJE

local Detalles = {}

local function suelo(datos: Terreno.Datos, x: number, z: number): Vector3
	return Kit.suelo(x, z) or Vector3.new(x, datos.altura(x, z), z)
end

local function dentro(p: Vector2, margen: number): boolean
	return math.max(math.abs(p.X), math.abs(p.Y)) < MITAD * C.Vegetacion.BORDE - margen
end

-- Punto de la superficie de un modelo visto desde `desde` hacia `hacia` (solo ese modelo).
local function tocar(modelo: Instance, desde: Vector3, hacia: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { modelo }
	return workspace:Raycast(desde, hacia - desde, params)
end

-- Modelos de una carpeta de la vegetación cerca de un sendero, barajados.
local function cercaDeSenderos(rng: Random, carpeta: Instance?, datos: Terreno.Datos, distancia: number): { Model }
	local lista: { Model } = {}
	if not carpeta then
		return lista
	end
	for _, m in carpeta:GetChildren() do
		if m:IsA("Model") then
			local p = m:GetPivot().Position
			if datos.distanciaCamino(p.X, p.Z) < C.ANCHO_CAMINO + distancia then
				table.insert(lista, m)
			end
		end
	end
	for i = #lista, 2, -1 do
		local j = rng:NextInteger(1, i)
		lista[i], lista[j] = lista[j], lista[i]
	end
	return lista
end

-- Toca el tronco de un árbol a la altura `h` sobre el suelo, desde el lado del sendero.
local function tronco(arbol: Model, datos: Terreno.Datos, h: number, rng: Random): RaycastResult?
	local pie = arbol:GetPivot().Position
	local y = datos.altura(pie.X, pie.Z) + h
	local a = rng:NextNumber(0, math.pi * 2)
	local desde = Vector3.new(pie.X + math.cos(a) * 14, y, pie.Z + math.sin(a) * 14)
	return tocar(arbol, desde, Vector3.new(pie.X, y, pie.Z))
end

function Detalles.decorar(
	rng: Random,
	disp: Disposicion.Disposicion,
	datos: Terreno.Datos,
	carpeta: Instance,
	vegetacion: Instance,
	claros: { { pos: Vector2, radio: number } }
)
	local atm = Instance.new("Folder")
	atm.Name = "Atmosfera"
	atm.Parent = carpeta
	local terror = Instance.new("Folder")
	terror.Name = "Terror"
	terror.Parent = carpeta

	local pantano: Disposicion.Lago? = nil
	for _, l in disp.lagos do
		if l.tipo == "pantano" then
			pantano = l
		end
	end

	-------------------------------------------------------------------------------------------
	-- Niebla baja: sobre el río, los lagos, los arroyos y en algunos fondos de valle
	-------------------------------------------------------------------------------------------
	local recorrido = math.huge
	for k = 2, #disp.rio do
		recorrido += (disp.rio[k] - disp.rio[k - 1]).Magnitude
		local p = disp.rio[k]
		if recorrido >= AT.NIEBLA_RIO and dentro(p, 40) then
			recorrido = 0
			Atmosfera.niebla(atm, Vector3.new(p.X, C.NIVEL_AGUA, p.Y), 60)
		end
	end
	for _, l in disp.lagos do
		local nivel = Vector3.new(l.centro.X, l.nivel, l.centro.Y)
		Atmosfera.niebla(atm, nivel, l.radio * 1.6, l.tipo == "pantano")
	end
	for _, a in disp.arroyos do
		if a.activo then
			for k = 20, #a.puntos, 50 do
				local p = a.puntos[k]
				Atmosfera.niebla(atm, Vector3.new(p.X, a.niveles[k], p.Y), 34)
			end
			local medio = a.puntos[#a.puntos // 2]
			Atmosfera.sonido(
				atm,
				Vector3.new(medio.X, a.niveles[#a.puntos // 2] + 1, medio.Y),
				C.Agua.Sonidos.Arroyo,
				20,
				160
			)
		end
	end
	local valles = 0
	for _ = 1, 80 do
		if valles >= 10 then
			break
		end
		local p = Vector2.new(rng:NextNumber(-MITAD, MITAD), rng:NextNumber(-MITAD, MITAD))
		local h = datos.altura(p.X, p.Y)
		if dentro(p, 60) and h < C.NIVEL_AGUA + 10 and datos.distanciaAgua(p.X, p.Y) > 20 then
			Atmosfera.niebla(atm, Vector3.new(p.X, h, p.Y), 50)
			valles += 1
		end
	end

	-------------------------------------------------------------------------------------------
	-- Haces de luna en los claros y sobre el lago negro
	-------------------------------------------------------------------------------------------
	local haces = 0
	for _, c in claros do
		if haces >= AT.HACES - 2 then
			break
		end
		Atmosfera.haz(atm, suelo(datos, c.pos.X, c.pos.Y), rng)
		haces += 1
	end
	if pantano then
		for _ = 1, 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			local p = pantano.centro + Vector2.new(math.cos(a), math.sin(a)) * pantano.radio * 0.4
			Atmosfera.haz(atm, Vector3.new(p.X, pantano.nivel, p.Y), rng)
		end
	end

	-------------------------------------------------------------------------------------------
	-- Agua: nenúfares, rocas en los rápidos y raíces al aire en las orillas
	-------------------------------------------------------------------------------------------
	if pantano then
		local hojas = Kit.modelo("Nenufares", atm)
		for _ = 1, 45 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = pantano.radio * math.sqrt(rng:NextNumber(0.05, 0.9))
			local p = pantano.centro + Vector2.new(math.cos(a), math.sin(a)) * r
			local d = rng:NextNumber(2, 4.2)
			Kit.parte(
				hojas,
				CFrame.new(p.X, pantano.nivel + 0.04, p.Y) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.pi / 2),
				Vector3.new(0.08, d, d),
				Kit.variar(Color3.fromRGB(42, 68, 38), rng, 0.06),
				M.SmoothPlastic,
				{ forma = CIL, colision = false, consulta = false, sombra = false }
			)
		end
	end
	local rapidos = Instance.new("Folder")
	rapidos.Name = "Rapidos"
	rapidos.Parent = atm
	for _, r in disp.rapidos do
		for _ = 1, 12 do
			local p = r + Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * C.Agua.RAPIDO_LARGO * 0.8
			if datos.distanciaRio(p.X, p.Y) < C.ANCHO_RIO then
				Vegetacion.roca(rng, Vector3.new(p.X, datos.altura(p.X, p.Y), p.Y), rapidos)
			end
		end
		Atmosfera.niebla(atm, Vector3.new(r.X, C.NIVEL_AGUA, r.Y), 40)
	end
	local orillas = Kit.modelo("RaicesOrilla", atm)
	for _ = 1, 30 do
		local k = rng:NextInteger(2, #disp.rio - 1)
		local p = disp.rio[k]
		local dir = disp.rio[k + 1] - disp.rio[k - 1]
		if dir.Magnitude > 1e-3 and dentro(p, 40) then
			local lado = Vector2.new(-dir.Y, dir.X).Unit * Kit.elegir(rng, { -1, 1 })
			local arriba = p + lado * (C.ANCHO_RIO + C.ORILLA + rng:NextNumber(2, 6))
			local abajo = p + lado * (C.ANCHO_RIO - rng:NextNumber(1, 4))
			if datos.distanciaCamino(arriba.X, arriba.Y) > C.ANCHO_CAMINO + 6 then
				local a = suelo(datos, arriba.X, arriba.Y)
				for _ = 1, rng:NextInteger(2, 4) do
					local desvio = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
					Culto.raiz(
						orillas,
						a + desvio,
						Vector3.new(abajo.X, C.NIVEL_AGUA - 1.5, abajo.Y) + desvio,
						rng:NextNumber(0.6, 1.2),
						rng
					)
				end
			end
		end
	end

	-------------------------------------------------------------------------------------------
	-- Senderos: raíces que cruzan y charcos
	-------------------------------------------------------------------------------------------
	local senderos = Kit.modelo("Senderos", atm)
	local charcos = 0
	for _, cam in disp.caminos do
		local largo = 0
		for k = 2, #cam.puntos - 1 do
			largo += (cam.puntos[k] - cam.puntos[k - 1]).Magnitude
			local p = cam.puntos[k]
			if largo >= 60 then
				largo = 0
				local dir = cam.puntos[k + 1] - cam.puntos[k - 1]
				if
					rng:NextNumber() < AT.RAICES_SENDERO
					and dir.Magnitude > 1e-3
					and datos.nivelAgua(p.X, p.Y) + 1 < datos.altura(p.X, p.Y)
				then
					local perp = Vector2.new(-dir.Y, dir.X).Unit
					local a = p + perp * (C.ANCHO_CAMINO + 3)
					local b = p - perp * (C.ANCHO_CAMINO + 3)
					Culto.raiz(
						senderos,
						suelo(datos, a.X, a.Y) + Vector3.yAxis * 0.2,
						suelo(datos, b.X, b.Y) + Vector3.yAxis * 0.2,
						rng:NextNumber(0.6, 1),
						rng
					)
				end
			elseif charcos < AT.CHARCOS and rng:NextNumber() < 0.012 and datos.distanciaAgua(p.X, p.Y) > 20 then
				charcos += 1
				local q = suelo(datos, p.X + rng:NextNumber(-3, 3), p.Y + rng:NextNumber(-3, 3))
				local d = rng:NextNumber(3, 7)
				Kit.parte(
					senderos,
					CFrame.new(q + Vector3.yAxis * 0.06) * CFrame.Angles(0, rng:NextNumber(0, 6), math.pi / 2),
					Vector3.new(0.08, d, d * rng:NextNumber(0.6, 1)),
					Color3.fromRGB(18, 24, 22),
					M.SmoothPlastic,
					{ forma = CIL, colision = false, consulta = false, sombra = false, reflejo = 0.35 }
				)
			end
		end
	end

	-------------------------------------------------------------------------------------------
	-- Terror: arañazos, mudas, rastro de ofrendas al templo y hongos que guían
	-------------------------------------------------------------------------------------------
	local arboles = cercaDeSenderos(rng, vegetacion:FindFirstChild("Arboles"), datos, 26)
	local usados = 0
	local function siguienteArbol(): Model?
		usados += 1
		return arboles[usados]
	end

	-- arañazos frescos: tres o cuatro surcos paralelos en la corteza, a la altura de la cabeza
	local aranazos = Kit.modelo("Aranazos", terror)
	local hechos = 0
	while hechos < AT.ARANAZOS do
		local arbol = siguienteArbol()
		if not arbol then
			break
		end
		local hit = tronco(arbol, datos, rng:NextNumber(5.5, 8), rng)
		if hit then
			hechos += 1
			local cf = CFrame.lookAt(hit.Position, hit.Position + hit.Normal)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.35, 0.35))
			for k = 1, rng:NextInteger(3, 4) do
				Kit.parte(
					aranazos,
					cf * CFrame.new((k - 2.5) * 0.45, rng:NextNumber(-0.3, 0.3), -0.05),
					Vector3.new(0.16, rng:NextNumber(2.6, 3.8), 0.12),
					Color3.fromRGB(176, 146, 108),
					M.Wood,
					DECOR
				)
			end
		end
	end

	-- pieles mudadas: cuelgan del tronco, pálidas y medio transparentes
	local mudas = Kit.modelo("Mudas", terror)
	hechos = 0
	while hechos < AT.MUDAS do
		local arbol = siguienteArbol()
		if not arbol then
			break
		end
		local hit = tronco(arbol, datos, rng:NextNumber(12, 20), rng)
		if hit then
			hechos += 1
			local prev = hit.Position + hit.Normal * 0.6
			local tramos = rng:NextInteger(5, 8)
			for k = 1, tramos do
				local p = prev
					+ Vector3.new(0, -rng:NextNumber(1.4, 2.2), 0)
					+ hit.Normal * rng:NextNumber(-0.2, 0.4)
					+ Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
				local ancho = 1.1 * (1 - 0.6 * k / tramos)
				Kit.viga(mudas, prev, p, ancho, 0.12, Color3.fromRGB(206, 196, 168), M.SmoothPlastic, {
					colision = false,
					consulta = false,
					sombra = false,
					transparencia = 0.3,
				}, rng:NextNumber(-0.6, 0.6))
				prev = p
			end
		end
	end

	-- rastro de ofrendas: del sendero que va de la salida al templo, más seguidas al acercarse
	local rastro = Kit.modelo("RastroOfrendas", terror)
	for _, cam in disp.caminos do
		local alTemplo = if cam.b == "T" then 1 elseif cam.a == "T" then -1 else 0
		if alTemplo ~= 0 then
			local n = #cam.puntos
			local largo, lado = 0, 1
			for i = 2, n - 1 do
				local k = if alTemplo == 1 then i else n + 1 - i
				local t = (i - 1) / (n - 1) -- 0 en la salida, 1 en el templo
				largo += (cam.puntos[k] - cam.puntos[k - alTemplo]).Magnitude
				local cada = CU.OFRENDAS_CADA * (1.6 - t)
				if largo >= cada and t > 0.08 and t < 0.92 then
					largo = 0
					lado = -lado
					local dir = cam.puntos[math.min(n, k + 1)] - cam.puntos[math.max(1, k - 1)]
					if dir.Magnitude > 1e-3 then
						local q = cam.puntos[k] + Vector2.new(-dir.Y, dir.X).Unit * lado * (C.ANCHO_CAMINO + 1.5)
						local s = suelo(datos, q.X, q.Y)
						if s.Y > datos.nivelAgua(q.X, q.Y) + 0.5 then
							local cf = CFrame.lookAt(s, s + Vector3.new(dir.X, 0, dir.Y))
								* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
							if rng:NextNumber() < 0.25 + t * 0.4 then
								Culto.ofrenda(rastro, cf, rng)
							else
								Culto.vela(rastro, cf, rng)
								if rng:NextNumber() < t then
									Culto.huesos(rastro, cf * CFrame.new(0, 0, 1.5), rng, rng:NextInteger(1, 2))
								end
							end
						end
					end
				end
			end
		end
	end

	-- hongos bioluminiscentes en troncos podridos junto a los senderos
	local hongos = Kit.modelo("Hongos", terror)
	local troncos = cercaDeSenderos(rng, vegetacion:FindFirstChild("Troncos"), datos, 40)
	hechos = 0
	for _, t in troncos do
		if hechos >= AT.HONGOS_TRONCOS then
			break
		end
		local centro = t:GetPivot().Position
		local brotes = 0
		for _ = 1, 8 do
			local x, z = centro.X + rng:NextNumber(-4, 4), centro.Z + rng:NextNumber(-4, 4)
			local hit = tocar(t, Vector3.new(x, centro.Y + 20, z), Vector3.new(x, centro.Y - 10, z))
			if hit then
				brotes += 1
				for _ = 1, rng:NextInteger(2, 4) do
					local d = rng:NextNumber(0.25, 0.7)
					Kit.parte(
						hongos,
						CFrame.new(
							hit.Position + Vector3.new(rng:NextNumber(-0.8, 0.8), d * 0.2, rng:NextNumber(-0.8, 0.8))
						),
						Vector3.new(d, d * 0.45, d),
						AT.HONGOS,
						M.Neon,
						{ forma = BOLA, colision = false, consulta = false, sombra = false, transparencia = 0.35 }
					)
				end
			end
		end
		if brotes > 0 then
			hechos += 1
		end
	end
	carpeta:SetAttribute("Hongos", hechos)
end

return Detalles
