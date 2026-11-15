--!strict
--[[
	Fauna con comportamiento, en el servidor (autoritativo). De momento, jaguares.

	PROPUESTA: CONTEXT.md deja abierto el catálogo de amenazas. Todo se ajusta o se apaga en
	Config.Fauna (JAGUARES = 0 los quita).

	Estados del jaguar (baúl: Horror Monster Chase AI End to End, NPC AI and Behaviour):
	  Merodea  → pasea por su territorio con pausas.
	  Acecha   → te vio: se acerca despacio y los ojos se le encienden en rojo.
	  Agazapa  → aviso legible antes de saltar: se agacha un instante.
	  Embiste  → carrera corta y muy rápida; si te alcanza, muerde.
	  Persigue → tras la embestida va más lento que un jugador caminando: se le puede dejar atrás.
	  Huye     → ahuyentado (CONTEXT.md: evadir o ahuyentar con comportamientos): ir en grupo
	             o plantarle cara un momento mientras acecha.
	  Vuelve   → regresa a su territorio.

	Reglas confirmadas que respeta:
	  · Los pueblos son zonas protegidas: no entra ni ataca dentro (el claro inicial, tampoco).
	  · La muerte se atribuye al animal: marca el personaje con UltimoAtacante / UltimoAtaqueEn
	    y Partida muestra "Eliminado por Jaguar".

	Movimiento sin PathfindingService: paso recto pegado al terreno, sin cruzar agua ni entrar
	en zonas protegidas (baúl: NPC AI and Behaviour §6). Piensa a 5 Hz y solo con jugadores
	cerca (§7). Atraviesa los troncos: la esquiva de árboles queda pendiente.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Modelos.Kit)
local Animales = require(script.Parent.Modelos.Animales)

local J = Config.Fauna.JAGUAR
local A = J.AHUYENTAR
local AGUA = Config.Mapa.NIVEL_AGUA
local MITAD = Config.Mapa.TAMANO / 2
local ALTURA = Animales.ALTURA_JAGUAR
local PERIODO = 0.2 -- 5 Hz
local CONO = math.cos(math.rad(J.CONO))
local ENCARAR = math.cos(math.rad(A.ENCARAR_ANGULO))
local OJO_CALMA = Color3.fromRGB(255, 214, 90)
local OJO_CAZA = Color3.fromRGB(255, 60, 36)

type Estado = "Merodea" | "Acecha" | "Agazapa" | "Embiste" | "Persigue" | "Huye" | "Vuelve"

type Jaguar = {
	modelo: Model,
	raiz: BasePart,
	ojos: { BasePart },
	casa: Vector3,
	pos: Vector3,
	rumbo: Vector3,
	estado: Estado,
	desde: number,
	objetivo: Player?,
	ultimoVisto: Vector3?,
	vistoEn: number,
	meta: Vector3?,
	pausaHasta: number,
	pensarEn: number,
	despierto: boolean,
	embestidaEn: number,
	miedoHasta: number,
	encaradoDesde: number?,
	fase: number,
}

type ZonaSegura = { centro: Vector3, radio: number }

-- Lo mínimo de Generador.ZonaMundo que se necesita (evita un require circular).
export type Zona = { tipo: string, centro: Vector3, radio: number }

local Fauna = {}

local jaguares: { Jaguar } = {}
local seguras: { ZonaSegura } = {}
local llegada: { [Player]: number } = {} -- cuándo entró cada jugador en la selva
local mordidoEn: { [Player]: number } = {}
local rng = Random.new()

local vista = RaycastParams.new()
vista.FilterType = Enum.RaycastFilterType.Exclude

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function enZonaSegura(p: Vector3, margen: number): boolean
	for _, z in seguras do
		if Vector2.new(p.X - z.centro.X, p.Z - z.centro.Z).Magnitude < z.radio + margen then
			return true
		end
	end
	return false
end

-- Suelo transitable: terreno seco, dentro del mapa y fuera de las zonas protegidas.
local function pisable(x: number, z: number): Vector3?
	if math.abs(x) > MITAD - 12 or math.abs(z) > MITAD - 12 then
		return nil
	end
	local p, mat = Kit.suelo(x, z)
	if not p or mat == Enum.Material.Water or p.Y < AGUA + 0.5 then
		return nil
	end
	if enZonaSegura(p, 6) then
		return nil
	end
	return p
end

local function cuerpo(pl: Player): (Model?, BasePart?, Humanoid?)
	local char = pl.Character
	if not char then
		return nil, nil, nil
	end
	local raiz = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not raiz or not raiz:IsA("BasePart") or not hum or hum.Health <= 0 then
		return nil, nil, nil
	end
	return char, raiz, hum
end

-- Jugador que puede ser presa ahora: en la selva, pasada la gracia y fuera de zonas protegidas.
local function presa(pl: Player, ahora: number): (Model?, BasePart?, Humanoid?)
	if pl:GetAttribute("Zona") ~= "Partida" then
		return nil, nil, nil
	end
	local llego = llegada[pl]
	if not llego or ahora - llego < J.GRACIA then
		return nil, nil, nil
	end
	local char, raiz, hum = cuerpo(pl)
	if not raiz or enZonaSegura(raiz.Position, 0) then
		return nil, nil, nil
	end
	return char, raiz, hum
end

local function ve(j: Jaguar, char: Model, raiz: BasePart): boolean
	local ojo = j.pos + Vector3.new(0, ALTURA + 1, 0)
	local hacia = raiz.Position - ojo
	local d = hacia.Magnitude
	if d > J.VISTA then
		return false
	end
	if d > J.SENTIR then
		local h = plano(hacia)
		if h.Magnitude > 0.1 and j.rumbo:Dot(h.Unit) < CONO then
			return false
		end
	end
	vista.FilterDescendantsInstances = { j.modelo, char }
	return workspace:Raycast(ojo, hacia, vista) == nil
end

local function fijar(j: Jaguar, e: Estado, ahora: number)
	if j.estado == e then
		return
	end
	j.estado = e
	j.desde = ahora
	j.meta = nil
	j.pausaHasta = 0
	j.modelo:SetAttribute("Estado", e)
	local caza = e == "Acecha" or e == "Agazapa" or e == "Embiste" or e == "Persigue"
	for _, o in j.ojos do
		o.Color = if caza then OJO_CAZA else OJO_CALMA
	end
	if not caza then
		j.objetivo = nil
		j.encaradoDesde = nil
	end
end

local function puntoCerca(centro: Vector3, minimo: number, maximo: number): Vector3?
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minimo, maximo)
		local p = pisable(centro.X + math.cos(a) * r, centro.Z + math.sin(a) * r)
		if p then
			return p
		end
	end
	return nil
