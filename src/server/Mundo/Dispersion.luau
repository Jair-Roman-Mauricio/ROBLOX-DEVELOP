--!strict
--[[
	Reparte la vegetación: densa en manchas (máscara de ruido), sin pisar senderos, río ni
	el interior de las zonas, y con helechos que enmarcan los senderos.
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

local Dispersion = {}

function Dispersion.poblar(
	rng: Random,
	disp: Disposicion.Disposicion,
	datos: Terreno.Datos,
	padre: Instance,
	progreso: (number) -> ()
)
	local ox, oz = rng:NextNumber(-500, 500), rng:NextNumber(-500, 500)

	local function libre(x: number, z: number, margenCamino: number, margenZona: number): boolean
		if datos.distanciaCamino(x, z) < C.ANCHO_CAMINO + margenCamino then
			return false
		end
		if datos.distanciaRio(x, z) < C.ANCHO_RIO + 3 then
			return false
		end
		for _, zona in disp.zonas do
			if (Vector2.new(x, z) - zona.pos).Magnitude < zona.radio + margenZona then
				return false
			end
		end
		return true
	end

	local function densidad(x: number, z: number): number
		return 0.3 + 0.7 * Ruido.suave(-0.25, 0.25, Ruido.fbm(x * 0.005, z * 0.005, 2, ox, oz))
	end

	local colocados = 0
	local total = V.ARBOLES + V.HELECHOS + V.ARBUSTOS + V.HOJAS_GRANDES + V.ROCAS + V.TRONCOS

	-- Huella ocupada por cada objeto colocado, en una rejilla de celdas: dos objetos no se
	-- colocan a menos de la suma de sus radios (troncos, rocas y plantas no se atraviesan).
	local CELDA_OCUPADA = 24
	local ocupadas: { [number]: { vector } } = {}
	local function clave(cx: number, cz: number): number
		return cx * 4096 + cz
	end
	local function libreDeOtros(x: number, z: number, radio: number): boolean
		local cx, cz = x // CELDA_OCUPADA, z // CELDA_OCUPADA
		local alcance = math.ceil((radio + RADIO_MAX) / CELDA_OCUPADA)
		for i = cx - alcance, cx + alcance do
			for j = cz - alcance, cz + alcance do
				local lista = ocupadas[clave(i, j)]
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
	end
	local function ocupar(x: number, z: number, radio: number)
		local k = clave(x // CELDA_OCUPADA, z // CELDA_OCUPADA)
		local lista = ocupadas[k]
		if not lista then
			lista = {}
			ocupadas[k] = lista
		end
		table.insert(lista, vector.create(x, radio, z))
	end

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
		if not libreDeOtros(x, z, huella.radio) then
			return false
		end
		local pie = apoyo(x, z, huella.radio, huella.pendiente)
		if not pie then
			return false
		end
		crear(rng, pie, carpeta)
		ocupar(x, z, huella.radio)
		colocados += 1
		if colocados % 30 == 0 then
			progreso(colocados / total)
			task.wait()
		end
		return true
	end

	local function repartir(
		nombre: string,
		cantidad: number,
		margenCamino: number,
		margenZona: number,
		elegir: () -> (Creador, Huella?)
	)
		local carpeta = Instance.new("Folder")
		carpeta.Name = nombre
		carpeta.Parent = padre
		local hechos, intentos = 0, 0
		local lim = MITAD - 20
		while hechos < cantidad and intentos < cantidad * 10 do
			intentos += 1
			local x, z = rng:NextNumber(-lim, lim), rng:NextNumber(-lim, lim)
			if libre(x, z, margenCamino, margenZona) and rng:NextNumber() < densidad(x, z) then
				local crear, huella = elegir()
				if plantar(crear, x, z, carpeta, huella) then
					hechos += 1
				end
			end
		end
	end

	local function arbol(): (Creador, Huella?)
		local r = rng:NextNumber()
		if r < V.CEIBAS then
			return Vegetacion.ceiba, HUELLAS.ceiba
		elseif r < 0.5 then
			return Vegetacion.arbol, HUELLAS.arbol
		elseif r < 0.88 then
			return Vegetacion.palmera, HUELLAS.palmera
		end
		return Vegetacion.seco, HUELLAS.palmera
	end

	repartir("Arboles", V.ARBOLES, 11, -4, arbol)
	-- los peñascos van primero y lejos de senderos y zonas: miden hasta 36 studs
	repartir("RocasGrandes", V.ROCAS_GRANDES, 24, 18, function()
		return Vegetacion.rocaGrande, HUELLAS.penasco
	end)
	repartir("Rocas", V.ROCAS - V.ROCAS_GRANDES, 6, 2, function()
		return Vegetacion.roca, HUELLAS.roca
	end)
	repartir("Troncos", V.TRONCOS, 4, 0, function()
		return Vegetacion.tronco, HUELLAS.tronco
	end)
	repartir("Arbustos", V.ARBUSTOS, 2, -10, function()
		return Vegetacion.arbusto, HUELLAS.arbusto
	end)
	repartir("HojasGrandes", V.HOJAS_GRANDES, 1.5, -12, function()
		return Vegetacion.hojaGrande, HUELLAS.arbusto
	end)

	-- helechos: la mitad bordea los senderos, el resto suelto
	local helechos = Instance.new("Folder")
	helechos.Name = "Helechos"
	helechos.Parent = padre
	local bordes = math.floor(V.HELECHOS * 0.5)
	local hechos, intentos = 0, 0
	while hechos < bordes and intentos < bordes * 6 do
		intentos += 1
		local cam = Kit.elegir(rng, disp.caminos)
		local k = rng:NextInteger(2, #cam.puntos - 1)
		local p, q = cam.puntos[k - 1], cam.puntos[k + 1]
		local dir = (q - p)
		if dir.Magnitude > 0 then
			local perp = Vector2.new(-dir.Y, dir.X).Unit * (if rng:NextNumber() < 0.5 then -1 else 1)
			local pos = cam.puntos[k] + perp * rng:NextNumber(C.ANCHO_CAMINO + 1.5, C.ANCHO_CAMINO + 8)
			if
				datos.distanciaCamino(pos.X, pos.Y) > C.ANCHO_CAMINO + 1
				and datos.distanciaRio(pos.X, pos.Y) > C.ANCHO_RIO + 2
			then
				if plantar(Vegetacion.helecho, pos.X, pos.Y, helechos) then
					hechos += 1
				end
			end
		end
	end
	repartir("HelechosSueltos", V.HELECHOS - bordes, 1, -14, function()
		return Vegetacion.helecho, HUELLAS.planta
	end)

	-- rocas de orilla
	local orillas = Instance.new("Folder")
	orillas.Name = "RocasOrilla"
	orillas.Parent = padre
	for _ = 1, 50 do
		local p = Kit.elegir(rng, disp.rio)
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = p + Vector2.new(math.cos(a), math.sin(a)) * (C.ANCHO_RIO + rng:NextNumber(1, 8))
		if datos.distanciaCamino(pos.X, pos.Y) > C.ANCHO_CAMINO + 4 then
			-- altura del lecho, no el raycast: así las rocas asoman del agua en vez de flotar
			if libreDeOtros(pos.X, pos.Y, HUELLAS.roca.radio) then
				Vegetacion.roca(rng, Vector3.new(pos.X, datos.altura(pos.X, pos.Y), pos.Y), orillas)
				ocupar(pos.X, pos.Y, HUELLAS.roca.radio)
			end
		end
	end
	progreso(1)
end

return Dispersion
