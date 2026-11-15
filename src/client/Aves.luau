--!strict
--[[
	Aves de la selva, solo visuales y locales: cada cliente las crea y las mueve, el servidor no
	sabe nada de ellas y no afectan al juego.
	  · Bandadas de guacamayos y loros que vuelan en bucles suaves sobre el dosel, alrededor
	    del jugador; si se quedan lejos, reaparecen cerca.
	  · De vez en cuando, una bandada asustada sale de entre los árboles con un graznido.

	Trayectorias: B-spline cúbica cerrada con velocidad por longitud de arco y alabeo en las
	curvas (baúl: Flight Flocks and Path Animation). Todo se mueve con BulkMoveTo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)

local AV = Config.Fauna.AVES
local SUB = 16

type Plumaje = { cuerpo: Color3, ala: Color3, cola: Color3 }

local PLUMAJES: { Plumaje } = {
	{ cuerpo = Color3.fromRGB(200, 34, 30), ala = Color3.fromRGB(30, 80, 190), cola = Color3.fromRGB(240, 196, 40) }, -- guacamayo rojo
	{ cuerpo = Color3.fromRGB(36, 110, 200), ala = Color3.fromRGB(28, 70, 160), cola = Color3.fromRGB(250, 200, 40) }, -- guacamayo azul
	{ cuerpo = Color3.fromRGB(60, 160, 60), ala = Color3.fromRGB(40, 120, 50), cola = Color3.fromRGB(220, 60, 40) }, -- loro
}

type Ave = {
	cuerpo: BasePart,
	alaI: BasePart,
	alaD: BasePart,
	cola: BasePart,
	desfase: Vector3,
	fase: number,
	ritmo: number,
}

type Ruta = { pts: { Vector3 }, n: number, L: { number }, len: number, K: number }

type Bandada = {
	aves: { Ave },
	ruta: Ruta,
	s: number,
	k: number,
	vel: number,
	centro: Vector3,
	rumbo: Vector3,
	alabeo: number,
}

-- bandada asustada: una curva abierta (Bézier cuadrática) de los árboles al cielo
type Susto = { aves: { Ave }, p0: Vector3, p1: Vector3, p2: Vector3, t: number, dur: number }

local Aves = {}

local jugador = Players.LocalPlayer
local rng = Random.new()
local carpeta: Folder? = nil
local bandadas: { Bandada } = {}
local sustos: { Susto } = {}
local partes: { BasePart } = {}
local cframes: { CFrame } = {}

local soloTerreno = RaycastParams.new()
soloTerreno.FilterType = Enum.RaycastFilterType.Include
soloTerreno.FilterDescendantsInstances = { workspace.Terrain }

local function suelo(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -1400, 0), soloTerreno)
	return if hit then hit.Position.Y else nil
end

-- B-spline cúbica uniforme cerrada: posición y derivada en el segmento i, parámetro u.
local function evalSeg(pts: { Vector3 }, n: number, i: number, u: number): (Vector3, Vector3)
	local a, b, c, d = pts[i % n + 1], pts[(i + 1) % n + 1], pts[(i + 2) % n + 1], pts[(i + 3) % n + 1]
	local u2, v = u * u, 1 - u
	local u3 = u2 * u
	local pos = (a * (v * v * v) + b * (3 * u3 - 6 * u2 + 4) + c * (-3 * u3 + 3 * u2 + 3 * u + 1) + d * u3) / 6
	local d1 = a * (-0.5 * v * v) + b * (1.5 * u2 - 2 * u) + c * (-1.5 * u2 + u + 0.5) + d * (0.5 * u2)
	return pos, d1
end

-- Tabla de longitud de arco: velocidad constante a lo largo de la curva.
local function construirRuta(pts: { Vector3 }): Ruta
	local n = #pts
	local L = { 0 }
	local prev = evalSeg(pts, n, 0, 0)
	local acc = 0
	for k = 1, n * SUB do
		local i = (k - 1) // SUB
		local p = evalSeg(pts, n, i, (k - i * SUB) / SUB)
		acc += (p - prev).Magnitude
		L[k + 1] = acc
		prev = p
	end
	return { pts = pts, n = n, L = L, len = acc, K = n * SUB }
end