end

-- Comportamientos que lo ahuyentan: varios jugadores juntos cerca, o encararlo sin huir.
local function ahuyentado(j: Jaguar, ahora: number): boolean
	local cerca = 0
	local encarado = false
	for _, pl in Players:GetPlayers() do
		local _, raiz = cuerpo(pl)
		if raiz and pl:GetAttribute("Zona") == "Partida" then
			local hacia = plano(j.pos - raiz.Position)
			local d = hacia.Magnitude
			if d <= A.RADIO_GRUPO then
				cerca += 1
			end
			local mira = plano(raiz.CFrame.LookVector)
			if d <= A.ENCARAR_DISTANCIA and d > 0.1 and mira.Magnitude > 0.1 then
				if mira.Unit:Dot(hacia.Unit) > ENCARAR then
					encarado = true
				end
			end
		end
	end
	if encarado then
		j.encaradoDesde = j.encaradoDesde or ahora
	else
		j.encaradoDesde = nil
	end
	local desde = j.encaradoDesde
	return cerca >= A.GRUPO or (desde ~= nil and ahora - desde >= A.ENCARAR_SEGUNDOS)
end

local function huir(j: Jaguar, ahora: number)
	local origen = j.ultimoVisto or (j.pos - j.rumbo)
	local lejos = plano(j.pos - origen)
	if lejos.Magnitude < 0.1 then
		lejos = -j.rumbo
	end
	j.miedoHasta = ahora + A.MIEDO
	fijar(j, "Huye", ahora)
	local destino = j.pos + lejos.Unit * 70
	j.meta = pisable(destino.X, destino.Z) or puntoCerca(j.pos, 30, 70)
end

