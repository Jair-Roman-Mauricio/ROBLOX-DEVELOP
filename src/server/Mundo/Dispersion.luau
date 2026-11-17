--!strict
--[[
	Reparte la vegetación con una estructura, no al azar (docs/SELVA-ECOTOPOS.md).

	1. Ecotopos: cada punto del mapa es ribera (junto al río), claro (hueco que dejó un árbol
	   caído), ladera (pendiente fuerte) o selva. Cada uno tiene sus especies y su densidad.
	2. Capas, de arriba abajo, y cada capa se apoya en la anterior:
	     hitos      ceibas emergentes junto a cada zona y a lo largo de los senderos
	     dosel      árboles con distancia mínima (como un muestreo de disco de Poisson), y
	                árboles que enmarcan los senderos alternando lados
	     rocas      peñascos en laderas y grupos de una roca grande con dos a cuatro pequeñas
	     troncos    uno en el centro de cada claro y otros caídos junto a árboles
	     sotobosque arbustos y hojas grandes al pie de los árboles, muros de vegetación en los
	                bordes de senderos y zonas, helechos abrazando troncos y rocas
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Disposicion = require(script.Parent.Disposicion)
local Ruido = require(script.Parent.Ruido)
local Terreno = require(script.Parent.Terreno)
local Kit = require(script.Parent.Parent.Modelos.Kit)
local Vegetacion = require(script.Parent.Parent.Modelos.Vegetacion)

local C = Config.Mapa
local V = C.Vegetacion
local MITAD = C.TAMANO / 2

type Creador = (Random, Vector3, Instance) -> Model
type Ecotopo = "ribera" | "claro" | "ladera" | "selva"

-- Huella de cada clase: radio libre alrededor (studs) y pendiente máxima del suelo bajo ella
-- (desnivel / distancia). Las plantas pequeñas pueden ir pegadas a troncos, no encima.
type Huella = { radio: number, pendiente: number }
local HUELLAS: { [string]: Huella } = {
	ceiba = { radio = 16, pendiente = 0.45 },
	arbol = { radio = 7, pendiente = 0.6 },
	palmera = { radio = 3.5, pendiente = 0.7 },
	penasco = { radio = 15, pendiente = 0.55 },
	roca = { radio = 6, pendiente = 0.8 },
	tronco = { radio = 10, pendiente = 0.35 },
	arbusto = { radio = 3, pendiente = 0.9 },
	planta = { radio = 1.6, pendiente = 1.1 },
}
local RADIO_MAX = 16

-- Rejilla de círculos para preguntar rápido si un punto choca con lo ya colocado.
type Rejilla = {
	libre: (x: number, z: number, radio: number) -> boolean,
	ocupar: (x: number, z: number, radio: number) -> (),
}
local function rejilla(celda: number, radioMax: number): Rejilla
	local celdas: { [number]: { vector } } = {}
	local function clave(cx: number, cz: number): number
		return cx * 4096 + cz
	end
	return {
		libre = function(x: number, z: number, radio: number): boolean
			local cx, cz = x // celda, z // celda
			local alcance = math.ceil((radio + radioMax) / celda)
			for i = cx - alcance, cx + alcance do
				for j = cz - alcance, cz + alcance do
					local lista = celdas[clave(i, j)]
					if lista then
						for _, o in lista do
							local dx, dz = o.x - x, o.z - z
							local r = o.y + radio
							if dx * dx + dz * dz < r * r then
								return false
							end
						end
					end
				end
			end
			return true
		end,
		ocupar = function(x: number, z: number, radio: number)
			local k = clave(x // celda, z // celda)
			local lista = celdas[k]
			if not lista then
				lista = {}
				celdas[k] = lista
			end
			table.insert(lista, vector.create(x, radio, z))
		end,
	}
end

local Dispersion = {}

function Dispersion.poblar(
	rng: Random,
	disp: Disposicion.Disposicion,
	datos: Terreno.Datos,
	padre: Instance,
	progreso: (number) -> ()
)
	local ox, oz = rng:NextNumber(-500, 500), rng:NextNumber(-500, 500)
	local lim = MITAD - 20

	local function enZona(x: number, z: number, margen: number): boolean
		for _, zona in disp.zonas do
			if (Vector2.new(x, z) - zona.pos).Magnitude < zona.radio + margen then
				return true
			end
		end
		return false
	end

	local function libre(x: number, z: number, margenCamino: number, margenZona: number): boolean
		if math.abs(x) > lim or math.abs(z) > lim then
			return false
		end
		if datos.distanciaCamino(x, z) < C.ANCHO_CAMINO + margenCamino then
			return false
		end
		if datos.distanciaRio(x, z) < C.ANCHO_RIO + 3 then
			return false
		end
		return not enZona(x, z, margenZona)
	end

	-- manchas de bosque más y menos tupido (arboledas), a escala de unos 200 studs
	local function densidad(x: number, z: number): number
		return 0.3 + 0.7 * Ruido.suave(-0.25, 0.25, Ruido.fbm(x * 0.005, z * 0.005, 2, ox, oz))
	end

	local function pendiente(x: number, z: number): number
		local dx = datos.altura(x + 6, z) - datos.altura(x - 6, z)
		local dz = datos.altura(x, z + 6) - datos.altura(x, z - 6)
		return math.sqrt(dx * dx + dz * dz) / 12
	end

	---------------------------------------------------------------------------------------------
	-- Claros: huecos del dosel que deja un árbol al caer. Lejos de senderos, zonas y río.
	---------------------------------------------------------------------------------------------
	type Claro = { pos: Vector2, radio: number }
	local claros: { Claro } = {}
	do
		local intentos = 0
		while #claros < V.CLAROS and intentos < V.CLAROS * 40 do
			intentos += 1
			local p = Vector2.new(rng:NextNumber(-lim, lim), rng:NextNumber(-lim, lim))
			local r = rng:NextNumber(V.CLARO_RADIO[1], V.CLARO_RADIO[2])
			local lejos = libre(p.X, p.Y, r + 12, r + 20)
				and datos.distanciaRio(p.X, p.Y) > C.ANCHO_RIO + V.RIBERA + r
				and pendiente(p.X, p.Y) < V.LADERA
			if lejos then
				for _, c in claros do
					if (c.pos - p).Magnitude < c.radio + r + 120 then
						lejos = false
						break
					end
				end
			end
			if lejos then
				table.insert(claros, { pos = p, radio = r })
			end
		end
	end

	local function claroEn(x: number, z: number): Claro?
		for _, c in claros do
			if (c.pos - Vector2.new(x, z)).Magnitude < c.radio then
				return c
			end
		end
		return nil
	end

	local function ecotopo(x: number, z: number): Ecotopo
		if datos.distanciaRio(x, z) < C.ANCHO_RIO + V.RIBERA then
			return "ribera"
		elseif claroEn(x, z) then
			return "claro"
		elseif pendiente(x, z) > V.LADERA then
			return "ladera"
		end
		return "selva"
	end

	---------------------------------------------------------------------------------------------
	-- Colocar
	---------------------------------------------------------------------------------------------
	local colocados = 0
	local total = V.ARBOLES + V.HELECHOS + V.ARBUSTOS + V.HOJAS_GRANDES + V.ROCAS + V.TRONCOS

	-- huellas físicas (nada se atraviesa) y espaciado del dosel (copas que no se pisan)
	local fisico = rejilla(24, RADIO_MAX)
	local dosel = rejilla(32, V.HITO_ESPACIO / 2)

	-- Suelo bajo toda la huella: centro y seis puntos alrededor. Devuelve el pie (el punto más
	-- bajo, para que ningún lado quede en el aire) o nil si la pendiente es excesiva o hay agua.
	local function apoyo(x: number, z: number, radio: number, pendienteMax: number): Vector3?
		local centro, mat = Kit.suelo(x, z)
		if not centro or mat == Enum.Material.Water or centro.Y < C.NIVEL_AGUA + 0.5 then
			return nil
		end
		local bajo, alto = centro.Y, centro.Y
		local r = math.max(radio * 0.8, 1.5)
		for k = 0, 5 do
			local a = k * math.pi / 3
			local p, m = Kit.suelo(x + math.cos(a) * r, z + math.sin(a) * r)
			if not p or m == Enum.Material.Water then
				return nil
			end
			bajo, alto = math.min(bajo, p.Y), math.max(alto, p.Y)
		end
		if (alto - bajo) / (2 * r) > pendienteMax then
			return nil
		end
		return Vector3.new(x, bajo - 0.15, z)
	end

	local function plantar(crear: Creador, x: number, z: number, carpeta: Instance, h: Huella?): boolean
		local huella = h or HUELLAS.planta
		if not fisico.libre(x, z, huella.radio) then
			return false
		end
		local pie = apoyo(x, z, huella.radio, huella.pendiente)
		if not pie then
			return false
		end
		crear(rng, pie, carpeta)
		fisico.ocupar(x, z, huella.radio)
		colocados += 1
		if colocados % 30 == 0 then
			progreso(math.min(colocados / total, 0.99))
			task.wait()
		end
		return true
	end

	local carpetas: { [string]: Folder } = {}
	local function carpeta(nombre: string): Folder
		local existente = carpetas[nombre]
		if existente then
			return existente
		end
		local nueva = Instance.new("Folder")
		nueva.Name = nombre
		nueva.Parent = padre
		carpetas[nombre] = nueva
		return nueva
	end

	-- Puntos donde ya hay algo, para que la capa siguiente crezca alrededor.
	local arboles: { Vector2 } = {}
	local rocas: { Vector2 } = {}
	local troncos: { Vector2 } = {}

	-- Prueba `intentos` veces un punto que devuelve `donde` y planta lo que diga `que`.
	local function sembrar(
		cantidad: number,
		donde: () -> Vector2?,
		que: (x: number, z: number) -> (Creador?, Huella?, string?),
		margenCamino: number,
		margenZona: number,
		lista: { Vector2 }?
	): number
		local hechos, intentos = 0, 0
		while hechos < cantidad and intentos < cantidad * 8 do
			intentos += 1
			local p = donde()
			if p and libre(p.X, p.Y, margenCamino, margenZona) then
				local crear, huella, nombre = que(p.X, p.Y)
				if crear and nombre and plantar(crear, p.X, p.Y, carpeta(nombre), huella) then
					hechos += 1
					if lista then
						table.insert(lista, p)
					end
				end
			end
		end
		return hechos
	end

	local function alAzar(): Vector2?
		return Vector2.new(rng:NextNumber(-lim, lim), rng:NextNumber(-lim, lim))
	end

	-- Un punto a una distancia entre rMin y rMax de algún punto de `centros`.
	local function alrededor(centros: { Vector2 }, rMin: number, rMax: number): () -> Vector2?
		return function(): Vector2?
			if #centros == 0 then
				return nil
			end
			local c = Kit.elegir(rng, centros)
			local a = rng:NextNumber(0, math.pi * 2)
			return c + Vector2.new(math.cos(a), math.sin(a)) * rng:NextNumber(rMin, rMax)
		end
	end

	-- Un punto junto a un sendero (a un lado o al otro) o en el anillo exterior de una zona.
	local function borde(dMin: number, dMax: number, zonas: boolean): () -> Vector2?
		return function(): Vector2?
			if zonas and rng:NextNumber() < 0.3 then
				local zona = Kit.elegir(rng, disp.zonas)
				local a = rng:NextNumber(0, math.pi * 2)
				return zona.pos + Vector2.new(math.cos(a), math.sin(a)) * (zona.radio + rng:NextNumber(dMin, dMax))
			end
			local cam = Kit.elegir(rng, disp.caminos)
			local k = rng:NextInteger(2, #cam.puntos - 1)
			local dir = cam.puntos[k + 1] - cam.puntos[k - 1]
			if dir.Magnitude < 1e-3 then
				return nil
			end
			local lado = if rng:NextNumber() < 0.5 then -1 else 1
			local perp = Vector2.new(-dir.Y, dir.X).Unit * lado
			return cam.puntos[k] + perp * (C.ANCHO_CAMINO + rng:NextNumber(dMin, dMax))
		end
	end

	-- Envuelve un creador para que, al plantarse de verdad, reserve su sitio en el dosel.
	local function enDosel(crear: Creador, espacio: number): Creador
		return function(r: Random, pie: Vector3, c: Instance): Model
			dosel.ocupar(pie.X, pie.Z, espacio / 2)
			return crear(r, pie, c)
		end
	end

	-- Árbol del dosel según el ecotopo, respetando la distancia mínima entre copas.
	local function arbolDe(x: number, z: number): (Creador?, Huella?, string?)
		local eco = ecotopo(x, z)
		if eco == "claro" then
			return nil
		end
		local espacio = (V.ESPACIO :: any)[eco] :: number
		if not dosel.libre(x, z, espacio / 2) or rng:NextNumber() > densidad(x, z) + 0.15 then
			return nil
		end
		local r = rng:NextNumber()
		if eco == "ribera" then
			if r < 0.7 then
				return enDosel(Vegetacion.palmera, espacio), HUELLAS.palmera, "Arboles"
			end
			return enDosel(Vegetacion.arbol, espacio), HUELLAS.arbol, "Arboles"
		elseif eco == "ladera" then
			if r < 0.4 then
				return enDosel(Vegetacion.seco, espacio), HUELLAS.palmera, "Arboles"
			end
			return enDosel(Vegetacion.arbol, espacio), HUELLAS.arbol, "Arboles"
		end
		if r < 0.8 then
			return enDosel(Vegetacion.arbol, espacio), HUELLAS.arbol, "Arboles"
		elseif r < 0.95 then
			return enDosel(Vegetacion.palmera, espacio), HUELLAS.palmera, "Arboles"
		end
		return enDosel(Vegetacion.seco, espacio), HUELLAS.palmera, "Arboles"
	end

	---------------------------------------------------------------------------------------------
	-- 1. Hitos: ceibas emergentes. Una junto a cada zona y otras a lo largo de los senderos,
	-- a un lado y a la vista: el jugador las ve por encima del dosel y camina hacia ellas.
	---------------------------------------------------------------------------------------------
	local function ceiba(p: Vector2): boolean
		if not dosel.libre(p.X, p.Y, V.HITO_ESPACIO / 2) then
			return false
		end
		if plantar(Vegetacion.ceiba, p.X, p.Y, carpeta("Arboles"), HUELLAS.ceiba) then
			dosel.ocupar(p.X, p.Y, V.HITO_ESPACIO / 2)
			table.insert(arboles, p)
			return true
		end
		return false
	end
	for _, zona in disp.zonas do
		for _ = 1, 12 do
			local a = rng:NextNumber(0, math.pi * 2)
			local p = zona.pos + Vector2.new(math.cos(a), math.sin(a)) * (zona.radio + rng:NextNumber(28, 46))
			if libre(p.X, p.Y, 16, 20) and ceiba(p) then
				break
			end
		end
	end
	for _, cam in disp.caminos do
		local largo = 0
		for k = 2, #cam.puntos do
			largo += (cam.puntos[k] - cam.puntos[k - 1]).Magnitude
			if largo >= V.HITO_SENDERO and k < #cam.puntos then
				local dir = cam.puntos[k + 1] - cam.puntos[k - 1]
				if dir.Magnitude > 1e-3 then
					local lado = if rng:NextNumber() < 0.5 then -1 else 1
					local p = cam.puntos[k] + Vector2.new(-dir.Y, dir.X).Unit * lado * rng:NextNumber(30, 45)
					if libre(p.X, p.Y, 16, 20) and ceiba(p) then
						largo = 0
					end
				end
			end
		end
	end

	---------------------------------------------------------------------------------------------
	-- 2. Dosel: árboles que enmarcan los senderos, luego el resto por ecotopo.
	---------------------------------------------------------------------------------------------
	local arbolesHechos = #arboles
	for _, cam in disp.caminos do
		local largo, lado = 0, 1
		for k = 2, #cam.puntos - 1 do
			largo += (cam.puntos[k] - cam.puntos[k - 1]).Magnitude
			if largo >= V.CORREDOR then
				largo = rng:NextNumber(-6, 6)
				lado = -lado
				local dir = cam.puntos[k + 1] - cam.puntos[k - 1]
				if dir.Magnitude > 1e-3 then
					local p = cam.puntos[k]
						+ Vector2.new(-dir.Y, dir.X).Unit * lado * (C.ANCHO_CAMINO + rng:NextNumber(9, 14))
					if libre(p.X, p.Y, 8, 6) then
						local crear, huella, nombre = arbolDe(p.X, p.Y)
						if crear and nombre and plantar(crear, p.X, p.Y, carpeta(nombre), huella) then
							table.insert(arboles, p)
							arbolesHechos += 1
						end
					end
				end
			end
		end
	end
	arbolesHechos += sembrar(V.ARBOLES - arbolesHechos, alAzar, arbolDe, 11, -4, arboles)

	---------------------------------------------------------------------------------------------
	-- 3. Rocas: peñascos donde el suelo se empina y grupos de una grande con varias pequeñas.
	---------------------------------------------------------------------------------------------
	sembrar(V.ROCAS_GRANDES, alAzar, function(x, z)
		local eco = ecotopo(x, z)
		if eco == "claro" or eco == "ribera" or (eco == "selva" and rng:NextNumber() < 0.75) then
			return nil
		end
		return Vegetacion.rocaGrande, HUELLAS.penasco, "RocasGrandes"
	end, 24, 18, rocas)

	local pequenas = V.ROCAS - V.ROCAS_GRANDES
	local grupos: { Vector2 } = {}
	sembrar(math.ceil(pequenas / 3.5), alAzar, function(x, z)
		local eco = ecotopo(x, z)
		local prob = if eco == "ladera" then 1 elseif eco == "ribera" then 0.4 elseif eco == "selva" then 0.3 else 0
		if rng:NextNumber() > prob then
			return nil
		end
		return Vegetacion.roca, HUELLAS.roca, "Rocas"
	end, 6, 2, grupos)
	for _, g in grupos do
		table.insert(rocas, g)
	end
	sembrar(pequenas - #grupos, alrededor(grupos, 7, 14), function()
		return Vegetacion.roca, HUELLAS.roca, "Rocas"
	end, 6, 2, rocas)

	---------------------------------------------------------------------------------------------
	-- 4. Troncos caídos: el que abrió cada claro y otros junto a árboles en pie.
	---------------------------------------------------------------------------------------------
	local troncosHechos = 0
	for _, c in claros do
		for _ = 1, 6 do
			local p = c.pos + Vector2.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4))
			if plantar(Vegetacion.tronco, p.X, p.Y, carpeta("Troncos"), HUELLAS.tronco) then
				table.insert(troncos, p)
				troncosHechos += 1
				break
			end
		end
	end
	sembrar(V.TRONCOS - troncosHechos, alrededor(arboles, 10, 18), function(x, z)
		if ecotopo(x, z) == "ribera" then
			return nil
		end
		return Vegetacion.tronco, HUELLAS.tronco, "Troncos"
	end, 4, 0, troncos)

	---------------------------------------------------------------------------------------------
	-- 5. Sotobosque. Más denso en los bordes (sendero, zona, claro), donde entra la luz.
	---------------------------------------------------------------------------------------------
	local bordesClaros: { Vector2 } = {}
	for _, c in claros do
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			table.insert(bordesClaros, c.pos + Vector2.new(math.cos(a), math.sin(a)) * c.radio)
		end
	end

	local function fijo(crear: Creador, huella: Huella, nombre: string)
		return function(): (Creador?, Huella?, string?)
			return crear, huella, nombre
		end
	end
	local arbusto = fijo(Vegetacion.arbusto, HUELLAS.arbusto, "Arbustos")
	local hoja = fijo(Vegetacion.hojaGrande, HUELLAS.arbusto, "HojasGrandes")
	local helecho = fijo(Vegetacion.helecho, HUELLAS.planta, "Helechos")
	local helechoSuelto = fijo(Vegetacion.helecho, HUELLAS.planta, "HelechosSueltos")

	-- arbustos: al pie de los árboles, muros en los bordes, el anillo de los claros y sueltos
	local a = V.ARBUSTOS
	sembrar(math.floor(a * 0.35), alrededor(arboles, 5, 12), arbusto, 2, -10)
	sembrar(math.floor(a * 0.3), borde(2, 10, true), arbusto, 1.5, -12)
	sembrar(math.floor(a * 0.15), alrededor(bordesClaros, 0, 6), arbusto, 2, -10)
	sembrar(a - math.floor(a * 0.35) - math.floor(a * 0.3) - math.floor(a * 0.15), alAzar, function(x, z)
		if ecotopo(x, z) == "claro" or rng:NextNumber() > densidad(x, z) then
			return nil
		end
		return Vegetacion.arbusto, HUELLAS.arbusto, "Arbustos"
	end, 2, -10)

	-- hojas grandes: sobre todo en la ribera húmeda, también en bordes y al pie de los árboles
	local h = V.HOJAS_GRANDES
	sembrar(math.floor(h * 0.5), alAzar, function(x, z)
		if ecotopo(x, z) ~= "ribera" then
			return nil
		end
		return Vegetacion.hojaGrande, HUELLAS.arbusto, "HojasGrandes"
	end, 1.5, -12)
	sembrar(math.floor(h * 0.25), borde(1.5, 7, false), hoja, 1.5, -12)
	sembrar(h - math.floor(h * 0.5) - math.floor(h * 0.25), alrededor(arboles, 4, 9), hoja, 1.5, -12)

	-- helechos: bordeando los senderos, abrazando rocas y troncos, al pie de los árboles y sueltos
	local f = V.HELECHOS
	sembrar(math.floor(f * 0.3), borde(1.5, 8, false), helecho, 1, -14)
	local apoyos: { Vector2 } = table.clone(rocas)
	table.move(troncos, 1, #troncos, #apoyos + 1, apoyos)
	sembrar(math.floor(f * 0.2), alrededor(apoyos, 4, 10), helecho, 1, -14)
	sembrar(math.floor(f * 0.25), alrededor(arboles, 3, 9), helechoSuelto, 1, -14)
	sembrar(f - math.floor(f * 0.3) - math.floor(f * 0.2) - math.floor(f * 0.25), alAzar, function(x, z)
		if rng:NextNumber() > densidad(x, z) then
			return nil
		end
		return Vegetacion.helecho, HUELLAS.planta, "HelechosSueltos"
	end, 1, -14)

	-- rocas de orilla: asoman del agua, a la altura del lecho
	local orillas = carpeta("RocasOrilla")
	for _ = 1, 50 do
		local p = Kit.elegir(rng, disp.rio)
		local ang = rng:NextNumber(0, math.pi * 2)
		local pos = p + Vector2.new(math.cos(ang), math.sin(ang)) * (C.ANCHO_RIO + rng:NextNumber(1, 8))
		if
			datos.distanciaCamino(pos.X, pos.Y) > C.ANCHO_CAMINO + 4 and fisico.libre(pos.X, pos.Y, HUELLAS.roca.radio)
		then
			Vegetacion.roca(rng, Vector3.new(pos.X, datos.altura(pos.X, pos.Y), pos.Y), orillas)
			fisico.ocupar(pos.X, pos.Y, HUELLAS.roca.radio)
		end
	end

	-- para depurar: la carpeta guarda dónde quedaron los claros
	padre:SetAttribute("Claros", #claros)
	progreso(1)
end

return Dispersion
