--!strict
-- Eventos y estado compartido con los clientes. Solo el servidor escribe el estado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpeta = Instance.new("Folder")
carpeta.Name = "Remotes"

local function evento(nombre: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name = nombre
	e.Parent = carpeta
	return e
end

-- Atributos: Estado ("preparando" | "lista" | "en_curso" | "error"), Progreso (0-1), Etapa, Semilla
local estado = Instance.new("Folder")
estado.Name = "EstadoPartida"
estado:SetAttribute("Estado", "preparando")
estado:SetAttribute("Progreso", 0)
estado:SetAttribute("Etapa", "")

local Remotes = {
	Aviso = evento("Aviso"), -- servidor → cliente: (texto, segundos?)
	Transicion = evento("Transicion"), -- servidor → cliente: (texto) fundido a negro
	Cinematica = evento("Cinematica"), -- servidor → cliente: (helipuerto: Model) despegue
	Intro = evento("Intro"), -- servidor → cliente: ("salto", destino, mirar) | ("choque")
	Linterna = evento("Linterna"), -- cliente → servidor: (encender: boolean)
	Serpiente = evento("Serpiente"), -- servidor → cliente: ("pasada", Pasada) | ("fin")
	Saltar = evento("Saltar"), -- cliente → servidor: ("despegue" | "cinematica") vota saltar la espera
	Estado = estado,
}

carpeta.Parent = ReplicatedStorage
estado.Parent = ReplicatedStorage

return Remotes
