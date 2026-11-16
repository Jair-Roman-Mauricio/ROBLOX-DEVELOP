--!strict
--[[
	Cámara de película en la selva: sobre el hombro, cerca del personaje y con el campo de
	visión algo cerrado. La distancia la fija el servidor (CameraMin/MaxZoomDistance iguales en
	Partida), así que el jugador no puede alejarla. Aquí solo se desplaza al hombro y se ajusta
	el campo de visión, con una transición suave al entrar y salir de la selva.

	Fuera de la selva (lobby, helicóptero, caída) no toca nada: esas cámaras son de Cinematica
	e Intro.
	Baúl: Camera Systems, Motion Sensitivity and Camera Comfort (sin balanceos añadidos).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Partida.Camara
local FOV_NORMAL = 70

local Camara = {}

function Camara.iniciar()
	local jugador = Players.LocalPlayer
	local activa = false
	local mezcla = 0

	RunService:BindToRenderStep("CamaraSelva", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
		local enSelva = jugador:GetAttribute("Zona") == "Partida"
		if not enSelva and not activa then
			return
		end
		activa = true
		local objetivo = if enSelva then 1 else 0
		mezcla += (objetivo - mezcla) * math.min(1, dt * 4)
		if not enSelva and mezcla < 0.01 then
			mezcla = 0
			activa = false
		end
		local char = jugador.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = C.HOMBRO * mezcla
		end
		local cam = workspace.CurrentCamera
		if cam and cam.CameraType == Enum.CameraType.Custom then
			cam.FieldOfView = FOV_NORMAL + (C.FOV - FOV_NORMAL) * mezcla
		end
	end)
end

return Camara
