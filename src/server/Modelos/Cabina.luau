--!strict
--[[
	Interior del helicóptero de carga donde ocurre la intro: bodega con ventanillas, asientos
	de red, cabina de mando con el piloto, objetos del botín, estante de paracaídas y rampa
	trasera que se abre. Coordenadas locales: suelo en y=0, morro hacia -Z, rampa en z=+16.
	El vuelo es falso: el escenario está quieto y el cliente mueve las nubes alrededor.
]]

local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)

local M = Enum.Material

local OLIVA = Color3.fromRGB(88, 94, 64)
local OLIVA_OSCURO = Color3.fromRGB(58, 62, 44)
local ACERO = Color3.fromRGB(104, 106, 102)
local SUELO = Color3.fromRGB(56, 58, 56)
local NEGRO = Color3.fromRGB(24, 24, 24)
local RED = Color3.fromRGB(150, 44, 38)
local LUZ = Color3.fromRGB(255, 232, 196)

export type Cabina = {
	modelo: Model,
	base: CFrame,
	asientos: { Seat },
	piloto: Model,
	objetos: { Model },
	paracaidas: { Model },
	luzRoja: BasePart,
	luzVerde: BasePart,
	abrirRampa: (segundos: number) -> (),
	destruir: () -> (),
}

local Cabina = {}

local SIN = { colision = false, sombra = false } :: Kit.Opciones

local function pegar(parte: BasePart, a: BasePart)
	parte.Anchored = false
	parte.Massless = true
	parte.CanCollide = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = parte
	w.Parent = parte
end

local function aviso(parte: BasePart, accion: string, objeto: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = accion
	pp.ObjectText = objeto
	pp.HoldDuration = 0.25
	pp.MaxActivationDistance = 8
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = parte
	return pp
end

-- Objetos del botín (modelos sencillos de ~1 stud). El primero que se crea es el agarre.
local function objeto(nombre: string, cf: CFrame, padre: Instance): Model
	local m = Kit.modelo(nombre, padre)
	local agarre: BasePart
	if nombre == "Linterna" then
		agarre = Kit.parte(m, cf * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.4, 0.45, 0.45), NEGRO, M.Metal, {
			forma = Enum.PartType.Cylinder,
		})
		Kit.parte(
			m,
			cf * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.12, 0.6, 0.6),
			Color3.fromRGB(255, 240, 180),
			M.Neon,
			{
				forma = Enum.PartType.Cylinder,
				colision = false,
			}
		)
	elseif nombre == "Botiquín" then
		agarre = Kit.parte(m, cf, Vector3.new(1.4, 1, 0.6), Color3.fromRGB(236, 232, 224), M.SmoothPlastic)
		Kit.parte(
			m,
			cf * CFrame.new(0, 0, -0.31),
			Vector3.new(0.7, 0.2, 0.02),
			Color3.fromRGB(200, 40, 40),
			M.SmoothPlastic,
			SIN
		)
		Kit.parte(
			m,
			cf * CFrame.new(0, 0, -0.31),
			Vector3.new(0.2, 0.7, 0.02),
			Color3.fromRGB(200, 40, 40),
			M.SmoothPlastic,
			SIN
		)
	elseif nombre == "Cantimplora" then
		agarre =
			Kit.ovoide(m, cf, Vector3.new(0.9, 1.1, 0.45), Color3.fromRGB(70, 92, 60), M.Fabric, { colision = true })
		Kit.parte(m, cf * CFrame.new(0, 0.65, 0), Vector3.new(0.3, 0.25, 0.3), NEGRO, M.Metal, SIN)
	elseif nombre == "Machete" then
		agarre =
			Kit.parte(m, cf * CFrame.new(-0.9, 0, 0), Vector3.new(1, 0.25, 0.3), Color3.fromRGB(60, 40, 28), M.Wood)
		Kit.parte(
			m,
			cf * CFrame.new(0.6, 0, 0),
			Vector3.new(2.2, 0.06, 0.45),
			Color3.fromRGB(180, 182, 184),
			M.Metal,
			SIN
		)
	elseif nombre == "Bengala" then
		agarre = Kit.parte(
			m,
			cf * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(1.2, 0.32, 0.32),
			Color3.fromRGB(210, 40, 30),
			M.SmoothPlastic,
			{
				forma = Enum.PartType.Cylinder,
			}
		)
		Kit.parte(
			m,
			cf * CFrame.new(0, 0.62, 0),
			Vector3.new(0.34, 0.1, 0.34),
			Color3.fromRGB(240, 240, 240),
			M.SmoothPlastic,
			SIN
		)
	elseif nombre == "Cuerda" then
		agarre = Kit.parte(
			m,
			cf * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.6, 1.3, 1.3),
			Color3.fromRGB(150, 120, 72),
			M.Fabric,
			{
				forma = Enum.PartType.Cylinder,
			}
		)
		Kit.parte(
			m,
			cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.62, 0.6, 0.6),
			Color3.fromRGB(40, 36, 30),
			M.Fabric,
			{
				forma = Enum.PartType.Cylinder,
				colision = false,
			}
		)
	elseif nombre == "Brújula" then
		agarre = Kit.parte(
			m,
			cf * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.18, 0.8, 0.8),
			Color3.fromRGB(176, 140, 70),
			M.Metal,
			{
				forma = Enum.PartType.Cylinder,
			}
		)
		Kit.parte(m, cf * CFrame.new(0, 0.1, 0), Vector3.new(0.05, 0.06, 0.5), Color3.fromRGB(200, 40, 40), M.Neon, SIN)
	else -- Radio
		agarre = Kit.parte(m, cf, Vector3.new(0.9, 1.3, 0.5), Color3.fromRGB(40, 44, 40), M.Plastic)
		Kit.parte(m, cf * CFrame.new(0.25, 1.1, 0), Vector3.new(0.1, 1, 0.1), NEGRO, M.Metal, SIN)
		Kit.parte(
			m,
			cf * CFrame.new(0, 0.25, -0.26),
			Vector3.new(0.5, 0.3, 0.02),
			Color3.fromRGB(120, 230, 120),
			M.Neon,
			SIN
		)
	end
	agarre.Name = "Agarre"
	m.PrimaryPart = agarre
	aviso(agarre, "Recoger", nombre)
	return m
