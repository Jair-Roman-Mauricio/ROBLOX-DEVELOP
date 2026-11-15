--!strict
--[[
	Animales de la selva construidos con partes (cargan para cualquier cuenta).

	El jaguar se mueve como una sola pieza: la raíz (`Raiz`, anclada e invisible) lleva soldadas
	las demás partes, así el servidor solo mueve y replica una parte por animal
	(baúl: NPC AI and Behaviour §7, Network Ownership).

	Convención: `cf` es la raíz a ALTURA_JAGUAR sobre el suelo, morro hacia -Z.
]]

local Kit = require(script.Parent.Kit)

local M = Enum.Material

local Animales = {}

Animales.ALTURA_JAGUAR = 2.4 -- de la raíz al suelo

local PELAJE = Color3.fromRGB(196, 146, 66)
local PELAJE_CLARO = Color3.fromRGB(226, 204, 160)
local MANCHA = Color3.fromRGB(40, 30, 22)
local OJO = Color3.fromRGB(255, 214, 90)

local SIN = { colision = false, consulta = false } :: Kit.Opciones
local DETALLE = { colision = false, consulta = false, sombra = false } :: Kit.Opciones

function Animales.jaguar(rng: Random, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Jaguar", padre)
	local raiz = Kit.parte(m, cf, Vector3.one, PELAJE, M.SmoothPlastic, {
		colision = false,
		consulta = false,
		sombra = false,
		transparencia = 1,
		nombre = "Raiz",
	})

	local function en(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local function p(x: number, y: number, z: number): Vector3
		return cf:PointToWorldSpace(Vector3.new(x, y, z))
	end

	local pelaje = Kit.variar(PELAJE, rng, 0.05)

	-- cuerpo
	Kit.ovoide(m, en(0, 0.1, 0.2), Vector3.new(2.1, 1.9, 5), pelaje, M.Fabric, SIN)
	Kit.ovoide(m, en(0, 0.2, -1.9), Vector3.new(2, 2.1, 2.2), pelaje, M.Fabric, SIN)
	Kit.ovoide(m, en(0, -0.45, 0), Vector3.new(1.6, 1, 4.4), PELAJE_CLARO, M.Fabric, SIN)

	-- cabeza
	Kit.ovoide(m, en(0, 0.75, -3.3), Vector3.new(1.6, 1.35, 1.7), pelaje, M.Fabric, SIN)
	Kit.ovoide(m, en(0, 0.45, -4.1), Vector3.new(0.95, 0.7, 0.9), PELAJE_CLARO, M.Fabric, SIN)
	Kit.ovoide(m, en(0, 0.62, -4.55), Vector3.new(0.35, 0.25, 0.15), MANCHA, M.SmoothPlastic, DETALLE)

	for _, s in { -1, 1 } do
		Kit.ovoide(m, en(0.55 * s, 1.4, -3.15), Vector3.new(0.45, 0.45, 0.2), pelaje, M.Fabric, DETALLE)
		Kit.ovoide(m, en(0.4 * s, 0.95, -4.05), Vector3.new(0.24, 0.18, 0.12), OJO, M.Neon, {
			colision = false,
			consulta = false,
			sombra = false,
			nombre = "Ojo",
		})
		-- patas: delanteras más finas
		for _, z in { -1.8, 1.7 } do
			local cadera = p(0.72 * s, -0.2, z)
			local pie = p(0.72 * s, -2.2, z - 0.15)
			Kit.cilindro(m, cadera, pie, if z < 0 then 0.62 else 0.7, pelaje, M.Fabric, SIN)
			Kit.ovoide(
				m,
				CFrame.new(pie) * cf.Rotation * CFrame.new(0, -0.05, -0.15),
				Vector3.new(0.7, 0.35, 0.85),
				pelaje,
				M.Fabric,
				DETALLE
			)
		end
	end

	-- cola con la punta oscura
	local c0, c1, c2 = p(0, 0.4, 2.6), p(0, -0.3, 4.4), p(0, 0.2, 5.6)
	Kit.cilindro(m, c0, c1, 0.38, pelaje, M.Fabric, SIN)
	Kit.cilindro(m, c1, c2, 0.32, MANCHA, M.Fabric, SIN)

	-- rosetas sobre el lomo y los costados
	for _ = 1, 16 do
		local a = rng:NextNumber(-1.3, 1.3)
		local z = rng:NextNumber(-1.8, 1.8)
		local t = rng:NextNumber(0.25, 0.42)
		local cfMancha = en(math.sin(a) * 1.02, 0.1 + math.cos(a) * 0.92, z) * CFrame.Angles(0, 0, -a)
		Kit.ovoide(m, cfMancha, Vector3.new(t, 0.08, t * 1.2), MANCHA, M.Fabric, DETALLE)
	end

	-- soldar todo a la raíz
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= raiz then
			local w = Instance.new("Weld")
			w.Part0 = raiz
			w.Part1 = d
			w.C0 = raiz.CFrame:ToObjectSpace(d.CFrame)
			w.Parent = d
			d.Anchored = false
			d.Massless = true
		end
	end
	m.PrimaryPart = raiz
	return m
end

return Animales
