--!strict
--[[
	Entrada del servidor: lobby con helipuertos y selva procedural nueva en cada partida.

	APAGADO POR DEFECTO (AGENTS.md): escribe terreno y quita el Baseplate en tiempo de juego.
	Para activarlo: Workspace > Attributes > atributo booleano `SelvaProcedural` = true.
]]

local Players = game:GetService("Players")

if workspace:GetAttribute("SelvaProcedural") ~= true then
	print("[Selva] desactivada. Pon el atributo SelvaProcedural = true en Workspace para jugar.")
	return
end

local Lobby = require(script.Lobby.Lobby)
local Partida = require(script.Partida)
local Portales = require(script.Lobby.Portales)
require(script.Remotes)
require(script.Linterna).iniciar()

-- restos de la plantilla del place: solo en juego, no se guarda en el place
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
for _, s in workspace:GetDescendants() do
	if s:IsA("SpawnLocation") then
		s.Enabled = false
	end
end

local function alEntrar(pl: Player)
	pl:SetAttribute("Zona", "Lobby")
	pl:SetAttribute("Portal", 0)
	pl.CameraMinZoomDistance = 0.5
	pl.CameraMaxZoomDistance = 40
end

local lobby = Lobby.construir()
Players.PlayerAdded:Connect(alEntrar)
for _, pl in Players:GetPlayers() do
	-- quien entró antes de que existiera el lobby reaparece en él
	alEntrar(pl)
	pl:LoadCharacter()
end

task.spawn(Partida.preparar)
Portales.iniciar(lobby.portales, Partida.puedeIniciar, Partida.iniciar)
