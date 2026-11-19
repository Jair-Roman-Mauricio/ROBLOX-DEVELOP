--!strict
--[[
	Ciclo de día y noche de la selva (servidor).

	Durante una expedición avanza la hora (Workspace.HoraSelva, de 0 a 24) y publica si es de
	día (Workspace.SelvaDia). Con eso:
	  · cada cliente pinta la luz y mueve el sol y la luna (client/Ambiente.luau);
	  · de día la selva se calma: la serpiente no pasa y no hay sustos (Serpiente, Acecho).

	Regla confirmada (CONTEXT.md): al descubrir un pueblo el tiempo pasa al día sin anomalías.
	Aquí basta con que un jugador entre en un pueblo por primera vez; cómo tratar a quien está
	lejos o desconectado sigue abierto, igual que la duración del día y la noche: los valores de
	Config.Ciclo son una PROPUESTA.
	Baúl: Lighting Mood and Time of Day (la hora la publica el servidor y cada cliente pinta).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local CI = Config.Ciclo

local Ciclo = {}

local hora = CI.HORA_INICIO
local descubiertos: { [Instance]: boolean } = {}
local siguienteRevision = 0

function Ciclo.esDeDia(h: number): boolean
	return h >= CI.AMANECER and h < CI.ANOCHECER
end

local function publicar()
	workspace:SetAttribute("HoraSelva", hora)
	local dia = Ciclo.esDeDia(hora)
	if workspace:GetAttribute("SelvaDia") ~= dia then
		workspace:SetAttribute("SelvaDia", dia)
	end
end

local function enSelva(): { BasePart }
	local raices = {}
	for _, pl in Players:GetPlayers() do
		local char = pl.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if pl:GetAttribute("Zona") == "Partida" and raiz and raiz:IsA("BasePart") then
			table.insert(raices, raiz)
		end
	end
	return raices
end

local function avisar(texto: string)
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Zona") == "Partida" then
			Remotes.Aviso:FireClient(pl, texto, 6)
		end
	end
end

-- Si alguien acaba de entrar en un pueblo que nadie había descubierto, amanece.
local function revisarPueblos()
	local selva = workspace:FindFirstChild("Selva")
	local zonas = selva and selva:FindFirstChild("Zonas")
	if not zonas then
		return
	end
	local raices = enSelva()
	for _, zona in zonas:GetChildren() do
		if zona:IsA("Model") and zona:GetAttribute("Tipo") == "pueblo" and not descubiertos[zona] then
			local centro = zona:GetPivot().Position
			local radio = (zona:GetAttribute("Radio") or 60) :: number
			for _, raiz in raices do
				local d = Vector2.new(raiz.Position.X - centro.X, raiz.Position.Z - centro.Z).Magnitude
				if d < radio then
					descubiertos[zona] = true
					if not Ciclo.esDeDia(hora) then
						hora = CI.AMANECER
						avisar("Encontrasteis un pueblo. Amanece y la selva se calma.")
					else
						avisar("Encontrasteis un pueblo.")
					end
					break
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	if not CI.ACTIVO then
		return
	end
	if Remotes.Estado:GetAttribute("Estado") ~= "en_curso" then
		-- entre expediciones vuelve a la hora de llegada
		if hora ~= CI.HORA_INICIO or next(descubiertos) then
			hora = CI.HORA_INICIO
			table.clear(descubiertos)
			publicar()
		end
		return
	end
	hora = (hora + dt * 24 / CI.DURACION) % 24
	local ahora = os.clock()
	if ahora >= siguienteRevision then
		-- dos veces por segundo basta: los clientes interpolan la hora entre medias
		siguienteRevision = ahora + 0.5
		revisarPueblos()
		publicar()
	end
end)

if CI.ACTIVO then
	publicar()
end

return Ciclo
