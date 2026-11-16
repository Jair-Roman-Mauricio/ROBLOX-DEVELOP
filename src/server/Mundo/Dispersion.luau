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

	local function plantar(crear: Creador, x: number, z: number, carpeta: Instance): boolean
		local p, mat = Kit.suelo(x, z)
		if not p or mat == Enum.Material.Water or p.Y < C.NIVEL_AGUA + 0.5 then
			return false
		end
		crear(rng, p, carpeta)
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
		elegir: () -> Creador
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
				if plantar(elegir(), x, z, carpeta) then
					hechos += 1
				end
			end
		end
	end

	local function arbol(): Creador
		local r = rng:NextNumber()
		if r < 0.07 then
			return Vegetacion.ceiba
		elseif r < 0.5 then
			return Vegetacion.arbol
		elseif r < 0.88 then
			return Vegetacion.palmera
		end
		return Vegetacion.seco
	end

	repartir("Arboles", V.ARBOLES, 7, -4, arbol)
	-- los peñascos van primero y lejos de senderos y zonas: miden hasta 36 studs
	repartir("RocasGrandes", V.ROCAS_GRANDES, 24, 18, function()
		return Vegetacion.rocaGrande
	end)
	repartir("Rocas", V.ROCAS - V.ROCAS_GRANDES, 6, 2, function()
		return Vegetacion.roca
	end)
	repartir("Troncos", V.TRONCOS, 4, 0, function()
		return Vegetacion.tronco
	end)
	repartir("Arbustos", V.ARBUSTOS, 2, -10, function()
		return Vegetacion.arbusto
	end)
	repartir("HojasGrandes", V.HOJAS_GRANDES, 1.5, -12, function()
		return Vegetacion.hojaGrande
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
		return Vegetacion.helecho
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
			Vegetacion.roca(rng, Vector3.new(pos.X, datos.altura(pos.X, pos.Y), pos.Y), orillas)
		end
	end
	progreso(1)
end

return Dispersion
