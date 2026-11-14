--!strict
--[[
	Genera una selva completa a partir de una semilla:
	  1. disposición (grafo de zonas, río, senderos)
	  2. terreno calculado en memoria
	  3. validación de accesibilidad; si falla se prueba otra semilla
	  4. escritura del terreno, puentes, zonas y vegetación

	Validación (CONTEXT.md: "el generador debe producir una ruta válida"):
	  - ningún sendero empieza o termina en el agua
	  - cada cruce de agua cabe en un puente (<= PUENTE_MAX)
	  - fuera de los puentes, el desnivel entre muestras de sendero es caminable
	Como la ruta A-B-C-D-E-F siempre existe, si todos los senderos pasan, todo es alcanzable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Disposicion = require(script.Parent.Disposicion)
local Dispersion = require(script.Parent.Dispersion)
local Terreno = require(script.Parent.Terreno)
local Zonas = require(script.Parent.Zonas)
local Estructuras = require(script.Parent.Parent.Modelos.Estructuras)
local Kit = require(script.Parent.Parent.Modelos.Kit)

local C = Config.Mapa
local AGUA = C.NIVEL_AGUA

export type ZonaMundo = {
	id: string,
	tipo: string,
	nombre: string,
	centro: Vector3,
	radio: number,
}

export type Mundo = {
	semilla: number,
	carpeta: Folder,
	zonas: { ZonaMundo },
	spawns: { Vector3 },
	mirarInicio: Vector3,
}

type Puente = { desde: Vector3, hasta: Vector3 }

local Generador = {}

local function validar(disp: Disposicion.Disposicion, datos: Terreno.Datos): (boolean, string?, { Puente })
	local puentes: { Puente } = {}
	for _, cam in disp.caminos do
		local pts = cam.puntos
		local enAgua = false
		local inicio = 1
		local anteriorSeco = true
		local hAnterior = datos.altura(pts[1].X, pts[1].Y)
		for i, p in pts do
			local h = datos.altura(p.X, p.Y)
			local seco = h >= AGUA + 1
			if not seco and not enAgua then
				if i == 1 then
					return false, ("el sendero %s-%s empieza en el agua"):format(cam.a, cam.b), puentes
				end
				enAgua, inicio = true, i - 1
			elseif seco and enAgua then
				enAgua = false
				local a = pts[inicio]
				local largo = (p - a).Magnitude
				if largo > C.PUENTE_MAX then
					return false, ("cruce de %d studs en %s-%s"):format(math.floor(largo), cam.a, cam.b), puentes
				end
				table.insert(puentes, {
					desde = Vector3.new(a.X, datos.altura(a.X, a.Y), a.Y),
					hasta = Vector3.new(p.X, h, p.Y),
				})
			elseif seco and anteriorSeco and i > 1 and math.abs(h - hAnterior) > 3.2 then
				return false, ("pendiente excesiva en %s-%s"):format(cam.a, cam.b), puentes
			end
			anteriorSeco = seco
			hAnterior = h
		end
		if enAgua then
			return false, ("el sendero %s-%s termina en el agua"):format(cam.a, cam.b), puentes
		end
	end
	return true, nil, puentes
end

-- Paredes invisibles en el borde para que nadie salga del mapa siguiendo el río.
local function limites(padre: Instance)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Limites"
	carpeta.Parent = padre
	local m = C.TAMANO / 2
	for _, d in
		{
			{ Vector3.new(m, 150, 0), Vector3.new(4, 600, C.TAMANO) },
			{ Vector3.new(-m, 150, 0), Vector3.new(4, 600, C.TAMANO) },
			{ Vector3.new(0, 150, m), Vector3.new(C.TAMANO, 600, 4) },
			{ Vector3.new(0, 150, -m), Vector3.new(C.TAMANO, 600, 4) },
		}
	do
		Kit.parte(carpeta, CFrame.new(d[1]), d[2], Color3.new(), Enum.Material.SmoothPlastic, {
			transparencia = 1,
			sombra = false,
			consulta = false,
			nombre = "Pared",
		})
	end
end

function Generador.generar(semilla: number, padre: Instance, progreso: (number, string) -> ()): Mundo
	progreso(0, "Trazando la selva")
	local disp: Disposicion.Disposicion? = nil
	local datos: Terreno.Datos? = nil
	local puentes: { Puente } = {}
	for _ = 1, C.INTENTOS do
		local rng = Random.new(semilla)
		local d, motivo = Disposicion.generar(rng)
		if d then
			local t = Terreno.calcular(d, rng, semilla)
			local ok, motivoValidacion, p = validar(d, t)
			if ok then
				disp, datos, puentes = d, t, p
				break
			end
			motivo = motivoValidacion
		end
		warn(("[Selva] semilla %d descartada: %s"):format(semilla, motivo or "?"))
		semilla += 7919
		task.wait()
	end
	assert(disp and datos, "[Selva] no se encontró una semilla válida")
	print(
		("[Selva] semilla %d (espejo: %s, %d senderos, %d puentes)"):format(
			semilla,
			tostring(disp.espejo),
			#disp.caminos,
			#puentes
		)
	)

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Selva"
	carpeta:SetAttribute("Semilla", semilla)
	carpeta.Parent = padre

	Terreno.escribir(datos, function(f)
		progreso(0.05 + f * 0.45, "Esculpiendo el terreno")
	end)
	limites(carpeta)

	local rng = Random.new(semilla + 1)
	local carpetaPuentes = Instance.new("Folder")
	carpetaPuentes.Name = "Puentes"
	carpetaPuentes.Parent = carpeta
	for _, p in puentes do
		Estructuras.puente(rng, p.desde, p.hasta, AGUA, carpetaPuentes)
	end

	progreso(0.55, "Levantando los pueblos")
	local zonas: { ZonaMundo } = {}
	local spawns: { Vector3 } = {}
	local carpetaZonas = Instance.new("Folder")
	carpetaZonas.Name = "Zonas"
	carpetaZonas.Parent = carpeta
	for _, z in disp.zonas do
		local centro = Kit.suelo(z.pos.X, z.pos.Y) or Vector3.new(z.pos.X, z.altura, z.pos.Y)
		local modelo: Model
		if z.tipo == "pueblo" then
			modelo = Zonas.pueblo(rng, centro, z.radio, datos, carpetaZonas)
		elseif z.tipo == "inicio" then
			modelo, spawns = Zonas.inicio(rng, centro, datos, carpetaZonas)
		elseif z.tipo == "helicoptero" then
			modelo = Zonas.helicoptero(rng, centro, datos, carpetaZonas)
		else
			modelo = Zonas.salida(rng, centro, z.pos.Unit, datos, carpetaZonas)
		end
		modelo.Name = ("%s_%s"):format(z.id, modelo.Name)
		modelo:SetAttribute("Zona", z.id)
		modelo:SetAttribute("Tipo", z.tipo)
		modelo:SetAttribute("Radio", z.radio)
		table.insert(zonas, { id = z.id, tipo = z.tipo, nombre = z.nombre, centro = centro, radio = z.radio })
		task.wait()
	end

	progreso(0.6, "Haciendo crecer la vegetación")
	local carpetaVeg = Instance.new("Folder")
	carpetaVeg.Name = "Vegetacion"
	carpetaVeg.Parent = carpeta
	Dispersion.poblar(rng, disp, datos, carpetaVeg, function(f)
		progreso(0.6 + f * 0.4, "Haciendo crecer la vegetación")
	end)

	-- los jugadores aparecen mirando hacia el primer pueblo
	local a, b = disp.porId.A.pos, disp.porId.B.pos
	local mirar = Vector3.new(b.X - a.X, 0, b.Y - a.Y).Unit

	progreso(1, "Lista")
	return {
		semilla = semilla,
		carpeta = carpeta,
		zonas = zonas,
		spawns = spawns,
		mirarInicio = mirar,
	}
end

return Generador
