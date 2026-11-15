--!strict
--[[
	Votaciones para saltar esperas:
	  despegue   → la cuenta atrás del helipuerto ("Despegar ya").
	  cinematica → el despegue del lobby y la charla del piloto ("Saltar cinemática").
	Solo se salta cuando votan todos los del grupo; si vas solo, al instante.

	El cliente solo pide (Remotes.Saltar con el tipo); el servidor decide si hay votación
	abierta para ese jugador, limita la frecuencia y cuenta los votos (baúl: Server Authority
	and Validation, Rate Limiting and Abuse Prevention).

	Atributos de cada jugador que lee la interfaz: Salto ("" | "despegue" | "cinematica"),
	SaltoVotos, SaltoTotal y SaltoVotado.
]]

local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)

export type Votacion = {
	tipo: string,
	miembros: { Player },
	votos: { [Player]: boolean },
	hecha: boolean,
}

local Saltos = {}

local dePlayer: { [Player]: Votacion } = {}
local ultimo: { [Player]: number } = {}
local INTERVALO = 0.3 -- segundos mínimos entre peticiones de un jugador

local function limpiarAtributos(pl: Player)
	if pl.Parent then
		pl:SetAttribute("Salto", "")
		pl:SetAttribute("SaltoVotos", 0)
		pl:SetAttribute("SaltoTotal", 0)
		pl:SetAttribute("SaltoVotado", false)
	end
end

local function pintar(v: Votacion)
	local total, n = 0, 0
	for _, pl in v.miembros do
		if pl.Parent then
			total += 1
			if v.votos[pl] then
				n += 1
			end
		end
	end
	if total > 0 and n >= total then
		v.hecha = true
	elseif v.tipo == "despegue" then
		-- en el helipuerto entra y sale gente: la votación se recalcula
		v.hecha = false
	end
	for _, pl in v.miembros do
		if pl.Parent then
			pl:SetAttribute("Salto", v.tipo)
			pl:SetAttribute("SaltoVotos", n)
			pl:SetAttribute("SaltoTotal", total)
			pl:SetAttribute("SaltoVotado", v.votos[pl] == true)
		end
	end
end

function Saltos.abrir(tipo: string, miembros: { Player }): Votacion
	local v: Votacion = { tipo = tipo, miembros = {}, votos = {}, hecha = false }
	Saltos.sincronizar(v, miembros)
	return v
end

-- Ajusta los miembros (gente que entra o sale del helipuerto) conservando los votos.
function Saltos.sincronizar(v: Votacion, miembros: { Player })
	for _, pl in v.miembros do
		if not table.find(miembros, pl) then
			v.votos[pl] = nil
			if dePlayer[pl] == v then
				dePlayer[pl] = nil
				limpiarAtributos(pl)
			end
		end
	end
	v.miembros = table.clone(miembros)
	for _, pl in v.miembros do
		dePlayer[pl] = v
	end
	pintar(v)
end

function Saltos.cerrar(v: Votacion)
	for _, pl in v.miembros do
		if dePlayer[pl] == v then
			dePlayer[pl] = nil
			limpiarAtributos(pl)
		end
	end
	table.clear(v.miembros)
end

-- Espera hasta `segundos` o hasta que el grupo vote saltar. Devuelve true si se saltó.
function Saltos.esperar(v: Votacion, segundos: number): boolean
	local fin = os.clock() + segundos
	while not v.hecha and os.clock() < fin do
		task.wait(0.1)
	end
	return v.hecha
end

Remotes.Saltar.OnServerEvent:Connect(function(pl: Player, tipo: unknown)
	if typeof(tipo) ~= "string" then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[pl] or -math.huge) < INTERVALO then
		return
	end
	ultimo[pl] = ahora
	local v = dePlayer[pl]
	if not v or v.tipo ~= tipo or v.votos[pl] then
		return
	end
	v.votos[pl] = true
	pintar(v)
end)

Players.PlayerRemoving:Connect(function(pl: Player)
	ultimo[pl] = nil
	local v = dePlayer[pl]
	dePlayer[pl] = nil
	if v then
		-- quien se va deja de contar para el total
		pintar(v)
	end
end)

return Saltos