local function ubicar(b: Bandada): (Vector3, Vector3)
	local r = b.ruta
	local L = r.L
	local k = b.k
	if b.s < L[k + 1] then
		k = 0
	end
	while k < r.K - 1 and L[k + 2] <= b.s do
		k += 1
	end
	b.k = k
	local a, c = L[k + 1], L[k + 2]
	local f = if c > a then (b.s - a) / (c - a) else 0
	local g = (k + f) / SUB
	local i = math.min(math.floor(g), r.n - 1)
	return evalSeg(r.pts, r.n, i, g - i)
end

local function pieza(padre: Instance, tam: Vector3, color: Color3, ovalo: boolean): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tam
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if ovalo then
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.Sphere
		malla.Parent = p
	end
	p.Parent = padre
	return p
end

local function crearAve(padre: Instance, plumaje: Plumaje, desfase: Vector3): Ave
	local escala = rng:NextNumber(0.85, 1.15)
	return {
		cuerpo = pieza(padre, Vector3.new(0.55, 0.55, 1.4) * escala, plumaje.cuerpo, true),
		alaI = pieza(padre, Vector3.new(1.6, 0.08, 0.7) * escala, plumaje.ala, false),
		alaD = pieza(padre, Vector3.new(1.6, 0.08, 0.7) * escala, plumaje.ala, false),
		cola = pieza(padre, Vector3.new(0.3, 0.06, 1) * escala, plumaje.cola, false),
		desfase = desfase,
		fase = rng:NextNumber(0, math.pi * 2),
		ritmo = rng:NextNumber(10, 14),
	}
end

local function crearGrupo(padre: Instance): { Ave }
	local plumaje = PLUMAJES[rng:NextInteger(1, #PLUMAJES)]
	local aves = {}
	for i = 1, rng:NextInteger(AV.POR_BANDADA[1], AV.POR_BANDADA[2]) do
		local desfase = if i == 1
			then Vector3.zero
			else Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-2, 2), rng:NextNumber(1, 9))
		table.insert(aves, crearAve(padre, plumaje, desfase))
	end
	return aves
end

local function destruirAves(aves: { Ave })
	for _, a in aves do
		a.cuerpo:Destroy()
		a.alaI:Destroy()
		a.alaD:Destroy()
		a.cola:Destroy()
	end
end

-- Pone el ave en su sitio dentro de la bandada, con aleteo, y la añade al lote de BulkMoveTo.
local function colocar(a: Ave, cf: CFrame, dt: number, aleteo: number)
	a.fase += dt * a.ritmo
	local ola = math.sin(a.fase * 0.37) * 0.5
	local c = cf * CFrame.new(a.desfase + Vector3.new(0, ola, 0))
	local giro = math.sin(a.fase) * aleteo
	local ancho = a.cuerpo.Size.X * 0.45
	local medio = a.alaI.Size.X / 2
	table.insert(partes, a.cuerpo)
	table.insert(cframes, c)
	table.insert(partes, a.alaI)
	table.insert(cframes, c * CFrame.new(-ancho, 0, 0) * CFrame.Angles(0, 0, giro) * CFrame.new(-medio, 0, 0))
	table.insert(partes, a.alaD)
	table.insert(cframes, c * CFrame.new(ancho, 0, 0) * CFrame.Angles(0, 0, -giro) * CFrame.new(medio, 0, 0))
	table.insert(partes, a.cola)
	table.insert(cframes, c * CFrame.new(0, 0, a.cuerpo.Size.Z * 0.55 + a.cola.Size.Z / 2 - 0.1))
end

local function nuevaBandada(padre: Instance, cerca: Vector3): Bandada?
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(60, 180)
	local x, z = cerca.X + math.cos(a) * r, cerca.Z + math.sin(a) * r
	local y = suelo(x, z)
	if not y then
		return nil
	end
	local centro = Vector3.new(x, y + rng:NextNumber(AV.ALTURA[1], AV.ALTURA[2]), z)
	local pts = {}
	local radio = rng:NextNumber(AV.RADIO[1], AV.RADIO[2])
	for i = 1, 6 do
		local ang = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local rr = radio * rng:NextNumber(0.7, 1.3)
		table.insert(pts, centro + Vector3.new(math.cos(ang) * rr, rng:NextNumber(-5, 5), math.sin(ang) * rr))
	end
	return {
		aves = crearGrupo(padre),
		ruta = construirRuta(pts),
		s = 0,
		k = 0,
		vel = rng:NextNumber(AV.VELOCIDAD[1], AV.VELOCIDAD[2]),
		centro = centro,
		rumbo = Vector3.zAxis,
		alabeo = 0,
	}
