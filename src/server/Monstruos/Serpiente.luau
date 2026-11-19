--!strict
--[[
	Serpiente (servidor): decide cuándo y por dónde pasa, abre el suelo a su paso y lo cierra
	después. No ataca todavía.

	El cuerpo y lo que arrastra se animan en cada cliente (client/Serpiente) con el mismo
	recorrido y la misma hora del servidor; así 50 piezas grandes no se replican cada frame.
	El servidor solo toca lo que tiene que ser igual para todos: el terreno.

	Terreno: antes de empezar se leen los vóxeles originales de todo el pasillo; a medida que la
	cabeza avanza se abre una zanja con tierra levantada a los lados, y REGENERA segundos después
	de que pase cada tramo se vuelven a escribir los vóxeles originales.

	Baúl: 34 Procedural Generation (Terrain ReadVoxels/WriteVoxels), Server-Authoritative
	Movement (el cliente solo dibuja), Boss and Set-Piece Encounters (aviso antes del golpe).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Forma = require(ReplicatedStorage.Shared.Serpiente)
local Remotes = require(script.Parent.Parent.Remotes)
local Generador = require(script.Parent.Parent.Mundo.Generador)

local S = Config.Serpiente
local MAPA = Config.Mapa
local MITAD = MAPA.TAMANO / 2
local CELDA = MAPA.CELDA
local terreno = workspace.Terrain

local Serpiente = {}

local generacion = 0 -- invalida pasadas en curso al terminar la expedición
local pendientes: { { region: Region3, materiales: any, ocupacion: any, hora: number } } = {}
local radio = 7
local largo = 600

---------------------------------------------------------------------------------------------
-- Recorrido
---------------------------------------------------------------------------------------------

-- Camino serpenteante en superficie que sale de `inicio` hacia `rumbo`, se aparta de las
-- zonas, del borde del mapa y del río, y mide `S.RECORRIDO` studs.
local function trazar(rng: Random, mundo: Generador.Mundo, inicio: Vector2, rumbo: Vector2): { Vector3 }
	local datos = mundo.datos
	local puntos: { Vector3 } = {}
	local p = inicio
	local angulo = math.atan2(rumbo.Y, rumbo.X)
	local giro = 0
	local pasos = math.floor(S.RECORRIDO / Forma.PASO)
	local limite = MITAD - 160
	for _ = 0, pasos do
		table.insert(puntos, Vector3.new(p.X, datos.altura(p.X, p.Y), p.Y))
		-- giro lento y aleatorio: curvas amplias, como un animal grande
		giro = math.clamp(giro + rng:NextNumber(-0.012, 0.012), -0.03, 0.03)
		local dir = Vector2.new(math.cos(angulo), math.sin(angulo))
		local empuje = Vector2.zero
		-- borde del mapa
		if math.abs(p.X) > limite then
			empuje += Vector2.new(-math.sign(p.X), 0)
		end
		if math.abs(p.Y) > limite then
			empuje += Vector2.new(0, -math.sign(p.Y))
		end
		-- zonas: pueblos, claro, helicóptero, salida
		for _, z in mundo.zonas do
			local d = Vector2.new(p.X - z.centro.X, p.Y - z.centro.Z)
			local libre = z.radio + S.MARGEN_ZONA + 60
			if d.Magnitude < libre then
				empuje += d.Unit * (1 - d.Magnitude / libre) * 2
			end
		end
		-- el río: lo cruza si hace falta, pero no lo sigue
		if datos.distanciaAgua(p.X, p.Y) < 30 then
			empuje += dir * 0.5
		end
		if empuje.Magnitude > 0.01 then
			local deseado = math.atan2(empuje.Y + dir.Y, empuje.X + dir.X)
			local dif = (deseado - angulo + math.pi) % (2 * math.pi) - math.pi
			angulo += math.clamp(dif, -0.06, 0.06)
		else
			angulo += giro
		end
		p += Vector2.new(math.cos(angulo), math.sin(angulo)) * Forma.PASO
	end
	return puntos
end

-- Punto donde abre la tierra la primera vez: delante del testigo, a la vista y lejos de zonas.
local function salida(rng: Random, mundo: Generador.Mundo, testigo: Player): (Vector2?, Vector2?)
	local char = testigo.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if not raiz or not raiz:IsA("BasePart") then
		return nil, nil
	end
	local mira = raiz.CFrame.LookVector
	local base = math.atan2(mira.Z, mira.X)
	local yo = Vector2.new(raiz.Position.X, raiz.Position.Z)
	for _ = 1, 24 do
		local a = base + rng:NextNumber(-0.5, 0.5)
		local d = rng:NextNumber(S.DISTANCIA[1], S.DISTANCIA[2])
		local p = yo + Vector2.new(math.cos(a), math.sin(a)) * d
		local valido = math.abs(p.X) < MITAD - 200 and math.abs(p.Y) < MITAD - 200
		for _, z in mundo.zonas do
			if (Vector2.new(z.centro.X, z.centro.Z) - p).Magnitude < z.radio + S.MARGEN_ZONA then
				valido = false
			end
		end
		if valido and mundo.datos.distanciaAgua(p.X, p.Y) > 12 then
			-- cruza de lado delante del testigo: perpendicular a la línea de visión
			local frente = (p - yo).Unit
			local lado = Vector2.new(-frente.Y, frente.X) * (if rng:NextNumber() < 0.5 then 1 else -1)
			-- empieza un poco antes para que la cabeza asome justo delante
			return p - lado * S.RAMPA * 0.8, lado
		end
	end
	return nil, nil
end

---------------------------------------------------------------------------------------------
-- Terreno
---------------------------------------------------------------------------------------------

local function alinear(v: number, abajo: boolean): number
	return if abajo then math.floor(v / CELDA) * CELDA else math.ceil(v / CELDA) * CELDA
end

-- Lee los vóxeles originales del pasillo en tramos y los guarda para regenerarlos después.
local function capturar(puntos: { Vector3 }, t0: number, velocidad: number)
	local ancho = math.max(radio * 1.9, radio * S.CRATER + 6) + 8
	local tramo = 8 -- puntos por tramo (32 studs)
	local extraCola = largo / velocidad
	for i = 1, #puntos, tramo do
		local j = math.min(#puntos, i + tramo)
		local lo = Vector3.new(math.huge, math.huge, math.huge)
		local hi = -lo
		for k = i, j do
			lo = lo:Min(puntos[k])
			hi = hi:Max(puntos[k])
		end
		lo -= Vector3.new(ancho, radio * 2.2 + 8, ancho)
		hi += Vector3.new(ancho, 12, ancho)
		local region = Region3.new(
			Vector3.new(alinear(lo.X, true), alinear(lo.Y, true), alinear(lo.Z, true)),
			Vector3.new(alinear(hi.X, false), alinear(hi.Y, false), alinear(hi.Z, false))
		)
		local materiales, ocupacion = terreno:ReadVoxels(region, CELDA)
		-- se regenera cuando ya pasó la cola por el tramo
		local hora = t0 + (j - 1) * Forma.PASO / velocidad + extraCola + S.REGENERA
		table.insert(pendientes, { region = region, materiales = materiales, ocupacion = ocupacion, hora = hora })
	end
end

local function abrir(p: Vector3, adelante: Vector3, rng: Random)
	local eje = p - Vector3.yAxis * radio * S.HUNDIDO
	terreno:FillBall(eje, radio * 1.12, Enum.Material.Air)
	-- tierra levantada y rota a los lados de la zanja
	local lado = adelante:Cross(Vector3.yAxis).Unit
	for signo = -1, 1, 2 do
		local c = p + lado * signo * radio * rng:NextNumber(1.15, 1.45) + Vector3.yAxis * rng:NextNumber(0.5, 2.5)
		terreno:FillBall(
			c,
			rng:NextNumber(2.2, 3.6),
			if rng:NextNumber() < 0.6 then Enum.Material.Mud else Enum.Material.Ground
		)
	end
end

-- Cráter donde sale y donde se hunde: un hoyo ancho con tierra reventada alrededor.
local function crater(p: Vector3, rng: Random)
	local r = radio * S.CRATER
	terreno:FillBall(p - Vector3.yAxis * r * 0.45, r * 0.7, Enum.Material.Air)
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local c = p + Vector3.new(math.cos(a), 0, math.sin(a)) * r * rng:NextNumber(0.65, 0.85)
		terreno:FillBall(
			c + Vector3.yAxis * rng:NextNumber(0, 3),
			rng:NextNumber(3, 5.5),
			if rng:NextNumber() < 0.5 then Enum.Material.Mud else Enum.Material.Ground
		)
	end
end

local function regenerarVencidos(todo: boolean)
	local ahora = workspace:GetServerTimeNow()
	for i = #pendientes, 1, -1 do
		local t = pendientes[i]
		if todo or ahora >= t.hora then
			terreno:WriteVoxels(t.region, CELDA, t.materiales, t.ocupacion)
			table.remove(pendientes, i)
		end
	end
end

---------------------------------------------------------------------------------------------
-- Pasadas
---------------------------------------------------------------------------------------------

local function enSelva(): { Player }
	local lista = {}
	for _, pl in Players:GetPlayers() do
		local char = pl.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if pl:GetAttribute("Zona") == "Partida" and hum and hum.Health > 0 then
			table.insert(lista, pl)
		end
	end
	return lista
end

local function congelar(jugadores: { Player }, segundos: number)
	for _, pl in jugadores do
		local char = pl.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") then
			raiz.Anchored = true
			task.delay(segundos, function()
				if raiz.Parent then
					raiz.Anchored = false
				end
			end)
		end
	end
end

local function pasada(mundo: Generador.Mundo, rng: Random, primera: boolean, gen: number)
	local jugadores = enSelva()
	if #jugadores == 0 then
		return
	end
	local testigo = jugadores[rng:NextInteger(1, #jugadores)]
	local inicio, rumbo = salida(rng, mundo, testigo)
	if not inicio or not rumbo then
		-- sin hueco delante del testigo: sale en cualquier sitio lejos de todos
		local a = rng:NextNumber(0, math.pi * 2)
		inicio = Vector2.new(math.cos(a), math.sin(a)) * MITAD * 0.45
		rumbo = -(inicio :: Vector2).Unit
	end
	local puntos = trazar(rng, mundo, inicio :: Vector2, rumbo :: Vector2)
	local t0 = workspace:GetServerTimeNow() + S.AVISO
	capturar(puntos, t0, S.VELOCIDAD)

	local datos: Forma.Pasada = {
		puntos = puntos,
		t0 = t0,
		velocidad = S.VELOCIDAD,
		primera = primera,
		testigo = if primera then testigo else nil,
	}
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Zona") == "Partida" then
			Remotes.Serpiente:FireClient(pl, "pasada", datos)
		end
	end
	if primera then
		-- quietos durante la cinemática: temblor + 14 s mirando cómo pasa
		congelar(jugadores, S.AVISO + 14)
	end
	print(
		("[Serpiente] pasada %s, %d studs"):format(
			if primera then "con cinemática" else "normal",
			#puntos * Forma.PASO
		)
	)

	-- abrir la zanja según avanza la cabeza (desde que asoma hasta que se hunde)
	local ultimo = 0
	local kEntrada = math.floor(S.RAMPA * 0.5 / Forma.PASO) + 1
	local crateres = { [kEntrada] = true, [#puntos - kEntrada + 1] = true }
	while generacion == gen do
		local s = (workspace:GetServerTimeNow() - t0) * S.VELOCIDAD
		local hasta = math.min(#puntos, math.floor(s / Forma.PASO) + 1)
		for k = ultimo + 1, hasta do
			if crateres[k] then
				crateres[k] = nil
				crater(puntos[k], rng)
			end
		end
		for k = ultimo + 1, hasta, 2 do
			local d = (k - 1) * Forma.PASO
			if d > S.RAMPA * 0.6 and d < (#puntos - 1) * Forma.PASO - S.RAMPA * 0.6 then
				local p = puntos[k]
				if p.Y > MAPA.NIVEL_AGUA + 1 then
					local q = puntos[math.min(#puntos, k + 1)]
					abrir(p, (q - p) + Vector3.new(0, 0, 1e-3), rng)
				end
			end
		end
		ultimo = math.max(ultimo, hasta)
		regenerarVencidos(false)
		if hasta >= #puntos and #pendientes == 0 then
			break
		end
		task.wait(0.1)
	end
end

function Serpiente.iniciar(mundo: Generador.Mundo)
	if not S.ACTIVADA then
		return
	end
	generacion += 1
	local gen = generacion
	local forma = Forma.forma()
	radio, largo = forma.radio, forma.largo
	forma.modelo:Destroy()
	task.spawn(function()
		local rng = Random.new(mundo.semilla + 404)
		-- Workspace.SerpienteRapida = true: aparece a los 8 s, para probar sin esperar
		local rapida = workspace:GetAttribute("SerpienteRapida") == true
		task.wait(if rapida then 8 else rng:NextNumber(S.PRIMERA[1], S.PRIMERA[2]))
		local primera = true
		while generacion == gen do
			-- de día no hay anomalías (CONTEXT.md; la hora la lleva server/Ciclo.luau)
			while generacion == gen and workspace:GetAttribute("SelvaDia") == true do
				task.wait(2)
			end
			if generacion ~= gen then
				break
			end
			pasada(mundo, rng, primera, gen)
			primera = false
			if generacion ~= gen then
				break
			end
			task.wait(rng:NextNumber(S.REPETIR[1], S.REPETIR[2]))
		end
	end)
end

-- Fin de la expedición: se corta la pasada y el suelo vuelve a su estado original.
function Serpiente.detener()
	generacion += 1
	regenerarVencidos(true)
	Remotes.Serpiente:FireAllClients("fin")
end

return Serpiente
