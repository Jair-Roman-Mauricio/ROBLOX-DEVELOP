--!strict
-- Entrada temprana y ligera: no carga todo Workspace ni usa RequestQueueSize.
-- PreloadAsync prepara recursos descargables; Roblox no expone el fin de compilación
-- de shaders. Se dejan unos frames de renderizado detrás de la pantalla antes de entrar.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local jugador = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CargaInicial"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
local fondo = Instance.new("Frame")
fondo.Size = UDim2.fromScale(1, 1)
fondo.BackgroundColor3 = Color3.fromRGB(8, 15, 21)
fondo.BorderSizePixel = 0
fondo.Parent = gui
local gradiente = Instance.new("UIGradient")
gradiente.Color = ColorSequence.new(Color3.fromRGB(19, 34, 43), Color3.fromRGB(5, 10, 15))
gradiente.Rotation = 35
gradiente.Parent = fondo

local function texto(contenido: string, y: number, alto: number, tam: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.82, alto)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = tam
	label.TextColor3 = color
	label.Text = contenido
	label.TextWrapped = true
	label.Parent = fondo
	return label
end
local ambar = Color3.fromRGB(241, 175, 61)
texto("EXPEDICIONES / AMAZONAS", 0.28, 0.05, 16, ambar)
local titulo = texto("LA SELVA ESPERA", 0.36, 0.12, 42, Color3.fromRGB(224, 233, 234))
titulo.Font = Enum.Font.GothamBold
titulo.TextScaled = true
local limite = Instance.new("UITextSizeConstraint")
limite.MaxTextSize = 52
limite.Parent = titulo
texto("BASE MARÍTIMA 07  /  PREPARACIÓN DE EMBARQUE", 0.51, 0.06, 13, Color3.fromRGB(117, 143, 153))
local estado = texto("Conectando con la base…", 0.68, 0.06, 16, Color3.fromRGB(198, 215, 220))
local porcentaje = texto("0%", 0.8, 0.04, 14, ambar)
texto(
	"En la selva, tu linterna es tu única luz. Mantente cerca de tu equipo.",
	0.9,
	0.05,
	13,
	Color3.fromRGB(126, 147, 156)
)
local pista = Instance.new("Frame")
pista.AnchorPoint = Vector2.new(0.5, 0)
pista.Position = UDim2.fromScale(0.5, 0.77)
pista.Size = UDim2.fromScale(0.58, 0.005)
pista.BorderSizePixel = 0
pista.BackgroundColor3 = Color3.fromRGB(40, 59, 68)
pista.Parent = fondo
local barra = Instance.new("Frame")
barra.Size = UDim2.fromScale(0, 1)
barra.BackgroundColor3 = ambar
barra.BorderSizePixel = 0
barra.Parent = pista
gui.Parent = jugador:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local objetivo = 0
local visible = 0
local pintando = RunService.RenderStepped:Connect(function(dt)
	visible += (objetivo - visible) * (1 - math.exp(-dt * 9))
	barra.Size = UDim2.fromScale(visible, 1)
	porcentaje.Text = ("%d%%"):format(math.floor(visible * 100 + 0.5))
end)
local bloquear = "CargaInicialMovimiento"
ContextActionService:BindActionAtPriority(bloquear, function()
	return Enum.ContextActionResult.Sink
end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))

local function cargar()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	objetivo = 0.15
	if workspace:GetAttribute("SelvaProcedural") ~= true then
		return
	end
	estado.Text = "Preparando la plataforma de embarque…"
	local lobby = workspace:WaitForChild("Lobby", 60)
	assert(lobby, "El servidor no creó el lobby a tiempo")
	local inicio = os.clock()
	while lobby:GetAttribute("Listo") ~= true do
		assert(os.clock() - inicio < 60, "El lobby no terminó de construirse")
		task.wait(0.1)
	end
	lobby:WaitForChild("SpawnLobby", 15)
	-- Con streaming, solicitar solo el punto de llegada. Nunca precargar toda la selva.
	local spawn = lobby:FindFirstChild("SpawnLobby")
	if spawn and spawn:IsA("BasePart") and workspace.StreamingEnabled then
		pcall(function()
			jugador:RequestStreamAroundAsync(spawn.Position, 5)
		end)
	end
	objetivo = 0.3
	estado.Text = "Cargando helicópteros y texturas de la base…"
	local recursos: { Instance } = {}
	for _, objeto in lobby:GetDescendants() do
		if
			objeto:IsA("MeshPart")
			or objeto:IsA("SpecialMesh")
			or objeto:IsA("Decal")
			or objeto:IsA("Texture")
			or objeto:IsA("Sound")
		then
			table.insert(recursos, objeto)
		end
	end
	local terminado = false
	local activos = true
	task.spawn(function()
		local ok, err = pcall(function()
			for i, recurso in recursos do
				ContentProvider:PreloadAsync({ recurso })
				if activos then
					objetivo = 0.3 + 0.5 * i / #recursos
				end
			end
		end)
		if not ok then
			warn("[Carga] Un recurso no pudo precargarse: " .. tostring(err))
		end
		terminado = true
	end)
	inicio = os.clock()
	while not terminado and os.clock() - inicio < 20 do
		task.wait(0.05)
	end
	activos = false
	if not terminado then
		warn("[Carga] Precarga agotó 20 segundos; los recursos restantes siguen en segundo plano.")
	end
	-- La generación inicial es el otro pico de trabajo. Esperar su fin impide abrir
	-- el lobby justo mientras se replican miles de instancias de la primera selva.
	estado.Text = "Preparando la primera expedición…"
	local estadoPartida = game:GetService("ReplicatedStorage"):WaitForChild("EstadoPartida", 15)
	inicio = os.clock()
	while estadoPartida and os.clock() - inicio < 90 do
		local e = estadoPartida:GetAttribute("Estado")
		if e == "lista" or e == "en_curso" or e == "error" then
			break
		end
		local progreso = estadoPartida:GetAttribute("Progreso")
		objetivo = 0.8 + 0.05 * (if typeof(progreso) == "number" then math.clamp(progreso, 0, 1) else 0)
		task.wait(0.1)
	end
	objetivo = 0.85
	estado.Text = "Preparando iluminación y renderizado…"
	local frames = 0
	inicio = os.clock()
	while (frames < 30 or os.clock() - inicio < 1.5) and os.clock() - inicio < 5 do
		RunService.RenderStepped:Wait()
		frames += 1
		objetivo = 0.85 + 0.13 * math.min(1, (os.clock() - inicio) / 1.5)
	end
end

local ok, err = pcall(cargar)
if not ok then
	warn("[Carga] " .. tostring(err))
	estado.Text = "La base tarda más de lo esperado. Esperando al servidor…"
	-- Mantener visible la pantalla si no hay suelo jugable. El menú de Roblox sigue accesible.
	local lobby = workspace:WaitForChild("Lobby")
	while lobby:GetAttribute("Listo") ~= true do
		task.wait(0.25)
	end
end
objetivo = 1
estado.Text = "Base lista. Bienvenido a bordo."
task.wait(0.35)
ContextActionService:UnbindAction(bloquear)
jugador:SetAttribute("CargaInicialLista", true)
pintando:Disconnect()
barra.Size = UDim2.fromScale(1, 1)
porcentaje.Text = "100%"
local fade = TweenService:Create(fondo, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
for _, objeto in fondo:GetDescendants() do
	if objeto:IsA("TextLabel") then
		TweenService:Create(objeto, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	elseif objeto:IsA("Frame") then
		TweenService:Create(objeto, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end
end
fade:Play()
fade.Completed:Wait()
gui:Destroy()
