--!strict
--[[
	Linterna (cliente). Con F, el botón Y del mando o el botón táctil se pide al servidor
	encender o apagar. La luz propia la dibuja este cliente: un foco que sale de la cabeza y
	apunta hacia donde mira la cámara, para poder alumbrar arriba y abajo. El foco que el
	servidor cuelga del personaje (el que ven los demás) se oculta aquí para no verla doble.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local L = Config.Linterna
local ACCION = "Linterna"
local NOMBRE_FOCO = "FocoLinterna"

local Linterna = {}

function Linterna.iniciar()
	local jugador = Players.LocalPlayer
	local remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Linterna") :: RemoteEvent

	local foco = Instance.new("Part")
	foco.Name = "LinternaLocal"
	foco.Size = Vector3.new(0.2, 0.2, 0.2)
	foco.Transparency = 1
	foco.Anchored = true
	foco.CanCollide = false
	foco.CanTouch = false
	foco.CanQuery = false
	local luz = Instance.new("SpotLight")
	luz.Face = Enum.NormalId.Front
	luz.Range = L.ALCANCE
	luz.Angle = L.ANGULO
	luz.Brightness = L.BRILLO
	luz.Color = L.COLOR
	luz.Shadows = true
	luz.Enabled = false
	luz.Parent = foco
	foco.Parent = workspace

	local function encendida(): boolean
		return jugador:GetAttribute("Linterna") == true
	end

	-- el foco del servidor en el personaje propio: apagado solo en este cliente
	local function ocultarPropio(char: Model)
		local function revisar(hijo: Instance)
			if hijo.Name == NOMBRE_FOCO then
				local propia = hijo:FindFirstChildOfClass("SpotLight") or hijo:WaitForChild("SpotLight", 2)
				if propia and propia:IsA("SpotLight") then
					propia.Enabled = false
				end
			end
		end
		char.ChildAdded:Connect(revisar)
		for _, hijo in char:GetChildren() do
			task.spawn(revisar, hijo)
		end
	end
	jugador.CharacterAdded:Connect(ocultarPropio)
	if jugador.Character then
		ocultarPropio(jugador.Character)
	end

	RunService:BindToRenderStep("Linterna", Enum.RenderPriority.Camera.Value + 2, function()
		local on = encendida()
		luz.Enabled = on
		if not on then
			return
		end
		-- cerca de la serpiente la linterna falla: cortes breves, más seguidos cuanto más cerca
		local miedo = (jugador:GetAttribute("MiedoSerpiente") or 0) :: number
		local t = os.clock()
		local corte = miedo > 0.05 and math.noise(t * 7, 3.3) > 0.55 - miedo * 0.6
		luz.Brightness = if corte
			then L.BRILLO * 0.05
			else L.BRILLO * (1 - miedo * 0.25 * (math.noise(t * 23, 1.1) + 0.5))
		local char = jugador.Character
		local cabeza = char and char:FindFirstChild("Head")
		local cam = workspace.CurrentCamera
		if cabeza and cabeza:IsA("BasePart") and cam then
			-- sale de la cabeza, no de la cámara: así no alumbra la espalda del personaje
			foco.CFrame = CFrame.new(cabeza.Position + cam.CFrame.LookVector * 1.2) * cam.CFrame.Rotation
		end
	end)

	local function pulsar(_nombre: string, estado: Enum.UserInputState): Enum.ContextActionResult
		if estado == Enum.UserInputState.Begin then
			remoto:FireServer(not encendida())
		end
		return Enum.ContextActionResult.Sink
	end

	-- la acción (y su botón táctil) solo existe mientras el jugador lleva la linterna en la selva
	local ligada = false
	local function actualizar()
		local disponible = jugador:GetAttribute("TieneLinterna") == true
		if disponible and not ligada then
			ligada = true
			ContextActionService:BindAction(ACCION, pulsar, true, L.TECLA, L.BOTON_MANDO)
			ContextActionService:SetTitle(ACCION, "Linterna")
			ContextActionService:SetPosition(ACCION, UDim2.new(1, -150, 1, -210))
		elseif not disponible and ligada then
			ligada = false
			ContextActionService:UnbindAction(ACCION)
		end
	end
	jugador:GetAttributeChangedSignal("TieneLinterna"):Connect(actualizar)
	actualizar()
end

return Linterna