local function pensar(j: Jaguar, ahora: number)
	-- presa visible más cercana (con preferencia por la actual, para que no cambie a cada rato)
	local mejor: Player? = nil
	local mejorRaiz: BasePart? = nil
	local mejorD = math.huge
	for _, pl in Players:GetPlayers() do
		local char, raiz = presa(pl, ahora)
		if char and raiz and ve(j, char, raiz) then
			local d = (raiz.Position - j.pos).Magnitude
			if pl == j.objetivo then
				d *= 0.6
			end
			if d < mejorD then
				mejor, mejorRaiz, mejorD = pl, raiz, d
			end
		end
	end
	if mejorRaiz then
		j.ultimoVisto = mejorRaiz.Position
		j.vistoEn = ahora
	end

	local e = j.estado
	local lejosDeCasa = plano(j.pos - j.casa).Magnitude > J.CORREA

	if e == "Huye" then
		if ahora - j.desde >= A.HUIDA then
			fijar(j, "Vuelve", ahora)
		elseif not j.meta then
			j.meta = puntoCerca(j.pos, 20, 50)
		end
		return
	end

	if (e == "Acecha" or e == "Persigue") and ahuyentado(j, ahora) then
		huir(j, ahora)
		return
	end

	if e == "Merodea" or e == "Vuelve" then
		if mejor and ahora >= j.miedoHasta then
			fijar(j, "Acecha", ahora)
			j.objetivo = mejor
			return
		end
		if e == "Vuelve" then
			if plano(j.pos - j.casa).Magnitude < 12 then
				fijar(j, "Merodea", ahora)
			elseif not j.meta then
				j.meta = j.casa
			end
			return
		end
		if lejosDeCasa then
			fijar(j, "Vuelve", ahora)
		elseif not j.meta and ahora >= j.pausaHasta then
			j.meta = puntoCerca(j.casa, 15, J.PATRULLA)
		end
		return
	end

	-- Acecha · Agazapa · Embiste · Persigue
	if lejosDeCasa and e ~= "Embiste" then
		fijar(j, "Vuelve", ahora)
		return
	end
	if not j.ultimoVisto or ahora - j.vistoEn > J.PERDER then
		fijar(j, "Vuelve", ahora)
		return
	end
	if mejor then
		j.objetivo = mejor
	end
	local puedeSaltar = mejor ~= nil
		and mejorD <= J.EMBESTIDA_DISTANCIA
		and ahora - j.embestidaEn >= J.EMBESTIDA_ENFRIAMIENTO

	if e == "Acecha" or e == "Persigue" then
		if puedeSaltar then
			fijar(j, "Agazapa", ahora)
		else
			j.meta = j.ultimoVisto
		end
	elseif e == "Agazapa" then
		if ahora - j.desde >= J.AGAZAPADO then
			fijar(j, "Embiste", ahora)
			j.embestidaEn = ahora
			j.meta = j.ultimoVisto
		end
	elseif e == "Embiste" then
		if ahora - j.desde >= J.EMBESTIDA_SEGUNDOS then
			fijar(j, "Persigue", ahora)
		end
		j.meta = j.ultimoVisto
	end
end

local function mover(j: Jaguar, dt: number, ahora: number)
	local vel = J.VELOCIDAD[j.estado]
	local meta = j.meta
	local andando = false

	if j.estado == "Agazapa" and j.ultimoVisto then
		-- se encara con la presa antes de saltar
		local h = plano(j.ultimoVisto - j.pos)
		if h.Magnitude > 0.1 then
			j.rumbo = j.rumbo:Lerp(h.Unit, math.min(1, J.GIRO * dt))
		end
	elseif meta then
		local hacia = plano(meta - j.pos)
		local d = hacia.Magnitude
		if d < 1.5 then
			j.meta = nil
			if j.estado == "Merodea" then
				j.pausaHasta = ahora + rng:NextNumber(J.PAUSA[1], J.PAUSA[2])
			end
		else
			local r = j.rumbo:Lerp(hacia / d, math.min(1, J.GIRO * dt))
			j.rumbo = if r.Magnitude > 0.05 then r.Unit else hacia / d
			local paso = math.min(vel * dt, d)
			local destino = j.pos + j.rumbo * paso
			local suelo = pisable(destino.X, destino.Z)
			if suelo and math.abs(suelo.Y - j.pos.Y) <= paso * 1.2 + 0.6 then
				j.pos = suelo
				andando = true
			else
				-- agua, pendiente o zona protegida: abandona esta meta
				j.meta = nil
				if j.estado == "Merodea" then
					j.pausaHasta = ahora + 1
				end
			end
		end
	end
	if j.rumbo.Magnitude < 0.05 then
		j.rumbo = Vector3.zAxis
	end
	j.rumbo = j.rumbo.Unit

	if andando then
		j.fase += dt * vel * 0.9
	end
	local alto = ALTURA
	if j.estado == "Agazapa" then
		alto -= 0.7
	elseif andando then
		alto += math.abs(math.sin(j.fase)) * 0.18
	end
	local base = j.pos + Vector3.new(0, alto, 0)
	j.raiz.CFrame = CFrame.lookAt(base, base + j.rumbo)
end

