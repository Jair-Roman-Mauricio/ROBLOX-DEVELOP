--!strict
--[[
	Agua viva, parte del servidor.

	1. Publica para los clientes el trazado del río (en el sentido de la corriente), los lagos y
	   los tramos de pirañas, como atributos de `Selva.Agua` (Configuration).
	2. Lleva los peligros del agua, que tienen que ser autoritativos:
	   · Pirañas: tramos del río donde nadar te muerde poco a poco. Se ven venir porque el agua
	     hierve y saltan peces (lo dibuja client/Agua.luau).
	   · Anaconda: vive en el lago-pantano (o en el primer lago que haya). Ronda bajo el agua;
	     si nadas cerca te persigue, muerde y vuelve a hundirse.

	La corriente, las salpicaduras, el efecto bajo el agua, los delfines rosados y los restos que
	flotan son solo visuales y van en el cliente.

	PROPUESTA: CONTEXT.md deja abierto el catálogo de amenazas. Valores en Config.Agua.
	Baúl: Terrain Deep Dive - Materials Water and Performance (nado, corrientes y efecto bajo el
	agua se programan aparte), NPC AI and Behaviour (pensar a pocos Hz y solo con gente cerca).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Disposicion = require(script.Parent.Mundo.Disposicion)

local A = Config.Agua
local AN = A.ANACONDA
local PI = A.PIRANAS
local AGUA = Config.Mapa.NIVEL_AGUA

type Anaconda = {
	modelo: Configuration,
	centro: Vector3, -- centro del lago a la altura del agua
	radio: number,
	pos: Vector3,
	rumbo: Vector3,
	angulo: number,
	estado: string, -- "ronda" | "caza" | "muerde"
	objetivo: Player?,
	desde: number,
	mordidaEn: number,
}

local Agua = {}

local piranas: { Vector3 } = {}
local anaconda: Anaconda? = nil
local mordido: { [Player]: number } = {}
local llegada: { [Player]: number } = {}
local siguientePirana = 0
local siguientePensar = 0
local siguientePublicar = 0

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ¿Hay agua de terreno en este punto? (celda de 4 studs, como recomienda el baúl)
local function enAgua(pos: Vector3): boolean
	local region = Region3.new(pos - Vector3.new(2, 2, 2), pos + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, canales = pcall(function()
		return workspace.Terrain:ReadVoxelChannels(region, 4, { "LiquidOccupancy" })
	end)
	if ok and canales then
		return (canales :: any).LiquidOccupancy[1][1][1] > 0.5
	end
	local materiales = workspace.Terrain:ReadVoxels(region, 4)
	return materiales[1][1][1] == Enum.Material.Water
end

local function cuerpo(pl: Player): (Model?, BasePart?, Humanoid?)
	local char = pl.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if char and raiz and raiz:IsA("BasePart") and hum and hum.Health > 0 then
		return char, raiz, hum
	end
	return nil, nil, nil
end

local function morder(pl: Player, char: Model, hum: Humanoid, quien: string, dano: number)
	char:SetAttribute("UltimoAtacante", quien)
	char:SetAttribute("UltimoAtaqueEn", workspace:GetServerTimeNow())
	hum:TakeDamage(dano)
	mordido[pl] = os.clock()
end

-- Prepara el agua de una selva recién generada. `padre` es la carpeta Selva.
function Agua.preparar(rng: Random, disp: Disposicion.Disposicion, padre: Instance)
	table.clear(piranas)
	anaconda = nil

	local cfg = Instance.new("Configuration")
	cfg.Name = "Agua"

	-- río cada ~MUESTRA_RIO studs, en el sentido de la corriente (entra por el norte y sale)
	local rio = disp.rio
	local paso = math.max(1, math.floor(A.MUESTRA_RIO / Config.Mapa.CELDA))
	local n = 0
	for i = 1, #rio, paso do
		n += 1
		cfg:SetAttribute("Rio" .. n, Vector3.new(rio[i].X, AGUA, rio[i].Y))
	end
	if #rio > 0 and (#rio - 1) % paso ~= 0 then
		n += 1
		cfg:SetAttribute("Rio" .. n, Vector3.new(rio[#rio].X, AGUA, rio[#rio].Y))
	end
	cfg:SetAttribute("RioN", n)

	for i, lago in disp.lagos do
		local nivel = if lago.nivel > 0 then lago.nivel else AGUA
		cfg:SetAttribute("Lago" .. i, Vector3.new(lago.centro.X, nivel, lago.centro.Y))
		cfg:SetAttribute("LagoRadio" .. i, lago.radio)
		cfg:SetAttribute("LagoTipo" .. i, lago.tipo)
	end
	cfg:SetAttribute("LagoN", #disp.lagos)

	-- pirañas: tramos al azar del río, lejos de sus extremos y separados entre sí
	if #rio > 20 then
		for _ = 1, PI.TRAMOS * 15 do
			if #piranas >= PI.TRAMOS then
				break
			end
			local p = rio[rng:NextInteger(math.floor(#rio * 0.15), math.floor(#rio * 0.85))]
			local v = Vector3.new(p.X, AGUA, p.Y)
			local libre = true
			for _, otra in piranas do
				if (otra - v).Magnitude < PI.SEPARACION then
					libre = false
					break
				end
			end
			if libre then
				table.insert(piranas, v)
			end
		end
	end
	for i, p in piranas do
		cfg:SetAttribute("Pirana" .. i, p)
	end
	cfg:SetAttribute("PiranaN", #piranas)
	cfg:SetAttribute("PiranaRadio", PI.RADIO)

	-- anaconda: en el lago-pantano si hay; si no, en el primer lago
	local elegido = nil
	for _, lago in disp.lagos do
		if lago.tipo == "pantano" then
			elegido = lago
		end
	end
	elegido = elegido or disp.lagos[1]
	if elegido and AN.ACTIVA then
		local nivel = if elegido.nivel > 0 then elegido.nivel else AGUA
		local centro = Vector3.new(elegido.centro.X, nivel, elegido.centro.Y)
		local m = Instance.new("Configuration")
		m.Name = "Anaconda"
		m.Parent = cfg
		local radio = elegido.radio * 0.8
		anaconda = {
			modelo = m,
			centro = centro,
			radio = radio,
			pos = centro + Vector3.new(radio * 0.6, -AN.PROFUNDIDAD, 0),
			rumbo = Vector3.zAxis,
			angulo = 0,
			estado = "ronda",
			objetivo = nil,
			desde = os.clock(),
			mordidaEn = -math.huge,
		}
		m:SetAttribute("Pos", anaconda.pos)
		m:SetAttribute("Rumbo", anaconda.rumbo)
		m:SetAttribute("Estado", "ronda")
	end

	cfg.Parent = padre
end

-- Nadadores que pueden ser presa (en la selva, pasada la gracia del aterrizaje, en el agua).
local function nadadores(ahora: number): { { pl: Player, char: Model, raiz: BasePart, hum: Humanoid } }
	local lista = {}
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Zona") == "Partida" then
			llegada[pl] = llegada[pl] or ahora
			local char, raiz, hum = cuerpo(pl)
			if char and raiz and hum and ahora - llegada[pl] >= AN.GRACIA and enAgua(raiz.Position) then
				table.insert(lista, { pl = pl, char = char, raiz = raiz, hum = hum })
			end
		else
			llegada[pl] = nil
		end
	end
	return lista
end

local function pensarAnaconda(a: Anaconda, ahora: number, presas: { any })
	-- presa más cercana dentro del lago
	local mejor, mejorD = nil, math.huge
	for _, p in presas do
		local dLago = plano(p.raiz.Position - a.centro).Magnitude
		local d = (p.raiz.Position - a.pos).Magnitude
		if dLago < a.radio + 6 and d < AN.VISTA and d < mejorD then
			mejor, mejorD = p, d
		end
	end

	if a.estado == "muerde" then
		if ahora - a.desde > 1 then
			a.estado, a.desde, a.objetivo = "ronda", ahora, nil
		end
	elseif mejor and ahora - a.mordidaEn > AN.ENFRIAMIENTO then
		a.estado, a.objetivo = "caza", mejor.pl
		if mejorD < AN.ALCANCE and ahora - (mordido[mejor.pl] or -math.huge) > 1 then
			morder(mejor.pl, mejor.char, mejor.hum, "Anaconda", AN.DANO)
			a.estado, a.desde, a.mordidaEn = "muerde", ahora, ahora
		end
	elseif a.estado == "caza" then
		a.estado, a.desde, a.objetivo = "ronda", ahora, nil
	end
end

local function moverAnaconda(a: Anaconda, dt: number)
	local meta: Vector3
	local vel: number
	local profundidad = AN.PROFUNDIDAD
	local objetivo = a.objetivo
	local raiz: BasePart? = nil
	if objetivo then
		local _, r = cuerpo(objetivo)
		raiz = r
	end
	if a.estado == "caza" and raiz then
		meta, vel, profundidad = raiz.Position, AN.CAZA, 1.2
	elseif a.estado == "muerde" then
		meta, vel, profundidad = a.pos + a.rumbo, 0, 0.2
	else
		a.angulo += dt * AN.RONDA / math.max(a.radio * 0.6, 4)
		meta = a.centro + Vector3.new(math.cos(a.angulo), 0, math.sin(a.angulo)) * a.radio * 0.6
		vel = AN.RONDA
	end
	local hacia = plano(meta - a.pos)
	if hacia.Magnitude > 0.5 and vel > 0 then
		a.rumbo = a.rumbo:Lerp(hacia.Unit, math.min(1, dt * 3)).Unit
		local nueva = a.pos + a.rumbo * math.min(vel * dt, hacia.Magnitude)
		-- no sale de su lago
		local desdeCentro = plano(nueva - a.centro)
		if desdeCentro.Magnitude > a.radio then
			nueva = a.centro + desdeCentro.Unit * a.radio
		end
		a.pos = nueva
	end
	a.pos = Vector3.new(a.pos.X, a.centro.Y - profundidad, a.pos.Z)
end

RunService.Heartbeat:Connect(function(dt: number)
	local a = anaconda
	if a and not a.modelo.Parent then
		-- la selva se destruyó (nueva partida)
		anaconda = nil
		a = nil
	end
	if #piranas == 0 and not a then
		return
	end
	local ahora = os.clock()

	if ahora >= siguientePirana or (a and ahora >= siguientePensar) then
		local presas = nadadores(ahora)

		-- pirañas: muerden a quien nade en su tramo
		if ahora >= siguientePirana then
			siguientePirana = ahora + PI.CADA
			for _, p in presas do
				for _, centro in piranas do
					if plano(p.raiz.Position - centro).Magnitude < PI.RADIO then
						morder(p.pl, p.char, p.hum, "Pirañas", PI.DANO)
						break
					end
				end
			end
		end

		if a and ahora >= siguientePensar then
			siguientePensar = ahora + 0.2
			pensarAnaconda(a, ahora, presas)
		end
	end

	if a then
		moverAnaconda(a, dt)
		if ahora >= siguientePublicar then
			-- 10 Hz basta: el cliente suaviza entre muestras
			siguientePublicar = ahora + 0.1
			a.modelo:SetAttribute("Pos", a.pos)
			a.modelo:SetAttribute("Rumbo", a.rumbo)
			a.modelo:SetAttribute("Estado", a.estado)
		end
	end
end)

Players.PlayerRemoving:Connect(function(pl: Player)
	mordido[pl] = nil
	llegada[pl] = nil
end)

return Agua
