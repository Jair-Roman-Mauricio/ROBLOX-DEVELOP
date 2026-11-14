--!strict
--[[
	Ciclo de una partida, de momento solo de exploración del mapa:
	  preparar → (selva lista) → iniciar con un equipo → (todos fuera) → preparar otra selva

	Una sola selva por servidor. Mientras hay una expedición en curso los helipuertos esperan.
	En producción cada vuelo debería ir a un servidor reservado (baúl: 41 Multiplayer Services/
	Parties and Group Teleports, Reserved and Private Servers in Practice).

	Sin monstruos, objetos, día/noche ni escape todavía. Al morir o reiniciar el personaje,
	el jugador reaparece en el lobby (el único SpawnLocation activo).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Generador = require(script.Parent.Mundo.Generador)
local Terreno = require(script.Parent.Mundo.Terreno)

local P = Config.Partida
local estado = Remotes.Estado

local Partida = {}

local mundo: Generador.Mundo? = nil
local jugadores: { Player } = {}
local generando = false

local function fijarEstado(e: string)
	estado:SetAttribute("Estado", e)
end

local function quitar(pl: Player)
	local i = table.find(jugadores, pl)
	if i then
		table.remove(jugadores, i)
	end
	if pl.Parent then
		pl:SetAttribute("Zona", "Lobby")
		pl.CameraMaxZoomDistance = 40
	end
end

function Partida.puedeIniciar(): (boolean, string)
	local e = estado:GetAttribute("Estado")
	if e == "lista" then
		return true, ""
	elseif e == "en_curso" then
		return false, "Expedición en curso"
	elseif e == "error" then
		return false, "Error al generar la selva"
	end
	return false,
		("Preparando la selva %d%%"):format(math.floor(((estado:GetAttribute("Progreso") or 0) :: number) * 100))
end

function Partida.preparar()
	if generando then
		return
	end
	generando = true
	fijarEstado("preparando")
	estado:SetAttribute("Progreso", 0)
	if mundo then
		mundo.carpeta:Destroy()
		mundo = nil
	end
	-- si una generación falla se reintenta con otra semilla, para no dejar el lobby bloqueado
	local ok, resultado = false, nil :: any
	local inicio = os.clock()
	for intento = 1, 3 do
		local resto = workspace:FindFirstChild("Selva")
		if resto then
			resto:Destroy()
		end
		Terreno.limpiar()
		local semilla = Random.new():NextInteger(1, 2 ^ 30)
		ok, resultado = pcall(Generador.generar, semilla, workspace, function(f: number, etapa: string)
			estado:SetAttribute("Progreso", f)
			estado:SetAttribute("Etapa", etapa)
		end)
		if ok then
			break
		end
		warn(("[Selva] error generando el mapa (intento %d/3): %s"):format(intento, tostring(resultado)))
		task.wait(1)
	end
	generando = false
	if not ok then
		fijarEstado("error")
		return
	end
	mundo = resultado
	estado:SetAttribute("Semilla", resultado.semilla)
	print(("[Selva] generada en %.1f s"):format(os.clock() - inicio))
	fijarEstado("lista")
end

local function terminar()
	jugadores = {}
	task.spawn(Partida.preparar)
end

function Partida.iniciar(grupo: { Player }, helipuerto: Model?)
	local m = mundo
	if estado:GetAttribute("Estado") ~= "lista" or not m then
		for _, pl in grupo do
			quitar(pl)
		end
		return
	end
	fijarEstado("en_curso")
	jugadores = table.clone(grupo)

	-- embarque: cada jugador entra en la cabina y queda anclado mientras su cliente
	-- reproduce la cinemática del despegue
	local heli = helipuerto and helipuerto:FindFirstChild("Helicoptero")
	local interior = heli and heli:FindFirstChild("Interior")
	for _, pl in jugadores do
		local char = pl.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if char and raiz and raiz:IsA("BasePart") then
			raiz.Anchored = true
			if interior and interior:IsA("BasePart") then
				char:PivotTo(interior.CFrame)
			end
		end
		Remotes.Cinematica:FireClient(pl, helipuerto)
	end
	task.wait(Config.Lobby.CINEMATICA)

	for i, pl in table.clone(jugadores) do
		local char = pl.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if not pl.Parent or not char or not hum or hum.Health <= 0 then
			quitar(pl)
			continue
		end
		local spawn = m.spawns[(i - 1) % #m.spawns + 1]
		pcall(function()
			pl:RequestStreamAroundAsync(spawn, 3)
		end)
		char:PivotTo(CFrame.lookAt(spawn, spawn + m.mirarInicio))
		if raiz and raiz:IsA("BasePart") then
			raiz.Anchored = false
		end
		pl:SetAttribute("Zona", "Partida")
		pl.CameraMaxZoomDistance = P.ZOOM_MAXIMO
		hum.Died:Once(function()
			if table.find(jugadores, pl) then
				quitar(pl)
				for _, otro in jugadores do
					Remotes.Aviso:FireClient(otro, ("%s ha caído."):format(pl.DisplayName), 4)
				end
			end
		end)
		Remotes.Aviso:FireClient(pl, "Explora la selva. Busca los pueblos, el helicóptero y la salida.", 6)
	end
	if #jugadores == 0 then
		terminar()
	end
end

-- Vigila caídas fuera del mapa y cierra la expedición cuando ya no queda nadie.
task.spawn(function()
	while true do
		task.wait(0.5)
		if estado:GetAttribute("Estado") == "en_curso" then
			for _, pl in table.clone(jugadores) do
				local char = pl.Parent and pl.Character
				local raiz = char and char:FindFirstChild("HumanoidRootPart")
				if not char or not raiz or not raiz:IsA("BasePart") then
					if not pl.Parent then
						quitar(pl)
					end
					continue
				end
				if raiz.Position.Y < -60 then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.Health = 0
					end
				end
			end
			if #jugadores == 0 then
				terminar()
			end
		end
	end
end)

Players.PlayerRemoving:Connect(quitar)

return Partida