end

local function mochila(cf: CFrame, padre: Instance): Model
	local m = Kit.modelo("Paracaidas", padre)
	local cuerpo = Kit.parte(m, cf, Vector3.new(1.8, 2.3, 0.9), OLIVA, M.Fabric, { nombre = "Agarre" })
	Kit.parte(m, cf * CFrame.new(0, -0.4, -0.47), Vector3.new(1.4, 1, 0.1), OLIVA_OSCURO, M.Fabric, SIN)
	for _, x in { -0.55, 0.55 } do
		Kit.parte(m, cf * CFrame.new(x, 0, 0.5), Vector3.new(0.25, 2.4, 0.1), NEGRO, M.Fabric, SIN)
	end
	Kit.parte(
		m,
		cf * CFrame.new(0, 0.85, -0.48),
		Vector3.new(0.5, 0.3, 0.06),
		Color3.fromRGB(230, 60, 40),
		M.SmoothPlastic,
		SIN
	)
	m.PrimaryPart = cuerpo
	aviso(cuerpo, "Ponerse", "Paracaídas")
	return m
end

-- Mochila visible a la espalda del jugador.
function Cabina.equiparMochila(char: Model)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) or char:FindFirstChild("MochilaParacaidas") then
		return
	end
	local m = mochila(torso.CFrame * CFrame.new(0, 0, 0.95) * CFrame.Angles(0, math.pi, 0), char)
	m.Name = "MochilaParacaidas"
	for _, d in m:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			pegar(d, torso)
		end
	end
end