local function morder(j: Jaguar, ahora: number)
	local pl = j.objetivo
	if not pl then
		return
	end
	local char, raiz, hum = presa(pl, ahora)
	if not char or not raiz or not hum then
		return
	end
	if (raiz.Position - (j.pos + Vector3.new(0, ALTURA, 0))).Magnitude > J.ALCANCE then
		return
	end
	-- un jugador no recibe mordiscos seguidos (ni de dos jaguares a la vez)
	if ahora - (mordidoEn[pl] or -math.huge) < J.ENFRIAMIENTO_JUGADOR then
		return
	end
	mordidoEn[pl] = ahora
	char:SetAttribute("UltimoAtacante", "Jaguar")
	char:SetAttribute("UltimoAtaqueEn", workspace:GetServerTimeNow())
	hum:TakeDamage(J.DANO)
	-- tras morder retrocede un poco: da tiempo a reaccionar y evita muertes en cadena
	j.embestidaEn = ahora
	fijar(j, "Persigue", ahora)
	j.meta = pisable(j.pos.X - j.rumbo.X * 10, j.pos.Z - j.rumbo.Z * 10)
end

local function hayJugadorCerca(j: Jaguar): boolean
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Zona") == "Partida" then
			local _, raiz = cuerpo(pl)
			if raiz and (raiz.Position - j.pos).Magnitude <= J.DESPERTAR then
				return true
			end
		end
	end
	return false
end

-- Coloca los jaguares de una selva recién generada, lejos de las zonas y entre sí.
function Fauna.poblar(rngMapa: Random, zonas: { Zona }, padre: Instance)
	table.clear(jaguares)
	table.clear(seguras)
	for _, z in zonas do
		if z.tipo == "pueblo" or z.tipo == "inicio" then
			table.insert(seguras, { centro = z.centro, radio = z.radio })
		end
	end

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Fauna"
	carpeta.Parent = padre

	local lim = MITAD - 40
	local intentos = 0
	while #jaguares < Config.Fauna.JAGUARES and intentos < 300 do
		intentos += 1
		local x, z = rngMapa:NextNumber(-lim, lim), rngMapa:NextNumber(-lim, lim)
		local valido = true
		for _, zona in zonas do
			if Vector2.new(x - zona.centro.X, z - zona.centro.Z).Magnitude < zona.radio + J.DISTANCIA_ZONAS then
				valido = false
				break
			end
		end
		if valido then
			for _, otro in jaguares do
				if Vector2.new(x - otro.casa.X, z - otro.casa.Z).Magnitude < J.PATRULLA * 1.5 then
					valido = false
					break
				end
			end
		end
		local suelo = if valido then pisable(x, z) else nil
		if suelo then
			local a = rngMapa:NextNumber(0, math.pi * 2)
			local rumbo = Vector3.new(math.cos(a), 0, math.sin(a))
			local base = suelo + Vector3.new(0, ALTURA, 0)
			local modelo = Animales.jaguar(rngMapa, CFrame.lookAt(base, base + rumbo), carpeta)
			local ojos: { BasePart } = {}
			for _, d in modelo:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Ojo" then
					table.insert(ojos, d)
				end
			end
			modelo:SetAttribute("Estado", "Merodea")
			table.insert(jaguares, {
				modelo = modelo,
				raiz = modelo.PrimaryPart :: BasePart,
				ojos = ojos,
				casa = suelo,
				pos = suelo,
				rumbo = rumbo,
				estado = "Merodea",
				desde = 0,
				objetivo = nil,
				ultimoVisto = nil,
				vistoEn = -math.huge,
				meta = nil,
				pausaHasta = 0,
				pensarEn = os.clock() + rng:NextNumber(0, PERIODO), -- fase al azar: no piensan todos a la vez
				despierto = false,
				embestidaEn = -math.huge,
				miedoHasta = 0,
				encaradoDesde = nil,
				fase = 0,
			})
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	local ahora = os.clock()
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Zona") == "Partida" then
			if not llegada[pl] then
				llegada[pl] = ahora
			end
		else
			llegada[pl] = nil
		end
	end

	for i = #jaguares, 1, -1 do
		local j = jaguares[i]
		if not j.modelo.Parent then
			-- la selva se destruyó (nueva partida)
			table.remove(jaguares, i)
			continue
		end
		if ahora >= j.pensarEn then
			j.pensarEn = ahora + PERIODO
			j.despierto = hayJugadorCerca(j)
			if j.despierto then
				pensar(j, ahora)
			elseif j.estado ~= "Merodea" then
				fijar(j, "Merodea", ahora)
			end
		end
		if j.despierto then
			mover(j, dt, ahora)
			if j.estado == "Embiste" or j.estado == "Persigue" then
				morder(j, ahora)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(pl: Player)
	llegada[pl] = nil
	mordidoEn[pl] = nil
end)

return Fauna
