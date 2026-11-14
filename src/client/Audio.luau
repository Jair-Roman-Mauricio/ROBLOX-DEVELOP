--!strict
--[[
	Música y ambiente del cliente (baúl: Music and Adaptive Audio, Spatial Audio and Mixing).
	  · Música en dos pistas con crossfade (Sine) para no cortar en seco.
	  · Capas de ambiente en bucle que se funden al cambiar de zona.
	  · Golpes musicales (stingers) y efectos sueltos.
	  · En la selva: lista de temas al azar con silencios entre ellos y pájaros lejanos.
	Los ids viven en Config.Audio. Las cinemáticas e Intro piden cambios concretos; la zona
	del jugador fija el ambiente base.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

type Pista = { id: number, volumen: number }

local A = Config.Audio

local Audio = {}

local grupoMusica: SoundGroup
local grupoAmbiente: SoundGroup
local grupoEfectos: SoundGroup
local decks: { Sound } = {}
local activo = 1
local capas: { [string]: Sound } = {}
local listaId = 0 -- invalida la lista de la selva cuando cambia la música

local function grupo(nombre: string, volumen: number): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = nombre
	g.Volume = volumen
	g.Parent = SoundService
	return g
end

local function sonido(nombre: string, def: Pista, padre: Instance, g: SoundGroup, bucle: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = nombre
	s.SoundId = ("rbxassetid://%d"):format(def.id)
	s.Volume = 0
	s.Looped = bucle
	s.SoundGroup = g
	s.Parent = padre
	return s
end

local function fundir(s: Sound, volumen: number, segundos: number, alTerminar: (() -> ())?)
	if segundos <= 0 then
		s.Volume = volumen
		if alTerminar then
			alTerminar()
		end
		return
	end
	local t = TweenService:Create(s, TweenInfo.new(segundos, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Volume = volumen,
	})
	if alTerminar then
		t.Completed:Once(alTerminar)
	end
	t:Play()
end

-- Cambia la música con crossfade. `nil` la apaga.
function Audio.pista(def: Pista?, segundos: number?, bucle: boolean?)
	local fade = segundos or 2.5
	local saliente = decks[activo]
	fundir(saliente, 0, fade, function()
		if saliente.Volume <= 0.001 then
			saliente:Stop()
		end
	end)
	if not def then
		return
	end
	activo = 3 - activo
	local entrante = decks[activo]
	entrante:Stop()
	entrante.SoundId = ("rbxassetid://%d"):format(def.id)
	entrante.Looped = bucle ~= false
	entrante.TimePosition = 0
	entrante.Volume = 0
	entrante:Play()
	fundir(entrante, def.volumen, fade)
end

function Audio.musica(nombre: string?, segundos: number?)
	listaId += 1
	Audio.pista(if nombre then (A.Musica :: any)[nombre] else nil, segundos)
end

-- Deja sonando exactamente estas capas de ambiente.
function Audio.capas(nombres: { string }, segundos: number?)
	local fade = segundos or 2.5
	local quiero: { [string]: boolean } = {}
	for _, n in nombres do
		quiero[n] = true
	end
	for n, s in capas do
		if not quiero[n] then
			fundir(s, 0, fade, function()
				if s.Volume <= 0.001 then
					s:Stop()
				end
			end)
		end
	end
	for n in quiero do
		local def = (A.Ambiente :: any)[n] :: Pista?
		if def then
			local s = capas[n]
			if not s then
				s = sonido(n, def, SoundService, grupoAmbiente, true)
				if n == "Rotor" then
					-- desde dentro del fuselaje: sin agudos
					local eq = Instance.new("EqualizerSoundEffect")
					eq.LowGain = 3
					eq.MidGain = -6
					eq.HighGain = -22
					eq.Parent = s
				end
				capas[n] = s
			end
			if not s.IsPlaying then
				s:Play()
			end
			fundir(s, def.volumen, fade)
		end
	end
end

function Audio.efecto(nombre: string, volumen: number?, tono: number?): Sound?
	local def = (A.Efectos :: any)[nombre] :: Pista?
	if not def then
		return nil
	end
	local s = sonido(nombre, def, SoundService, grupoEfectos, false)
	s.Volume = def.volumen * (volumen or 1)
	s.PlaybackSpeed = tono or 1
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	return s
end

-- Baja la música (por ejemplo bajo los diálogos) sin pararla.
function Audio.atenuar(factor: number, segundos: number?)
	TweenService:Create(grupoMusica, TweenInfo.new(segundos or 0.6), { Volume = 0.8 * factor }):Play()
end

-- Selva: temas al azar sin repetir el anterior, con silencios entre ellos.
local function listaSelva()
	listaId += 1
	local id = listaId
	task.spawn(function()
		local anterior = 0
		task.wait(8)
		while id == listaId do
			local i = math.random(1, #A.Selva)
			if i == anterior and #A.Selva > 1 then
				i = i % #A.Selva + 1
			end
			anterior = i
			Audio.pista(A.Selva[i], 6, false)
			local s = decks[activo]
			local largo = if s.TimeLength > 0 then s.TimeLength else 120
			local fin = os.clock() + largo
			while id == listaId and os.clock() < fin - 6 do
				task.wait(0.5)
				if s.TimeLength > 0 then
					fin = os.clock() + (s.TimeLength - s.TimePosition)
				end
			end
			if id ~= listaId then
				break
			end
			Audio.pista(nil, 6)
			task.wait(math.random(A.SILENCIO_SELVA[1], A.SILENCIO_SELVA[2]))
		end
	end)
end

-- Pájaros lejanos en la selva, posicionados alrededor de la cámara (sonido 3D).
local function pajaros()
	local id = listaId
	task.spawn(function()
		while id == listaId do
			task.wait(math.random(18, 45))
			local cam = workspace.CurrentCamera
			local def = A.Efectos.Pajaro
			if id ~= listaId or not cam then
				break
			end
			local a = math.random() * math.pi * 2
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.one
			p.Position = cam.CFrame.Position + Vector3.new(math.cos(a) * 70, 25, math.sin(a) * 70)
			p.Parent = cam
			local s = sonido("Pajaro", def, p, grupoEfectos, false)
			s.Volume = def.volumen
			s.RollOffMaxDistance = 300
			s.PlaybackSpeed = 0.85 + math.random() * 0.25
			s:Play()
			s.Ended:Once(function()
				p:Destroy()
			end)
		end
	end)
end

function Audio.iniciar()
	grupoMusica = grupo("SelvaMusica", 0.8)
	grupoAmbiente = grupo("SelvaAmbiente", 0.8)
	grupoEfectos = grupo("SelvaEfectos", 1)
	for i = 1, 2 do
		local s = Instance.new("Sound")
		s.Name = ("Musica%d"):format(i)
		s.SoundGroup = grupoMusica
		s.Volume = 0
		s.Parent = SoundService
		decks[i] = s
	end

	-- precarga en segundo plano (baúl: preload on approach)
	task.spawn(function()
		local lista: { Instance } = {}
		local function sumar(def: Pista)
			local s = Instance.new("Sound")
			s.SoundId = ("rbxassetid://%d"):format(def.id)
			table.insert(lista, s)
		end
		for _, t in { A.Musica, A.Ambiente, A.Efectos } :: { any } do
			for _, def in t do
				sumar(def)
			end
		end
		for _, def in A.Selva do
			sumar(def)
		end
		pcall(function()
			ContentProvider:PreloadAsync(lista)
		end)
	end)

	local jugador = Players.LocalPlayer
	local function zona()
		local z = jugador:GetAttribute("Zona")
		if z == "Lobby" or z == "Partida" then
			Audio.atenuar(1)
		end
		if z == "Lobby" then
			Audio.capas({ "Lobby" })
			Audio.musica(nil, 3)
		elseif z == "Helicoptero" then
			Audio.capas({ "Rotor" }, 1.5)
		elseif z == "Saltando" then
			Audio.capas({ "Viento" }, 0.5)
			Audio.musica("Caida", 1)
		elseif z == "Partida" then
			Audio.capas({ "SelvaNoche", "Insectos" }, 4)
			Audio.musica(nil, 4)
			listaSelva()
			pajaros()
		end
	end
	jugador:GetAttributeChangedSignal("Zona"):Connect(zona)
	zona()
end

return Audio
