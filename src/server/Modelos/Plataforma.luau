--!strict
-- Plataforma offshore. Si existe la plantilla importada (ReplicatedStorage.Modelos.Plataforma,
-- de art/export/Plataforma.glb) se usa esa; si no, se construye una de respaldo con partes.
-- No escribe ni limpia Terrain (el mar lo pone Lobby/Mar).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Plataforma = {}

local P = Config.Lobby.Plataforma

-- Lo que el lobby necesita de la plataforma: dónde aparecen los jugadores, dónde van los
-- helicópteros y cómo pasar de metros del modelo original a studs del mundo.
export type Importada = {
	modelo: Model,
	spawn: CFrame,
	helipuertos: { Vector3 }, -- centro de la superficie de cada helipuerto
	punto: (metros: Vector3) -> Vector3, -- x, y en el plano de la plataforma; z hacia arriba
	studsPorMetro: number,
}

local function parteDe(i: Instance?): BasePart?
	if not i then
		return nil
	elseif i:IsA("BasePart") then
		return i
	end
	return i:FindFirstChildWhichIsA("BasePart", true)
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Superficie de una parte bajo un punto, mirando solo esa parte.
local function techo(parte: BasePart, desde: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { parte }
	local r = workspace:Raycast(desde + Vector3.yAxis * 60, Vector3.yAxis * -120, params)
	return if r then r.Position else desde + Vector3.yAxis * parte.Size.Y / 2
end

function Plataforma.importada(c: Vector3, padre: Instance): Importada?
	local modelos = ReplicatedStorage:FindFirstChild("Modelos")
	local modelo = modelos and modelos:FindFirstChild("Plataforma")
	if not (modelo and modelo:IsA("Model")) then
		return nil
	end
	local function pad(nombre: string): BasePart?
		return parteDe(modelo:FindFirstChild(("PLAT_Helideck_%s_Pad"):format(nombre), true))
	end
	local este, oeste, ne, se = pad("East"), pad("West"), pad("NE"), pad("SE")
	if not (este and oeste and ne and se) then
		warn("[Lobby] la plataforma importada no tiene los helipuertos East, West, NE y SE; uso la de respaldo")
		return nil
	end

	-- escala: la distancia entre los helipuertos East y West es conocida en metros
	local k = P.STUDS_POR_METRO * P.ESCALA
	local actual = (este.Position - oeste.Position).Magnitude / P.SEPARACION_HELIPUERTOS
	modelo:ScaleTo(modelo:GetScale() * k / actual)

	-- ejes del modelo original en el mundo: x hacia East, y hacia NE desde SE, z arriba
	local ex = plano(este.Position - oeste.Position).Unit
	local ey = plano(ne.Position - se.Position)
	ey = (ey - ex * ey:Dot(ex)).Unit
	local medio = (este.Position + oeste.Position) / 2
	local origen = Vector3.new(medio.X, medio.Y - P.ALTURA_HELIPUERTOS * k, medio.Z)
	modelo:PivotTo(CFrame.new(c - origen) * modelo:GetPivot())
	local function punto(m: Vector3): Vector3
		return c + ex * m.X * k + ey * m.Y * k + Vector3.yAxis * m.Z * k
	end

	-- todo anclado; las lámparas brillan y unas cuantas iluminan de verdad
	local blancas = 0
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			local blanca = string.find(d.Name, "^PLAT_Lamp_White") ~= nil
			local roja = string.find(d.Name, "^PLAT_Lamp_Red") ~= nil
			if blanca or roja then
				d.Material = Enum.Material.Neon
				d.Color = if roja then Color3.fromRGB(255, 50, 40) else Color3.fromRGB(255, 226, 170)
				d.CanCollide = false
				d.CastShadow = false
				if blanca then
					blancas += 1
					if blancas % 3 == 0 and blancas / 3 <= P.LUCES_MAX then
						Kit.luz(d, Color3.fromRGB(255, 210, 150), 32, 1.2)
					end
				end
			end
		end
	end
	modelo.Name = "PlataformaOffshore"
	modelo.Parent = padre

	local helipuertos: { Vector3 } = {}
	for _, nombre in P.HELIPUERTOS do
		local p = pad(nombre)
		if p then
			table.insert(helipuertos, techo(p, p.Position))
		end
	end

	-- aparecer sobre la cubierta, mirando hacia la torre
	local pie = punto(P.SPAWN)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { modelo }
	local r = workspace:Raycast(pie + Vector3.yAxis * 400, Vector3.yAxis * -600, params)
	local suelo = if r then r.Position else punto(Vector3.new(P.SPAWN.X, P.SPAWN.Y, 30))
	local mirar = punto(P.MIRAR)
	local spawn = CFrame.lookAt(suelo + Vector3.yAxis * 3, Vector3.new(mirar.X, suelo.Y + 3, mirar.Z))

	return { modelo = modelo, spawn = spawn, helipuertos = helipuertos, punto = punto, studsPorMetro = k }
end
local M = Enum.Material
local ACERO = Color3.fromRGB(48, 60, 68)
local BORDE = Color3.fromRGB(89, 102, 108)
local AMBAR = Color3.fromRGB(241, 170, 46)
local BLANCO = Color3.fromRGB(199, 220, 224)

function Plataforma.baranda(padre: Instance, a: Vector3, b: Vector3)
	local pasos = math.max(1, math.ceil((b - a).Magnitude / 7))
	for i = 0, pasos do
		local p = a:Lerp(b, i / pasos)
		Kit.cilindro(padre, p, p + Vector3.yAxis * 3.5, 0.22, AMBAR, M.Metal)
	end
	for _, y in { 1.7, 3.3 } do
		Kit.cilindro(padre, a + Vector3.yAxis * y, b + Vector3.yAxis * y, 0.16, AMBAR, M.Metal)
	end
	Kit.viga(padre, a + Vector3.yAxis * 0.3, b + Vector3.yAxis * 0.3, 0.12, 0.55, BORDE, M.Metal)
end

function Plataforma.pasarela(padre: Instance, a: Vector3, b: Vector3)
	Kit.viga(padre, a - Vector3.yAxis * 0.25, b - Vector3.yAxis * 0.25, 10, 0.5, BORDE, M.DiamondPlate)
	local lado = Vector3.new(-(b - a).Z, 0, (b - a).X).Unit
	for _, signo in { -1, 1 } do
		local o = lado * signo * 4.8
		Plataforma.baranda(padre, a + o, b + o)
		Kit.viga(padre, a + o - Vector3.yAxis * 1.4, b + o - Vector3.yAxis * 1.4, 0.5, 2, ACERO, M.Metal)
	end
end

function Plataforma.foco(padre: Instance, pie: Vector3, mirar: Vector3)
	Kit.cilindro(padre, pie, pie + Vector3.yAxis * 14, 0.45, BORDE, M.Metal)
	local p = pie + Vector3.yAxis * 14
	local carcasa = Kit.parte(padre, CFrame.lookAt(p, mirar), Vector3.new(2.3, 1.3, 0.7), ACERO, M.Metal)
	local lente = Kit.parte(
		padre,
		carcasa.CFrame * CFrame.new(0, 0, -0.4),
		Vector3.new(1.9, 0.9, 0.08),
		BLANCO,
		M.Neon,
		Kit.FOLLAJE
	)
	local luz = Instance.new("SpotLight")
	luz.Face = Enum.NormalId.Front
	luz.Angle = 85
	luz.Range = 65
	luz.Brightness = 2.2
	luz.Color = BLANCO
	luz.Shadows = true
	luz.Parent = lente
end

local function letrero(padre: Instance, cf: CFrame, texto: string, tam: Vector3)
	local p = Kit.parte(padre, cf, tam, ACERO, M.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 35
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = BLANCO
	label.Text = texto
	label.Parent = gui
end

function Plataforma.construir(c: Vector3, padre: Instance)
	local m = Kit.modelo("PlataformaOffshore", padre)
	-- Cubierta 80 x 80, chapa modular y vigas estructurales visibles bajo el borde.
	for x = -2, 2 do
		for z = -2, 2 do
			local centro = c + Vector3.new(x * 16, -0.5, z * 16)
			Kit.parte(
				m,
				CFrame.new(centro),
				Vector3.new(15.9, 1, 15.9),
				if (x + z) % 2 == 0 then ACERO else BORDE,
				M.DiamondPlate
			)
		end
	end
	for _, x in { -35, 0, 35 } do
		Kit.parte(m, CFrame.new(c + Vector3.new(x, -3, 0)), Vector3.new(1.5, 5, 80), ACERO, M.Metal)
	end
	for _, z in { -35, 0, 35 } do
		Kit.parte(m, CFrame.new(c + Vector3.new(0, -3, z)), Vector3.new(80, 5, 1.5), ACERO, M.Metal)
	end
	for _, x in { -33, 33 } do
		for _, z in { -33, 33 } do
			local p = c + Vector3.new(x, -1, z)
			Kit.cilindro(m, p - Vector3.yAxis * 40, p, 4, BORDE, M.Metal)
			Kit.cilindro(m, p - Vector3.yAxis * 22, p - Vector3.yAxis * 18, 4.3, AMBAR, M.Metal)
			local s = if x < 0 then 1 else -1
			Kit.viga(m, p - Vector3.yAxis * 17, p + Vector3.new(s * 23, -3, 0), 1.4, 1.4, ACERO, M.Metal)
		end
	end
	-- Borde sur cerrado; los extremos este/oeste tienen huecos para las pasarelas.
	Plataforma.baranda(m, c + Vector3.new(-40, 0, 40), c + Vector3.new(40, 0, 40))
	for _, x in { -40, 40 } do
		for _, tramo in { { -40, -34 }, { -22, 22 }, { 34, 40 } } do
			Plataforma.baranda(m, c + Vector3.new(x, 0, tramo[1]), c + Vector3.new(x, 0, tramo[2]))
		end
	end
	-- Sala de operaciones elevada detrás de la llegada, con acceso central libre.
	local sala = c + Vector3.new(0, 0, 29)
	Kit.parte(m, CFrame.new(sala + Vector3.new(0, 0.2, 0)), Vector3.new(28, 0.4, 15), ACERO, M.Metal)
	Kit.parte(m, CFrame.new(sala + Vector3.new(0, 9, 0)), Vector3.new(29, 0.5, 16), BORDE, M.CorrodedMetal)
	Kit.parte(m, CFrame.new(sala + Vector3.new(0, 4.5, 7)), Vector3.new(28, 9, 0.5), ACERO, M.Metal)
	for _, x in { -13.5, 13.5 } do
		Kit.parte(m, CFrame.new(sala + Vector3.new(x, 4.5, 0)), Vector3.new(0.5, 9, 14), BORDE, M.Metal)
	end
	letrero(m, CFrame.new(sala + Vector3.new(0, 7, -7.1)), "AMAZONAS / BASE MARÍTIMA", Vector3.new(26, 2, 0.3))
	letrero(
		m,
		CFrame.new(c + Vector3.new(0, 4, 14)),
		"EMBARQUE →\nVUELOS 01—04 · EQUIPOS DE HASTA 4",
		Vector3.new(15, 5, 0.4)
	)
	for _, x in { -25, 25 } do
		Plataforma.foco(m, c + Vector3.new(x, 0, 25), c + Vector3.new(0, 0, -8))
	end
	-- Contenedores y conducciones en el perímetro, sin cortar el paso a los vuelos.
	for i, x in { -29, 29 } do
		local caja = c + Vector3.new(x, 3, 22)
		Kit.parte(
			m,
			CFrame.new(caja),
			Vector3.new(9, 6, 14),
			if i == 1 then Color3.fromRGB(132, 72, 39) else Color3.fromRGB(32, 81, 88),
			M.Metal
		)
		for k = -3, 3 do
			Kit.parte(m, CFrame.new(caja + Vector3.new(0, 0, k * 1.8)), Vector3.new(9.15, 6, 0.12), BORDE, M.Metal)
		end
	end
	-- Torre de control: celosía de acero, cabina acristalada y baliza roja.
	local torre = c + Vector3.new(0, 0, -27)
	for _, x in { -5, 5 } do
		for _, z in { -5, 5 } do
			local pie = torre + Vector3.new(x, 0, z)
			Kit.cilindro(m, pie, pie + Vector3.yAxis * 22, 0.65, BORDE, M.Metal)
			Kit.viga(m, pie + Vector3.yAxis * 2, torre + Vector3.new(-x, 19, z), 0.35, 0.35, ACERO, M.Metal)
		end
	end
	Kit.parte(m, CFrame.new(torre + Vector3.yAxis * 22), Vector3.new(15, 1, 15), BORDE, M.DiamondPlate)
	Kit.parte(m, CFrame.new(torre + Vector3.yAxis * 30), Vector3.new(16, 0.7, 16), ACERO, M.Metal)
	for _, x in { -7, 7 } do
		Kit.parte(
			m,
			CFrame.new(torre + Vector3.new(x, 26, 0)),
			Vector3.new(0.2, 7, 14),
			Color3.fromRGB(64, 105, 117),
			M.Glass,
			{ transparencia = 0.35 }
		)
	end
	for _, z in { -7, 7 } do
		Kit.parte(
			m,
			CFrame.new(torre + Vector3.new(0, 26, z)),
			Vector3.new(14, 7, 0.2),
			Color3.fromRGB(64, 105, 117),
			M.Glass,
			{ transparencia = 0.35 }
		)
	end
	local lampara =
		Kit.parte(m, CFrame.new(torre + Vector3.yAxis * 29), Vector3.new(7, 0.15, 1), BLANCO, M.Neon, Kit.FOLLAJE)
	Kit.luz(lampara, BLANCO, 18, 0.8)
	Kit.cilindro(m, torre + Vector3.yAxis * 30, torre + Vector3.yAxis * 38, 0.25, BORDE, M.Metal)
	local baliza = Kit.parte(
		m,
		CFrame.new(torre + Vector3.yAxis * 38),
		Vector3.new(0.7, 0.7, 0.7),
		Color3.fromRGB(240, 57, 39),
		M.Neon,
		Kit.FOLLAJE
	)
	Kit.etiquetar(baliza, "Baliza")
	return m
end

return Plataforma
