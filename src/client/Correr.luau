--!strict
--[[
	Correr mientras se mantiene Shift (L3 en mando, botón en pantalla táctil), solo en las zonas
	de Config.Correr.ZONAS. Es el único sitio que escribe WalkSpeed (baúl: Cookbook - Players
	and Characters, "un solo escritor").
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Correr
local ACCION = "Correr"

local Correr = {}

function Correr.iniciar()
	local jugador = Players.LocalPlayer
	local corriendo = false
	local fovBase: number? = nil

	local function permitido(): boolean
		local zona = jugador:GetAttribute("Zona")
		return typeof(zona) == "string" and (C.ZONAS :: any)[zona] == true
	end

	local function aplicar()
		local char = jugador.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local rapido = corriendo and permitido()
		hum.WalkSpeed = if rapido then C.CORRER else C.CAMINAR
		local cam = workspace.CurrentCamera
		-- fuera de las zonas de correr la cámara es de otro sistema (primera persona en la selva)
		if cam and cam.CameraType == Enum.CameraType.Custom and (permitido() or fovBase) then
			fovBase = fovBase or cam.FieldOfView
			local extra = if rapido and not UserGameSettings.ReducedMotion then C.FOV_EXTRA else 0
			TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {
				FieldOfView = (fovBase :: number) + extra,
			}):Play()
		end
	end

	local function accion(_: string, estado: Enum.UserInputState): Enum.ContextActionResult
		if estado == Enum.UserInputState.Begin then
			corriendo = true
		elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
			corriendo = false
		end
		aplicar()
		return Enum.ContextActionResult.Pass
	end

	local function zona()
		corriendo = false
		aplicar() -- devuelve el campo de visión antes de soltar la cámara
		if permitido() then
			ContextActionService:BindAction(ACCION, accion, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
			ContextActionService:SetTitle(ACCION, "Correr")
			ContextActionService:SetPosition(ACCION, UDim2.new(1, -170, 1, -150))
		else
			ContextActionService:UnbindAction(ACCION)
		end
		-- la cámara de otras zonas tiene su propio campo de visión: se vuelve a leer al volver
		fovBase = nil
		if permitido() then
			aplicar()
		end
	end

	jugador:GetAttributeChangedSignal("Zona"):Connect(zona)
	jugador.CharacterAdded:Connect(function()
		corriendo = false
		task.defer(aplicar)
	end)
	zona()
end

return Correr
