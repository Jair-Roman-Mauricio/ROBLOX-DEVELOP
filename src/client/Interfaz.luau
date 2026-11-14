--!strict
--[[
	Interfaz mínima: fundido a negro al despegar, avisos del servidor, panel del vuelo en el
	que estás y progreso de la selva mientras se genera.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local CREMA = Color3.fromRGB(244, 232, 206)
local AMBAR = Color3.fromRGB(255, 176, 70)
local FONDO = Color3.fromRGB(18, 20, 18)

local Interfaz = {}

local function etiqueta(padre: Instance, fuente: Enum.Font, tam: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = fuente
	l.TextSize = tam
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = ""
	l.Parent = padre
	return l
end

local function tarjeta(padre: Instance, nombre: string): Frame
	local f = Instance.new("Frame")
	f.Name = nombre
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.BackgroundColor3 = FONDO
	f.BackgroundTransparency = 0.25
	f.Visible = false
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 10)
	esquina.Parent = f
	local borde = Instance.new("UIStroke")
	borde.Color = AMBAR
	borde.Transparency = 0.6
	borde.Parent = f
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop = UDim.new(0, 10)
	relleno.PaddingBottom = UDim.new(0, 10)
	relleno.PaddingLeft = UDim.new(0, 18)
	relleno.PaddingRight = UDim.new(0, 18)
	relleno.Parent = f
	local lista = Instance.new("UIListLayout")
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.Padding = UDim.new(0, 4)
	lista.Parent = f
	f.Parent = padre
	return f
end

function Interfaz.iniciar()
	local jugador = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local estado = ReplicatedStorage:WaitForChild("EstadoPartida")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Selva"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = jugador:WaitForChild("PlayerGui")

	-- fundido
	local negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.ZIndex = 20
	negro.Parent = gui
	local textoNegro = etiqueta(negro, Enum.Font.Merriweather, 30, CREMA)
	textoNegro.Size = UDim2.fromScale(0.8, 0.2)
	textoNegro.Position = UDim2.fromScale(0.1, 0.4)
	textoNegro.TextTransparency = 1
	textoNegro.ZIndex = 21

	-- avisos
	local aviso = tarjeta(gui, "Aviso")
	aviso.Position = UDim2.new(0.5, 0, 0, 72)
	local textoAviso = etiqueta(aviso, Enum.Font.GothamMedium, 18, CREMA)
	textoAviso.AutomaticSize = Enum.AutomaticSize.XY
	textoAviso.Size = UDim2.fromOffset(0, 0)
	local avisoId = 0

	-- panel del vuelo
	local panel = tarjeta(gui, "Vuelo")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -28)
	local tituloVuelo = etiqueta(panel, Enum.Font.Merriweather, 22, CREMA)
	tituloVuelo.AutomaticSize = Enum.AutomaticSize.XY
	local detalleVuelo = etiqueta(panel, Enum.Font.GothamMedium, 15, AMBAR)
	detalleVuelo.AutomaticSize = Enum.AutomaticSize.XY

	-- progreso de generación
	local progreso = etiqueta(gui, Enum.Font.GothamMedium, 14, CREMA)
	progreso.AnchorPoint = Vector2.new(1, 0)
	progreso.Position = UDim2.new(1, -20, 0, 16)
	progreso.Size = UDim2.fromOffset(320, 20)
	progreso.TextXAlignment = Enum.TextXAlignment.Right
	progreso.TextTransparency = 0.2

	local function mostrarAviso(texto: string, segundos: number?)
		avisoId += 1
		local id = avisoId
		textoAviso.Text = texto
		aviso.Visible = true
		task.delay(segundos or 4, function()
			if id == avisoId then
				aviso.Visible = false
			end
		end)
	end

	local function transicion(texto: string)
		textoNegro.Text = texto
		local entrar = TweenInfo.new(0.6)
		TweenService:Create(negro, entrar, { BackgroundTransparency = 0 }):Play()
		TweenService:Create(textoNegro, entrar, { TextTransparency = 0 }):Play()
		task.delay(2.6, function()
			local salir = TweenInfo.new(1.4)
			TweenService:Create(negro, salir, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(textoNegro, salir, { TextTransparency = 1 }):Play()
		end)
	end

	local function refrescarPanel()
		local indice = (jugador:GetAttribute("Portal") or 0) :: number
		if indice == 0 or jugador:GetAttribute("Zona") ~= "Lobby" then
			panel.Visible = false
			return
		end
		local lobby = workspace:FindFirstChild("Lobby")
		local portal = lobby and lobby:FindFirstChild(("Vuelo%d"):format(indice))
		local n = if portal then (portal:GetAttribute("Jugadores") or 0) :: number else 0
		local cuenta = if portal then (portal:GetAttribute("Cuenta") or -1) :: number else -1
		tituloVuelo.Text = ("Vuelo %d · %d/%d a bordo"):format(indice, n, Config.MAX_POR_EQUIPO)
		detalleVuelo.Text = if cuenta >= 0
			then ("Despega en %ds · aléjate del helicóptero para cancelar"):format(cuenta)
			else "Esperando a que la selva esté lista"
		panel.Visible = true
	end

	local function refrescarProgreso()
		local e = estado:GetAttribute("Estado")
		if e == "preparando" and jugador:GetAttribute("Zona") == "Lobby" then
			progreso.Text = ("%s… %d%%"):format(
				(estado:GetAttribute("Etapa") or "Preparando la selva") :: string,
				math.floor(((estado:GetAttribute("Progreso") or 0) :: number) * 100)
			)
		else
			progreso.Text = ""
		end
	end

	(remotes:WaitForChild("Aviso") :: RemoteEvent).OnClientEvent:Connect(mostrarAviso);
	(remotes:WaitForChild("Transicion") :: RemoteEvent).OnClientEvent:Connect(transicion)
	estado.AttributeChanged:Connect(refrescarProgreso)
	jugador.AttributeChanged:Connect(function()
		refrescarPanel()
		refrescarProgreso()
	end)
	task.spawn(function()
		while true do
			refrescarPanel()
			task.wait(0.25)
		end
	end)
	refrescarProgreso()
end

return Interfaz
