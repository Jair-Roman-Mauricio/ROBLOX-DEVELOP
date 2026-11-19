--!strict
--[[
	Botón para saltar esperas, abajo a la derecha (dentro del área segura). Hay que mantenerlo
	pulsado un segundo:
	  "Despegar ya"        en el helipuerto, durante la cuenta atrás.
	  "Saltar cinemática"  en el despegue del lobby y en la charla del piloto.
	En grupo muestra los votos (2/4) y espera a que voten todos. El servidor decide
	(server/Saltos.luau): este módulo solo pinta los atributos Salto* y envía el voto.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CREMA = Color3.fromRGB(244, 232, 206)
local AMBAR = Color3.fromRGB(255, 176, 70)
local FONDO = Color3.fromRGB(18, 20, 18)

local TEXTOS = {
	despegue = "Mantén para despegar ya",
	cinematica = "Mantén para saltar la cinemática",
}
local MANTENER = 1 -- segundos manteniendo pulsado para votar

local Saltos = {}

function Saltos.iniciar()
	local jugador = Players.LocalPlayer
	local remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Saltar") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Saltos"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000 -- por encima de las franjas y fundidos de las cinemáticas

	local boton = Instance.new("TextButton")
	boton.Name = "Saltar"
	boton.AnchorPoint = Vector2.new(1, 1)
	boton.Position = UDim2.new(1, -24, 1, -24)
	boton.Size = UDim2.fromOffset(0, 44) -- 44 px de alto: cómodo de tocar en móvil
	boton.AutomaticSize = Enum.AutomaticSize.X
	boton.BackgroundColor3 = FONDO
	boton.BackgroundTransparency = 0.2
	boton.Font = Enum.Font.GothamBold
	boton.TextSize = 18
	boton.TextColor3 = CREMA
	boton.Visible = false
	boton.Parent = gui

	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 10)
	esquina.Parent = boton
	local borde = Instance.new("UIStroke")
	borde.Color = AMBAR
	borde.Thickness = 1.5
	borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	borde.Parent = boton
	local relleno = Instance.new("UIPadding")
	relleno.PaddingLeft = UDim.new(0, 18)
	relleno.PaddingRight = UDim.new(0, 18)
	relleno.Parent = boton

	gui.Parent = jugador:WaitForChild("PlayerGui")

	local function actualizar()
		local tipo = jugador:GetAttribute("Salto")
		local base = if typeof(tipo) == "string" then (TEXTOS :: any)[tipo] :: string? else nil
		if not base then
			boton.Visible = false
			return
		end
		local votos = (jugador:GetAttribute("SaltoVotos") or 0) :: number
		local total = (jugador:GetAttribute("SaltoTotal") or 0) :: number
		local votado = jugador:GetAttribute("SaltoVotado") == true
		if votado and total > 1 then
			boton.Text = ("Esperando al equipo  %d/%d"):format(votos, total)
		elseif total > 1 then
			boton.Text = ("%s  %d/%d"):format(base, votos, total)
		else
			boton.Text = base
		end
		boton.AutoButtonColor = not votado
		boton.TextTransparency = if votado then 0.35 else 0
		borde.Transparency = if votado then 0.6 else 0
		boton.Visible = true
	end

	for _, atributo in { "Salto", "SaltoVotos", "SaltoTotal", "SaltoVotado" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(actualizar)
	end
	actualizar()

	-- Mantener pulsado MANTENER segundos para votar: evita saltos sin querer, por ejemplo con
	-- un clic que iba al botón anterior. La barra se llena mientras lo mantienes.
	local barra = Instance.new("Frame")
	barra.Name = "Progreso"
	barra.BackgroundColor3 = AMBAR
	barra.BackgroundTransparency = 0.7
	barra.BorderSizePixel = 0
	barra.Position = UDim2.fromOffset(-18, 0) -- ocupa también el margen interior del botón
	barra.Size = UDim2.fromScale(0, 1)
	barra.ZIndex = 0
	barra.Parent = boton
	local esquinaBarra = Instance.new("UICorner")
	esquinaBarra.CornerRadius = UDim.new(0, 10)
	esquinaBarra.Parent = barra

	local inicio: number? = nil
	local tipoPulsado: string? = nil

	local function soltar()
		inicio = nil
		tipoPulsado = nil
		barra.Size = UDim2.fromScale(0, 1)
	end

	boton.InputBegan:Connect(function(entrada: InputObject)
		local t = entrada.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		local tipo = jugador:GetAttribute("Salto")
		if typeof(tipo) == "string" and tipo ~= "" and jugador:GetAttribute("SaltoVotado") ~= true then
			inicio = os.clock()
			tipoPulsado = tipo
		end
	end)
	boton.InputEnded:Connect(function(entrada: InputObject)
		local t = entrada.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			soltar()
		end
	end)
	boton.MouseLeave:Connect(soltar)

	RunService.RenderStepped:Connect(function()
		local desde = inicio
		if not desde then
			return
		end
		-- si cambió la votación mientras lo mantenías (otra pantalla), no cuenta
		if jugador:GetAttribute("Salto") ~= tipoPulsado or not boton.Visible then
			soltar()
			return
		end
		local f = math.clamp((os.clock() - desde) / MANTENER, 0, 1)
		barra.Size = UDim2.new(f, 36 * f, 1, 0)
		if f >= 1 then
			remoto:FireServer(tipoPulsado)
			soltar()
		end
	end)

	jugador:GetAttributeChangedSignal("Salto"):Connect(soltar)
end

return Saltos
