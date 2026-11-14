--!strict
--[[
	Animaciones locales y baratas sobre objetos etiquetados por el servidor:
	  Antorcha   → parpadeo de la luz
	  Baliza     → destello rojo
	  Glifo      → pulso de los tótems
	  PlatoRadar → giro lento del plato
	  RotorLobby → rotor de los helicópteros del lobby; gira más rápido con gente a bordo
	Se ejecutan a ~20 Hz salvo los rotores (cada frame).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Efectos = {}

local function conjunto(etiqueta: string): { [Instance]: number }
	local s: { [Instance]: number } = {}
	for _, i in CollectionService:GetTagged(etiqueta) do
		s[i] = math.random() * 100
	end
	CollectionService:GetInstanceAddedSignal(etiqueta):Connect(function(i)
		s[i] = math.random() * 100
	end)
	CollectionService:GetInstanceRemovedSignal(etiqueta):Connect(function(i)
		s[i] = nil
	end)
	return s
end

function Efectos.iniciar()
	local antorchas = conjunto("Antorcha")
	local balizas = conjunto("Baliza")
	local glifos = conjunto("Glifo")
	local platos = conjunto("PlatoRadar")
	local rotores = conjunto("RotorLobby")
	local brilloBase: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
	local velocidad: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

	local acumulado = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()

		for rotor, _ in rotores do
			if rotor:IsA("Model") and rotor.PrimaryPart then
				local portal = rotor.Parent and rotor.Parent.Parent
				local gente = if portal then (portal:GetAttribute("Jugadores") or 0) :: number else 0
				local objetivo = if gente > 0 then 6 + gente * 3 else 0.6
				local v = velocidad[rotor] or 0.6
				v += (objetivo - v) * math.min(1, dt * 0.8)
				velocidad[rotor] = v
				rotor:PivotTo(rotor:GetPivot() * CFrame.Angles(0, v * dt, 0))
			end
		end

		acumulado += dt
		if acumulado < 0.05 then
			return
		end
		acumulado = 0

		for parte, fase in antorchas do
			local luz = parte:FindFirstChildOfClass("PointLight")
			if luz then
				local base = brilloBase[luz]
				if not base then
					base = luz.Brightness
					brilloBase[luz] = base
				end
				luz.Brightness = base * (0.8 + 0.35 * (math.noise(t * 2.4, fase) + 0.5))
			end
		end
		for parte, fase in balizas do
			local on = (t + fase) % 1.4 < 0.25
			if parte:IsA("BasePart") then
				parte.Transparency = if on then 0 else 0.7
			end
			local luz = parte:FindFirstChildOfClass("PointLight")
			if luz then
				luz.Enabled = on
			end
		end
		for parte, fase in glifos do
			if parte:IsA("BasePart") then
				parte.Transparency = 0.2 + 0.35 * (0.5 + 0.5 * math.sin(t * 1.3 + fase))
			end
		end
		for plato, _ in platos do
			if plato:IsA("Model") and plato.PrimaryPart then
				plato:PivotTo(plato:GetPivot() * CFrame.Angles(0, 0.025, 0))
			end
		end
	end)
end

return Efectos
