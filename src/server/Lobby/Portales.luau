--!strict
--[[
	Cola de los helipuertos del lobby. Quien se acerca a un helicóptero se une a su vuelo (máx. 4);
	al entrar el primero empieza la cuenta atrás, que se acorta con el equipo completo.
	Alejarse del helicóptero cancela la plaza. El servidor decide todo por posición: el cliente
	solo muestra los atributos `Portal` del jugador y `Jugadores`/`Cuenta` del helipuerto.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Parent.Remotes)
local Lobby = require(script.Parent.Lobby)

local L = Config.Lobby
local MAX = Config.MAX_POR_EQUIPO
local VERDE = Color3.fromRGB(90, 255, 140)
local APAGADA = Color3.fromRGB(50, 52, 54)

local Portales = {}

local function posicion(pl: Player): Vector3?
	if pl:GetAttribute("Zona") ~= "Lobby" then
		return nil
	end
	local char = pl.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not raiz or not raiz:IsA("BasePart") then
		return nil
	end
	return raiz.Position
end

local function dentro(portal: Lobby.Portal, pos: Vector3): boolean
	local d = Vector2.new(pos.X - portal.centro.X, pos.Z - portal.centro.Z).Magnitude
	return d <= L.RADIO_EMBARQUE and pos.Y > portal.centro.Y - 8 and pos.Y < portal.centro.Y + 20
end

local function expulsar(pl: Player, portal: Lobby.Portal, pos: Vector3)
	local char = pl.Character
	if not char then
		return
	end
	local dir = Vector3.new(pos.X - portal.centro.X, 0, pos.Z - portal.centro.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.zAxis
	end
	char:PivotTo(CFrame.new(portal.centro + dir.Unit * (L.RADIO_EMBARQUE + 5) + Vector3.new(0, 4, 0)))
end

local function pintar(portal: Lobby.Portal, n: number, restante: number?, listo: boolean, motivo: string)
	for k, lampara in portal.lamparas do
		local ocupada = k <= n
		lampara.Color = if ocupada then VERDE else APAGADA
		lampara.Material = if ocupada then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	local texto
	if n == 0 then
		texto = if listo then "Acércate para embarcar" else motivo
	elseif not listo then
		texto = ("%d/%d · %s"):format(n, MAX, motivo)
	elseif restante then
		texto = ("%d/%d · despega en %ds"):format(n, MAX, restante)
	else
		texto = ("%d/%d"):format(n, MAX)
	end
	portal.estado.Text = texto
	portal.modelo:SetAttribute("Jugadores", n)
	portal.modelo:SetAttribute("Cuenta", restante or -1)
end

function Portales.iniciar(
	portales: { Lobby.Portal },
	puedeIniciar: () -> (boolean, string),
	lanzar: ({ Player }, Model) -> ()
)
	local miembros: { { Player } } = {}
	local fin: { [number]: number } = {}
	for i in portales do
		miembros[i] = {}
	end

	while true do
		local listo, motivo = puedeIniciar()
		local ahora = os.clock()
		local lanzado = false
		for i, portal in portales do
			local lista = miembros[i]
			for k = #lista, 1, -1 do
				local pl = lista[k]
				local pos = if pl.Parent then posicion(pl) else nil
				if not pos or not dentro(portal, pos) then
					table.remove(lista, k)
					if pl.Parent then
						pl:SetAttribute("Portal", 0)
					end
				end
			end
			for _, pl in Players:GetPlayers() do
				if (pl:GetAttribute("Portal") or 0) == 0 then
					local pos = posicion(pl)
					if pos and dentro(portal, pos) then
						if #lista < MAX then
							table.insert(lista, pl)
							pl:SetAttribute("Portal", i)
						else
							expulsar(pl, portal, pos)
							Remotes.Aviso:FireClient(pl, "Este vuelo está lleno (máximo 4).", 3)
						end
					end
				end
			end

			if #lista == 0 then
				fin[i] = nil
			else
				local f = fin[i] or (ahora + L.CUENTA_ATRAS)
				if #lista >= MAX then
					f = math.min(f, ahora + L.CUENTA_EQUIPO_LLENO)
				end
				fin[i] = f
				if ahora >= f and listo and not lanzado then
					local grupo = table.clone(lista)
					table.clear(lista)
					fin[i] = nil
					for _, pl in grupo do
						pl:SetAttribute("Portal", 0)
						pl:SetAttribute("Zona", "Viajando")
					end
					lanzado = true
					listo, motivo = false, "Expedición en curso"
					task.spawn(lanzar, grupo, portal.modelo)
				end
			end
			local restante = if fin[i] then math.max(0, math.ceil(fin[i] - ahora)) else nil
			pintar(portal, #lista, restante, listo, motivo)
		end
		task.wait(0.2)
	end
end

return Portales