end

local function nuevoSusto(padre: Instance, cerca: Vector3)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(40, 80)
	local x, z = cerca.X + math.cos(a) * r, cerca.Z + math.sin(a) * r
	local y = suelo(x, z)
	if not y then
		return
	end
	local fuera = Vector3.new(math.cos(a), 0, math.sin(a))
	local p0 = Vector3.new(x, y + 14, z)
	table.insert(sustos, {
		aves = crearGrupo(padre),
		p0 = p0,
		p1 = p0 + fuera * 25 + Vector3.new(0, 30, 0),
		p2 = p0 + fuera * 160 + Vector3.new(rng:NextNumber(-40, 40), 70, rng:NextNumber(-40, 40)),
		t = 0,
		dur = rng:NextNumber(5, 7),
	})
	Audio.efecto("Pajaro", 1, rng:NextNumber(1, 1.2))
end

local function limpiar()
	for _, b in bandadas do
		destruirAves(b.aves)
	end
	for _, s in sustos do
		destruirAves(s.aves)
	end
	table.clear(bandadas)
	table.clear(sustos)
	if carpeta then
		carpeta:Destroy()
		carpeta = nil
	end
end

local function enSelva(): boolean
	return jugador:GetAttribute("Zona") == "Partida"
end

local function paso(dt: number)
	local cam = workspace.CurrentCamera
	if not enSelva() or not cam then
		if carpeta then
			limpiar()
		end
		return
	end
	local padre = carpeta
	if not padre then
		local f = Instance.new("Folder")
		f.Name = "AvesLocales"
		f.Parent = workspace
		carpeta = f
		padre = f
	end
	local ojo = cam.CFrame.Position

	-- mantener las bandadas cerca del jugador
	for i = #bandadas, 1, -1 do
		local c = bandadas[i].centro
		if Vector2.new(c.X - ojo.X, c.Z - ojo.Z).Magnitude > AV.RECICLAR then
			destruirAves(bandadas[i].aves)
			table.remove(bandadas, i)
		end
	end
	if #bandadas < AV.BANDADAS then
		local b = nuevaBandada(padre :: Folder, ojo)
		if b then
			table.insert(bandadas, b)
		end
	end

	table.clear(partes)
	table.clear(cframes)

	for _, b in bandadas do
		b.s += b.vel * dt
		if b.s >= b.ruta.len then
			b.s -= b.ruta.len
		end
		local pos, d1 = ubicar(b)
		local dir = if d1.Magnitude > 0.01 then d1.Unit else b.rumbo
		-- alabeo según lo rápido que gira: se inclina hacia dentro de la curva
		local giro = b.rumbo:Cross(dir).Y / math.max(dt, 1 / 240)
		b.alabeo += (math.clamp(giro * 0.35, -0.8, 0.8) - b.alabeo) * math.min(1, dt * 4)
		b.rumbo = dir
		local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, b.alabeo)
		for _, a in b.aves do
			colocar(a, cf, dt, 0.7)
		end
	end

	for i = #sustos, 1, -1 do
		local s = sustos[i]
		s.t += dt / s.dur
		if s.t >= 1 then
			destruirAves(s.aves)
			table.remove(sustos, i)
		else
			local t, u = s.t, 1 - s.t
			local pos = s.p0 * (u * u) + s.p1 * (2 * u * t) + s.p2 * (t * t)
			local d = (s.p1 - s.p0) * (2 * u) + (s.p2 - s.p1) * (2 * t)
			local cf = CFrame.lookAt(pos, pos + (if d.Magnitude > 0.01 then d.Unit else Vector3.yAxis))
			for _, a in s.aves do
				colocar(a, cf, dt * 1.6, 0.9) -- aletean más rápido, asustadas
			end
		end
	end

	if #partes > 0 then
		workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Aves.iniciar()
	RunService.RenderStepped:Connect(paso)
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(AV.SUSTO[1], AV.SUSTO[2]))
			local cam = workspace.CurrentCamera
			local padre = carpeta
			if enSelva() and cam and padre then
				nuevoSusto(padre, cam.CFrame.Position)
			end
		end
	end)
end

return Aves
