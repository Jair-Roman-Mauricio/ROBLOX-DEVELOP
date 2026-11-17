--!strict
--[[
	Linterna (servidor). El cliente pide encender o apagar; el servidor comprueba que el jugador
	está vivo, en la selva y que tiene la linterna en su botín, y publica el estado en el
	atributo `Linterna` del jugador. La luz que ven los demás cuelga del personaje: un foco en
	el pecho que apunta hacia donde mira el cuerpo. Cada cliente dibuja su propia linterna
	siguiendo la cámara (client/Linterna) y oculta este foco para no duplicarla.

	Baúl: Light Sources and Shadows (SpotLight, alcance máximo 120), Genre Playbook - Horror and
	Story ("Never make darkness unplayable"), Remote validation (nunca fiarse del cliente).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local L = Config.Linterna
local NOMBRE_FOCO = "FocoLinterna"

local Linterna = {}

local ultima: { [Player]: number } = {}

local function tiene(pl: Player): boolean
	local botin = pl:FindFirstChild("Botin")
	return botin ~= nil and botin:FindFirstChild(L.OBJETO) ~= nil
end

local function puede(pl: Player): boolean
	local char = pl.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and pl:GetAttribute("Zona") == "Partida" and tiene(pl)
end

local function quitarFoco(pl: Player)
	local char = pl.Character
	local foco = char and char:FindFirstChild(NOMBRE_FOCO)
	if foco then
		foco:Destroy()
	end
end

local function ponerFoco(pl: Player)
	local char = pl.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	if not char or not torso or not torso:IsA("BasePart") or char:FindFirstChild(NOMBRE_FOCO) then
		return
	end
	local foco = Instance.new("Part")
	foco.Name = NOMBRE_FOCO
	foco.Size = Vector3.new(0.3, 0.3, 0.3)
	foco.Transparency = 1
	foco.CanCollide = false
	foco.CanTouch = false
	foco.CanQuery = false
	foco.Massless = true
	foco.CFrame = torso.CFrame * CFrame.new(0, 0.4, -0.7)
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = torso
	soldadura.Part1 = foco
	soldadura.Parent = foco
	local luz = Instance.new("SpotLight")
	luz.Face = Enum.NormalId.Front
	luz.Range = L.ALCANCE
	luz.Angle = L.ANGULO
	luz.Brightness = L.BRILLO
	luz.Color = L.COLOR
	luz.Shadows = true
	luz.Parent = foco
	foco.Parent = char
end

local function fijar(pl: Player, encendida: boolean)
	pl:SetAttribute("Linterna", encendida)
	if encendida then
		ponerFoco(pl)
	else
		quitarFoco(pl)
	end
end

function Linterna.iniciar()
	Remotes.Linterna.OnServerEvent:Connect(function(pl: Player, pedido: unknown)
		if typeof(pedido) ~= "boolean" then
			return
		end
		local ahora = os.clock()
		if ahora - (ultima[pl] or 0) < L.ESPERA then
			return
		end
		ultima[pl] = ahora
		fijar(pl, pedido and puede(pl))
	end)

	local function alEntrar(pl: Player)
		pl:SetAttribute("Linterna", false)
		pl:SetAttribute("TieneLinterna", false)
		-- al salir de la selva o reaparecer, apagada
		pl:GetAttributeChangedSignal("Zona"):Connect(function()
			if pl:GetAttribute("Zona") ~= "Partida" then
				fijar(pl, false)
			end
			local disponible = pl:GetAttribute("Zona") == "Partida" and tiene(pl)
			pl:SetAttribute("TieneLinterna", disponible)
			if disponible then
				fijar(pl, puede(pl))
				task.delay(7, function()
					if pl.Parent and pl:GetAttribute("TieneLinterna") == true then
						Remotes.Aviso:FireClient(pl, "Linterna: F en teclado, Y en mando o el botón táctil.", 5)
					end
				end)
			end
		end)
		pl.CharacterAdded:Connect(function()
			fijar(pl, false)
		end)
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, pl in Players:GetPlayers() do
		alEntrar(pl)
	end
	Players.PlayerRemoving:Connect(function(pl)
		ultima[pl] = nil
	end)
end

return Linterna
