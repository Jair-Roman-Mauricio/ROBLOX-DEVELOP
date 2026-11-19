--!strict
--[[
	Genera una selva completa a partir de una semilla:
	  1. disposición (grafo de zonas, río, senderos)
	  2. terreno calculado en memoria
	  3. validación de accesibilidad; si falla se prueba otra semilla
	  4. escritura del terreno, puentes, zonas, culto, vegetación y detalles

	Lagos y arroyos tienen su propio nivel de agua: un cruce se detecta comparando con
	datos.nivelAgua, y los cruces cortos (arroyos) se pasan por un tronco caído.

	Validación (CONTEXT.md: "el generador debe producir una ruta válida"):
	  - ningún sendero empieza o termina en el agua
	  - cada cruce de agua cabe en un puente (<= PUENTE_MAX)
	  - fuera de los puentes, el desnivel entre muestras de sendero es caminable
	Como la ruta A-B-C-D-E-F siempre existe, si todos los senderos pasan, todo es alcanzable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogo = require(script.Parent.Parent.Modelos.CatalogoVegetacion)

local Config = require(ReplicatedStorage.Shared.Config)
local Atmosfera = require(script.Parent.Parent.Modelos.Atmosfera)
local Culto = require(script.Parent.Parent.Modelos.Culto)
local Detalles = require(script.Parent.Detalles)
local Agua = require(script.Parent.Parent.Agua)
local Disposicion = require(script.Parent.Disposicion)
local Dispersion = require(script.Parent.Dispersion)
local Fauna = require(script.Parent.Parent.Fauna)
local Terreno = require(script.Parent.Terreno)
local Zonas = require(script.Parent.Zonas)
local Estructuras = require(script.Parent.Parent.Modelos.Estructuras)
local Kit = require(script.Parent.Parent.Modelos.Kit)

local C = Config.Mapa

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
	-- alturas del terreno tal como se generó y el grafo de zonas (los usa la serpiente)
	datos: Terreno.Datos,
	disposicion: Disposicion.Disposicion,
}

type Puente = { desde: Vector3, hasta: Vector3, nivel: number }

local Generador = {}

local function validar(disp: Disposicion.Disposicion, datos: Terreno.Datos): (boolean, string?, { Puente })
	local puentes: { Puente } = {}
	for _, cam in disp.caminos do
		local pts = cam.puntos
		local enAgua = false
		local inicio = 1
		local nivel = 0
		local anteriorSeco = true
		local hAnterior = datos.altura(pts[1].X, pts[1].Y)
		for i, p in pts do
			local h = datos.altura(p.X, p.Y)
			local agua = datos.nivelAgua(p.X, p.Y)
			-- el borde mismo del cauce cuenta como agua: el puente o tronco lo salva
			local seco = h >= agua + 1 and datos.distanciaAgua(p.X, p.Y) > 4
			if not seco and not enAgua then
				if i == 1 then
					return false, ("el sendero %s-%s empieza en el agua"):format(cam.a, cam.b), puentes
				end
				enAgua, inicio, nivel = true, i - 1, agua
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
					nivel = nivel,
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
	-- cada lado va en tramos: una parte no puede medir más de 2048 studs
	local m = C.TAMANO / 2
	local tramos = math.ceil(C.TAMANO / 1024)
	local largo = C.TAMANO / tramos
	for k = 1, tramos do
		local o = -m + (k - 0.5) * largo
		for _, d in
			{
				{ Vector3.new(m, 300, o), Vector3.new(4, 900, largo) },
				{ Vector3.new(-m, 300, o), Vector3.new(4, 900, largo) },
				{ Vector3.new(o, 300, m), Vector3.new(largo, 900, 4) },
				{ Vector3.new(o, 300, -m), Vector3.new(largo, 900, 4) },
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
end

function Generador.generar(semilla: number, padre: Instance, progreso: (number, string) -> ()): Mundo
	progreso(0, "Cargando vegetación de Creator Store")
	Catalogo.preparar()
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
	Terreno.estilo()
	limites(carpeta)

	local rng = Random.new(semilla + 1)
	local carpetaPuentes = Instance.new("Folder")
	carpetaPuentes.Name = "Puentes"
	carpetaPuentes.Parent = carpeta
	for _, p in puentes do
		if (p.hasta - p.desde).Magnitude <= C.Agua.TRONCO_MAX then
			Estructuras.troncoPuente(rng, p.desde, p.hasta, carpetaPuentes)
		else
			Estructuras.puente(rng, p.desde, p.hasta, p.nivel, carpetaPuentes)
		end
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
			local lago: Disposicion.Lago? = nil
			if z.estilo == "palafitos" then
				for _, l in disp.lagos do
					if l.tipo == "pantano" then
						lago = l
					end
				end
			end
			modelo = Zonas.pueblo(rng, centro, z, datos, carpetaZonas, lago)
		elseif z.tipo == "templo" then
			modelo = Zonas.templo(rng, centro, disp.porId.F.pos - z.pos, datos, carpetaZonas)
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

	-- el culto: santuarios junto a los senderos, mirando al sendero; y la cascada
	local carpetaCulto = Instance.new("Folder")
	carpetaCulto.Name = "Culto"
	carpetaCulto.Parent = carpeta
	for _, s in disp.santuarios do
		local p = Kit.suelo(s.pos.X, s.pos.Y) or Vector3.new(s.pos.X, datos.altura(s.pos.X, s.pos.Y), s.pos.Y)
		Culto.santuario(rng, CFrame.lookAt(p, p + Vector3.new(s.frente.X, 0, s.frente.Y)), carpetaCulto)
	end
	for _, l in disp.lagos do
		if l.tipo == "cascada" then
			local fuera = Vector3.new(l.fuera.X, 0, l.fuera.Y)
			local pie = Vector3.new(l.centro.X, l.nivel, l.centro.Y) + fuera * (l.radio + 1)
			Atmosfera.cascada(carpetaCulto, pie, fuera, C.Agua.CASCADA_ALTO, rng)
		end
	end

	progreso(0.6, "Haciendo crecer la vegetación")
	local carpetaVeg = Instance.new("Folder")
	carpetaVeg.Name = "Vegetacion"
	carpetaVeg.Parent = carpeta
	local claros = Dispersion.poblar(rng, disp, datos, carpetaVeg, function(f)
		progreso(0.6 + f * 0.35, "Haciendo crecer la vegetación")
	end)

	progreso(0.95, "Despertando la selva")
	Detalles.decorar(rng, disp, datos, carpeta, carpetaVeg, claros)
	Agua.preparar(rng, disp, carpeta)

	Fauna.poblar(rng, zonas, carpeta)

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
		datos = datos,
		disposicion = disp,
	}
end

return Generador