local function piloto(cf: CFrame, padre: Instance): Model
	local ok, modelo = pcall(function(): Model
		local d = Instance.new("HumanoidDescription")
		local piel = Color3.fromRGB(176, 124, 92)
		d.HeadColor = piel
		d.LeftArmColor = OLIVA
		d.RightArmColor = OLIVA
		d.TorsoColor = OLIVA
		d.LeftLegColor = OLIVA_OSCURO
		d.RightLegColor = OLIVA_OSCURO
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	local m: Model
	if ok and modelo then
		m = modelo
		m.Name = "Piloto"
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local raiz = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			raiz.Anchored = true
		end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
		m:PivotTo(cf)
		-- sentado con las manos en los mandos y la cabeza girada hacia la bodega
		local function girar(parte: string, motor: string, angulos: CFrame)
			local pa = m:FindFirstChild(parte)
			local mo = pa and pa:FindFirstChild(motor)
			if mo and mo:IsA("Motor6D") then
				mo.C0 *= angulos
			end
		end
		for _, lado in { "Left", "Right" } do
			girar(lado .. "UpperLeg", lado .. "Hip", CFrame.Angles(math.rad(90), 0, 0))
			girar(lado .. "LowerLeg", lado .. "Knee", CFrame.Angles(math.rad(-90), 0, 0))
			girar(lado .. "UpperArm", lado .. "Shoulder", CFrame.Angles(math.rad(55), 0, 0))
			girar(lado .. "LowerArm", lado .. "Elbow", CFrame.Angles(math.rad(25), 0, 0))
		end
		girar("Head", "Neck", CFrame.Angles(0, math.rad(-40), 0))
	else
		warn("[Selva] no se pudo crear el piloto R15, se usa uno de bloques:", modelo)
		m = Kit.modelo("Piloto", padre)
		Kit.parte(m, cf, Vector3.new(2, 2, 1), OLIVA, M.Fabric, { nombre = "Torso", colision = false })
		Kit.parte(
			m,
			cf * CFrame.new(0, 1.6, 0),
			Vector3.new(1.2, 1.2, 1.2),
			Color3.fromRGB(176, 124, 92),
			M.SmoothPlastic,
			{
				nombre = "Head",
				colision = false,
			}
		)
	end
	m.Parent = padre

	-- gorra, gafas de aviador y cascos; ojos rojos ocultos hasta la posesión
	local cabeza = m:FindFirstChild("Head") :: BasePart?
	if cabeza then
		local h = cabeza.CFrame
		local t = cabeza.Size
		local function accesorio(
			off: CFrame,
			tam: Vector3,
			color: Color3,
			material: Enum.Material,
			o: Kit.Opciones?
		): BasePart
			local p = Kit.parte(m, h * off, tam, color, material, o or SIN)
			pegar(p, cabeza)
			return p
		end
		accesorio(
			CFrame.new(0, t.Y * 0.42, 0.05),
			Vector3.new(t.X * 1.05, t.Y * 0.32, t.Z * 1.05),
			OLIVA_OSCURO,
			M.Fabric
		)
		accesorio(CFrame.new(0, t.Y * 0.3, -t.Z * 0.6), Vector3.new(t.X * 0.9, 0.08, t.Z * 0.4), OLIVA_OSCURO, M.Fabric)
		accesorio(
			CFrame.new(0, t.Y * 0.1, -t.Z * 0.52),
			Vector3.new(t.X * 0.8, t.Y * 0.18, 0.08),
			Color3.fromRGB(20, 20, 26),
			M.Glass,
			{
				colision = false,
				sombra = false,
				reflejo = 0.4,
			}
		)
		for _, s in { -1, 1 } do
			accesorio(
				CFrame.new(s * t.X * 0.55, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Vector3.new(0.35, 0.6, 0.6),
				NEGRO,
				M.Plastic,
				{
					forma = Enum.PartType.Cylinder,
					colision = false,
					sombra = false,
				}
			)
			local ojo = accesorio(
				CFrame.new(s * t.X * 0.17, t.Y * 0.1, -t.Z * 0.56),
				Vector3.one * 0.18,
				Color3.fromRGB(255, 30, 20),
				M.Neon,
				{
					forma = Enum.PartType.Ball,
					colision = false,
					sombra = false,
					transparencia = 1,
					nombre = "Ojo",
				}
			)
			if s == 1 then
				local luz = Kit.luz(ojo, Color3.fromRGB(255, 30, 20), 10, 3)
				luz.Name = "LuzOjos"
				luz.Enabled = false
			end
		end
		-- micrófono
		accesorio(
			CFrame.new(-t.X * 0.45, -t.Y * 0.2, -t.Z * 0.35) * CFrame.Angles(0, math.rad(-50), 0),
			Vector3.new(0.08, 0.08, 0.8),
			NEGRO,
			M.Plastic
		)
	end
	return m
end

function Cabina.construir(posicion: Vector3, padre: Instance): Cabina
	local m = Kit.modelo("IntroCabina", padre)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local base = CFrame.new(posicion)
	local function c(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	-- suelo, techo y costillas
	Kit.parte(m, c(0, -0.5, -4), Vector3.new(15.2, 1, 42), SUELO, M.DiamondPlate)
	Kit.parte(m, c(0, 10.3, -4), Vector3.new(15.2, 0.6, 42), OLIVA_OSCURO, M.Metal)
	for _, z in { -15, -9, -3, 3, 9, 15 } do
		for _, s in { -1, 1 } do
			Kit.parte(m, c(s * 6.85, 5, z), Vector3.new(0.3, 10, 0.5), ACERO, M.Metal, SIN)
		end
		Kit.parte(m, c(0, 9.85, z), Vector3.new(14, 0.3, 0.5), ACERO, M.Metal, SIN)
	end
	-- paredes con ventanillas
	local ventanas = { -12, -6, 0, 6, 12 }
	for _, s in { -1, 1 } do
		Kit.parte(m, c(s * 7.3, 2.1, 0), Vector3.new(0.6, 4.2, 32), OLIVA, M.Metal)
		Kit.parte(m, c(s * 7.3, 8.4, 0), Vector3.new(0.6, 3.2, 32), OLIVA, M.Metal)
		local desde = -16
		for _, z in ventanas do
			local hasta = z - 1.4
			Kit.parte(m, c(s * 7.3, 5.5, (desde + hasta) / 2), Vector3.new(0.6, 2.6, hasta - desde), OLIVA, M.Metal)
			Kit.parte(m, c(s * 7.3, 5.5, z), Vector3.new(0.2, 2.6, 2.8), Color3.fromRGB(150, 180, 200), M.Glass, {
				transparencia = 0.55,
				reflejo = 0.1,
			})
			desde = z + 1.4
		end
		Kit.parte(m, c(s * 7.3, 5.5, (desde + 16) / 2), Vector3.new(0.6, 2.6, 16 - desde), OLIVA, M.Metal)
		-- cabina de mando
		Kit.parte(m, c(s * 7.3, 5, -20.5), Vector3.new(0.6, 10, 9), OLIVA, M.Metal)
	end
	-- luces del techo
	for _, z in { -10, -2, 6, 13 } do
		local foco = Kit.parte(m, c(0, 9.8, z), Vector3.new(1.4, 0.3, 3), LUZ, M.Neon, SIN)
		Kit.luz(foco, LUZ, 18, 1.1)
		Kit.etiquetar(foco, "LuzCabina")
	end
	-- balizas de alarma (las enciende el cliente durante la cuenta atrás)
	for _, x in { -4, 4 } do
		local alarma = Kit.parte(m, c(x, 9.6, 0), Vector3.new(0.8, 0.6, 0.8), Color3.fromRGB(120, 20, 16), M.Neon, SIN)
		local foco = Instance.new("SpotLight")
		foco.Color = Color3.fromRGB(255, 40, 30)
		foco.Range = 26
		foco.Angle = 70
		foco.Brightness = 4
		foco.Face = Enum.NormalId.Front
		foco.Enabled = false
		foco.Parent = alarma
		Kit.etiquetar(alarma, "Alarma")
	end

	-- asientos de red mirando al pasillo
	local asientos = {}
	for _, s in { -1, 1 } do
		for _, z in { -10, -4.5 } do
			local pos = (c(s * 5.6, 1.9, z)).Position
			local asiento = Instance.new("Seat")
			asiento.Anchored = true
			asiento.Size = Vector3.new(2.4, 0.5, 2.2)
			asiento.CFrame = CFrame.lookAt(pos, pos + base:VectorToWorldSpace(Vector3.new(-s, 0, 0)))
			asiento.Color = RED
			asiento.Material = M.Fabric
			asiento.TopSurface = Enum.SurfaceType.Smooth
			asiento.Parent = m
			table.insert(asientos, asiento)
			Kit.parte(m, c(s * 6.75, 4.2, z), Vector3.new(0.2, 3.8, 2.6), RED, M.Fabric, SIN)
			for _, dz in { -1, 1 } do
				Kit.parte(m, c(s * 5.6, 0.85, z + dz), Vector3.new(0.2, 1.7, 0.2), ACERO, M.Metal, SIN)
			end
		end
	end

	-- mamparo con puerta a la cabina de mando
	for _, s in { -1, 1 } do
		Kit.parte(m, c(s * 5, 5, -16), Vector3.new(4.6, 10, 0.5), OLIVA_OSCURO, M.Metal)
	end
	Kit.parte(m, c(0, 8.9, -16), Vector3.new(5.4, 2.2, 0.5), OLIVA_OSCURO, M.Metal)
	-- parabrisas, consola y asientos de los pilotos
	Kit.parte(m, c(0, 1.6, -24.9), Vector3.new(15, 3.2, 0.5), OLIVA_OSCURO, M.Metal)
	local inclinado = c(0, 6.4, -24.2) * CFrame.Angles(0.3, 0, 0)
	Kit.parte(m, inclinado, Vector3.new(14.4, 6.6, 0.3), Color3.fromRGB(160, 190, 210), M.Glass, {
		transparencia = 0.7,
		reflejo = 0.1,
	})
	Kit.parte(m, inclinado, Vector3.new(0.5, 6.6, 0.45), NEGRO, M.Metal, SIN)
	Kit.parte(m, c(0, 3.3, -23.2), Vector3.new(12, 1.6, 2.4), Color3.fromRGB(46, 48, 48), M.Metal)
	for i, x in { -4.2, -1.4, 1.4, 4.2 } do
		local pantalla = Kit.parte(
			m,
			c(x, 4.6, -23.9),
			Vector3.new(2.2, 1.4, 0.15),
			if i % 2 == 0 then Color3.fromRGB(110, 230, 140) else Color3.fromRGB(255, 186, 80),
			M.Neon,
			SIN
		)
		pantalla.Transparency = 0.15
	end
	for _, x in { -2.9, 2.9 } do
		Kit.parte(m, c(x, 1.8, -19.8), Vector3.new(2.6, 0.5, 2.4), Color3.fromRGB(50, 40, 34), M.Leather)
		Kit.parte(m, c(x, 3.9, -18.5), Vector3.new(2.6, 4.2, 0.5), Color3.fromRGB(50, 40, 34), M.Leather)
		Kit.cilindro(m, c(x, 0, -21.6).Position, c(x, 2.6, -21.4).Position, 0.25, NEGRO, M.Metal)
	end
	local tablero =
		Kit.parte(m, c(0, 4.3, -22.2), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(120, 230, 150), M.Neon, SIN)
	Kit.luz(tablero, Color3.fromRGB(150, 255, 190), 9, 0.8)
	local pilotoModelo = piloto(c(-2.9, 3.55, -19.3), m)

	-- carga, estantes y botín
	Kit.parte(m, c(0, 1, 6.2), Vector3.new(3, 2, 3.4), Color3.fromRGB(116, 90, 60), M.WoodPlanks)
	Kit.parte(m, c(0, 1, 6.2), Vector3.new(3.1, 0.2, 3.5), Color3.fromRGB(200, 170, 60), M.Fabric, SIN)
	for _, s in { -1, 1 } do
		Kit.parte(m, c(s * 6.4, 3.2, 6), Vector3.new(1.4, 0.2, 9), ACERO, M.Metal)
	end
	local sitios: { [string]: CFrame } = {
		Linterna = c(-6.3, 3.55, 2.5),
		["Botiquín"] = c(-6.3, 3.8, 6) * CFrame.Angles(0, math.pi / 2, 0),
		Cantimplora = c(-6.3, 3.85, 9.5),
		Machete = c(0, 2.15, 5.4) * CFrame.Angles(0, 0.4, 0),
		Bengala = c(0.9, 2.2, 7.2),
		Cuerda = c(6.3, 3.6, 2.6),
		["Brújula"] = c(-0.9, 2.12, 6.9),
		Radio = c(6.3, 3.95, 6.4) * CFrame.Angles(0, -math.pi / 2, 0),
	}
	local objetos = {}
	for nombre, cf in sitios do
		table.insert(objetos, objeto(nombre, cf, m))
	end

	-- estante de paracaídas junto a la rampa
	Kit.parte(m, c(6.6, 6.9, 12.6), Vector3.new(0.3, 0.3, 6.4), ACERO, M.Metal)
	local paracaidas = {}
	for _, z in { 10.4, 11.9, 13.4, 14.9 } do
		table.insert(paracaidas, mochila(c(6.2, 5.4, z) * CFrame.Angles(0, -math.pi / 2, 0), m))
	end

	-- luces de salto sobre la rampa
	local luzRoja =
		Kit.parte(m, c(-1.2, 9.6, 15.4), Vector3.new(0.9, 0.5, 0.5), Color3.fromRGB(255, 40, 30), M.Neon, SIN)
	Kit.luz(luzRoja, Color3.fromRGB(255, 50, 40), 12, 1.5)
	local luzVerde =
		Kit.parte(m, c(1.2, 9.6, 15.4), Vector3.new(0.9, 0.5, 0.5), Color3.fromRGB(30, 60, 34), M.SmoothPlastic, SIN)

	-- rampa trasera: gira sobre la bisagra del suelo; cerrada queda vertical
	local bisagra = c(0, 0, 16.3)
	local piezasRampa: { { parte: BasePart, off: CFrame } } = {}
	local function pieza(off: CFrame, tam: Vector3, color: Color3, material: Enum.Material)
		local p = Kit.parte(m, bisagra, tam, color, material)
		table.insert(piezasRampa, { parte = p, off = off })
	end
	pieza(CFrame.new(0, 0, 5.4), Vector3.new(14.6, 0.6, 10.8), SUELO, M.DiamondPlate)
	for k = -3, 3 do
		pieza(
			CFrame.new(k * 2, 0.32, 10.3),
			Vector3.new(1, 0.05, 0.9),
			if k % 2 == 0 then Color3.fromRGB(230, 190, 40) else NEGRO,
			M.SmoothPlastic
		)
	end
	local function colocar(angulo: number)
		local giro = bisagra * CFrame.Angles(angulo, 0, 0)
		for _, pr in piezasRampa do
			pr.parte.CFrame = giro * pr.off
		end
	end
	colocar(-math.pi / 2)

	local abierta = false
	local function abrirRampa(segundos: number)
		if abierta then
			return
		end
		abierta = true
		task.spawn(function()
			local t0 = os.clock()
			while true do
				local f = math.min(1, (os.clock() - t0) / segundos)
				local e = f * f * (3 - 2 * f)
				colocar(-math.pi / 2 + (math.pi / 2 + 0.24) * e)
				if f >= 1 or not m.Parent then
					break
				end
				task.wait()
			end
		end)
	end

	return {
		modelo = m,
		base = base,
		asientos = asientos,
		piloto = pilotoModelo,
		objetos = objetos,
		paracaidas = paracaidas,
		luzRoja = luzRoja,
		luzVerde = luzVerde,
		abrirRampa = abrirRampa,
		destruir = function()
			m:Destroy()
		end,
	}
end

return Cabina
