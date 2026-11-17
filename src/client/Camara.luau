--!strict
--[[
	Cámara de la selva: primera persona fija (la bloquea el servidor con CameraMode) y, aquí:

	  - brazos visibles: en primera persona Roblox oculta el cuerpo; se vuelven a mostrar los
	    brazos, y cuando el jugador lleva algo en la mano (hoy, la linterna encendida) se levantan
	    los dos hacia donde mira, con el objeto en la derecha;
	  - tensión: encuadre estable y bordes oscuros, sin giros, cabeceo ni zoom al caminar.

	Fuera de la selva no toca nada: esas cámaras son de Cinematica e Intro.
	Baúl: Camera Systems, Motion Sensitivity and Camera Comfort, Foliage Props and Scatter.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Partida.Camara
local BRAZOS = {
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"Right Arm",
	"Left Arm",
}

local Camara = {}

local function vineta(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "VinetaSelva"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	gui.Enabled = false
	-- cuatro franjas degradadas: negras en el borde, transparentes hacia el centro
	local bordes: { { tam: UDim2, pos: UDim2, giro: number } } = {
		{ tam = UDim2.fromScale(1, 0.3), pos = UDim2.fromScale(0, 0), giro = 90 },
		{ tam = UDim2.fromScale(1, 0.3), pos = UDim2.fromScale(0, 0.7), giro = -90 },
		{ tam = UDim2.fromScale(0.24, 1), pos = UDim2.fromScale(0, 0), giro = 0 },
		{ tam = UDim2.fromScale(0.24, 1), pos = UDim2.fromScale(0.76, 0), giro = 180 },
	}
	for _, b in bordes do
		local f = Instance.new("Frame")
		f.Size = b.tam
		f.Position = b.pos
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = b.giro
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - C.VINETA),
			NumberSequenceKeypoint.new(0.5, 1 - C.VINETA * 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = gui
	end
	return gui
end

-- Linterna de mano: solo la ve este cliente, soldada a su mano derecha.
local function crearObjeto(): Model
	local m = Instance.new("Model")
	m.Name = "LinternaMano"
	local function pieza(tam: Vector3, color: Color3, material: Enum.Material, z: number): Part
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = tam
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		-- el eje del cilindro (X) pasa a ser el eje Z del modelo
		p.CFrame = CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0)
		p.Parent = m
		return p
	end
	local cuerpo = pieza(Vector3.new(1.3, 0.34, 0.34), Color3.fromRGB(34, 36, 38), Enum.Material.Metal, 0)
	local cabeza = pieza(Vector3.new(0.4, 0.52, 0.52), Color3.fromRGB(52, 54, 56), Enum.Material.Metal, -0.8)
	local lente = pieza(Vector3.new(0.06, 0.44, 0.44), Color3.fromRGB(255, 244, 214), Enum.Material.Neon, -1.02)
	for _, p in { cabeza, lente } do
		local s = Instance.new("WeldConstraint")
		s.Part0 = cuerpo
		s.Part1 = p
		s.Parent = p
	end
	m.PrimaryPart = cuerpo
	return m
end

function Camara.iniciar()
	local jugador = Players.LocalPlayer
	local gui = vineta()
	gui.Parent = jugador:WaitForChild("PlayerGui")
	local objeto = crearObjeto()
	local soldadura: Weld? = nil

	local activa = false
	local alzar = 0 -- 0 brazos caídos, 1 levantados con el objeto
	local camaraAnterior: Camera? = nil
	local fovAnterior = 70

	local function enSelva(): boolean
		return jugador:GetAttribute("Zona") == "Partida"
	end
	local function sostiene(): boolean
		return enSelva() and jugador:GetAttribute("Linterna") == true
	end

	local function soltar()
		if soldadura then
			soldadura:Destroy()
			soldadura = nil
		end
		objeto.Parent = nil
	end

	local function agarrar(char: Model)
		local mano = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		local cuerpo = objeto.PrimaryPart
		if soldadura or not mano or not mano:IsA("BasePart") or not cuerpo then
			return
		end
		local s = Instance.new("Weld")
		s.Part0 = mano
		s.Part1 = cuerpo
		-- el brazo apunta con su eje -Y: la linterna sale de la mano en esa dirección
		local bajo = if mano.Name == "RightHand" then -0.25 else -1.1
		s.C0 = CFrame.new(0, bajo, -0.15) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		s.Parent = cuerpo
		soldadura = s
		objeto.Parent = char
	end

	jugador.CharacterRemoving:Connect(function()
		soltar()
		alzar = 0
	end)

	-- Brazos: después de las animaciones (Stepped), para poder imponer la pose.
	RunService.Stepped:Connect(function(_t: number, dt: number)
		local char = jugador.Character
		if not char then
			return
		end
		local quiere = sostiene()
		alzar += ((if quiere then 1 else 0) - alzar) * math.min(1, dt * 9)
		if quiere then
			agarrar(char)
		elseif soldadura and alzar < 0.05 then
			soltar()
		end
		if alzar < 0.01 then
			return
		end
		local cam = workspace.CurrentCamera
		local inclinacion = if cam then math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)) else 0
		local subir = (math.pi / 2 + inclinacion * 0.92) * alzar
		local der = char:FindFirstChild("RightUpperArm")
		local izq = char:FindFirstChild("LeftUpperArm")
		local hombroDer = der and der:FindFirstChild("RightShoulder")
		local hombroIzq = izq and izq:FindFirstChild("LeftShoulder")
		if hombroDer and hombroDer:IsA("Motor6D") and hombroIzq and hombroIzq:IsA("Motor6D") then
			-- R15: la derecha recta al frente con el objeto; la izquierda cruza a sujetarlo
			hombroDer.Transform = CFrame.Angles(subir, 0, math.rad(-6) * alzar)
			hombroIzq.Transform = CFrame.Angles(subir * 0.96, 0, math.rad(24) * alzar)
			for _, nombre in { "RightLowerArm", "LeftLowerArm" } do
				local antebrazo = char:FindFirstChild(nombre)
				local codo = antebrazo and antebrazo:FindFirstChildWhichIsA("Motor6D")
				if codo then
					codo.Transform = codo.Transform:Lerp(CFrame.new(), alzar)
				end
			end
		else
			-- R6: los hombros giran sobre otro eje
			local torso = char:FindFirstChild("Torso")
			local hd = torso and torso:FindFirstChild("Right Shoulder")
			local hi = torso and torso:FindFirstChild("Left Shoulder")
			if hd and hd:IsA("Motor6D") and hi and hi:IsA("Motor6D") then
				hd.Transform = CFrame.Angles(0, 0, subir)
				hi.Transform = CFrame.Angles(0, 0, -subir)
			end
		end
	end)

	-- Solo se modifica el FOV al entrar/salir. Nunca se escribe CFrame ni CameraOffset:
	-- el ratón, mando y pantalla táctil conservan toda la autoridad sobre la mirada.
	RunService:BindToRenderStep("CamaraSelva", Enum.RenderPriority.Camera.Value + 1, function()
		local dentro = enSelva()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		if activa and (not dentro or cam ~= camaraAnterior) then
			if camaraAnterior and camaraAnterior.CameraType == Enum.CameraType.Custom then
				camaraAnterior.FieldOfView = fovAnterior
			end
			activa = false
			soltar()
		end
		gui.Enabled = dentro
		if not dentro or cam.CameraType ~= Enum.CameraType.Custom then
			return
		end
		if not activa then
			camaraAnterior = cam
			fovAnterior = cam.FieldOfView
			cam.FieldOfView = C.FOV
			activa = true
		end
		local char = jugador.Character
		if not char then
			return
		end
		for _, nombre in BRAZOS do
			local parte = char:FindFirstChild(nombre)
			if parte and parte:IsA("BasePart") then
				parte.LocalTransparencyModifier = 0
			end
		end
	end)
end

return Camara
