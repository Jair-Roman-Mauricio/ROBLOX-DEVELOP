--!strict
--[[
	Doble local de un personaje para las cinemáticas: copia anclada por la raíz, sin scripts ni
	colisiones, con las animaciones del propio avatar (las lee de su script Animate).
]]

local Doble = {}

-- Animaciones por defecto de Roblox (R15) si el avatar no trae las suyas.
local POR_DEFECTO = {
	walk = { ruta = { "walk", "WalkAnim" }, id = "rbxassetid://913402848" },
	idle = { ruta = { "idle", "Animation1" }, id = "rbxassetid://507766388" },
	fall = { ruta = { "fall", "FallAnim" }, id = "rbxassetid://507767968" },
}

local function idAnimacion(char: Model, tipo: string): string
	local def = POR_DEFECTO[tipo]
	local nodo: Instance? = char:FindFirstChild("Animate")
	for _, n in def.ruta do
		nodo = nodo and nodo:FindFirstChild(n)
	end
	if nodo and nodo:IsA("Animation") and nodo.AnimationId ~= "" then
		return nodo.AnimationId
	end
	return def.id
end

--[[
	Devuelve el doble (o nil), sus pistas por nombre y la altura de la raíz sobre los pies.
	`animaciones` mapea un nombre propio a "walk" | "idle" | "fall".
]]
function Doble.crear(pl: Player?, animaciones: { [string]: string }): (Model?, { [string]: AnimationTrack }, number)
	local pistas: { [string]: AnimationTrack } = {}
	local char = pl and pl.Character
	if not char then
		return nil, pistas, 3
	end
	local ids: { [string]: string } = {}
	for nombre, tipo in animaciones do
		ids[nombre] = idAnimacion(char, tipo)
	end
	local antes = char.Archivable
	char.Archivable = true
	local ok, copia = pcall(function()
		return char:Clone()
	end)
	char.Archivable = antes
	if not ok or not copia then
		return nil, pistas, 3
	end
	local m = copia :: Model
	local hum = m:FindFirstChildOfClass("Humanoid")
	local raiz = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz then
		m:Destroy()
		return nil, pistas, 3
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.Anchored = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	raiz.Anchored = true
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	m.Name = "Doble"
	m.Parent = workspace.CurrentCamera
	local altura = if hum.RigType == Enum.HumanoidRigType.R15 then hum.HipHeight + raiz.Size.Y / 2 else 3
	local animador = hum:FindFirstChildOfClass("Animator")
	if not animador then
		local nuevo = Instance.new("Animator")
		nuevo.Parent = hum
		animador = nuevo
	end
	for nombre, id in ids do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok2, pista = pcall(function()
			return (animador :: Animator):LoadAnimation(a)
		end)
		if ok2 and pista then
			pistas[nombre] = pista
		end
	end
	return m, pistas, altura
end

return Doble
