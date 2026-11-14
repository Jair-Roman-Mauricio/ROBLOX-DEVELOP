--!strict
--[[
	Intro en el helicóptero (servidor autoritativo). Fases, publicadas como atributos del
	modelo IntroCabina para que cada cliente monte su cinemática:
	  charla   → el piloto bromea (atributo Linea = índice en Config.Intro.LINEAS)
	  posesion → tormenta, apagón, rayo; el piloto queda poseído y habla (Linea sigue avanzando)
	  cuenta   → 30 s (atributo Fin = hora del servidor): recoger botín, ponerse el paracaídas
	             y saltar por la rampa. Quien siga dentro al acabar muere en el choque.
	Saltar = salir por el final de la rampa o caer fuera del helicóptero con paracaídas.
	Sin paracaídas, caer fuera también mata.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cabina = require(script.Parent.Modelos.Cabina)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local I = Config.Intro

local Intro = {}

local actual: Cabina.Cabina? = nil

local function humanoide(pl: Player): (Model?, Humanoid?, BasePart?)
	local char = pl.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if char and hum and hum.Health > 0 and raiz and raiz:IsA("BasePart") then
		return char, hum, raiz
	end
	return nil, nil, nil
end

local function botin(pl: Player): Folder
	local f = pl:FindFirstChild("Botin")
	if f and f:IsA("Folder") then
		return f
	end
	local nuevo = Instance.new("Folder")
	nuevo.Name = "Botin"
	nuevo.Parent = pl
	return nuevo
end

--[[
	Ejecuta la intro completa con el grupo ya anclado en el helicóptero del lobby y vuelve
	cuando ya no queda nadie dentro. `destinos`: puntos de aterrizaje; `alAterrizar(pl)` lo
	llama al terminar la caída de cada jugador.
]]
function Intro.ejecutar(grupo: { Player }, destinos: { Vector3 }, mirar: Vector3, alAterrizar: (Player) -> ())
	if actual then
		actual.destruir()
	end
	local cab = Cabina.construir(I.CABINA, workspace)
	actual = cab
	local modelo = cab.modelo
	modelo:SetAttribute("Fase", "charla")
	modelo:SetAttribute("Linea", 0)

	-- a bordo: cada jugador a su asiento, sin poder saltar mientras habla el piloto
	local dentro: { Player } = {}
	for i, pl in grupo do
		local char, hum, raiz = humanoide(pl)
		if char and hum and raiz then
			botin(pl):ClearAllChildren()
			pl:SetAttribute("Paracaidas", false)
			pcall(function()
				pl:RequestStreamAroundAsync(I.CABINA, 3)
			end)
			local asiento = cab.asientos[(i - 1) % #cab.asientos + 1]
			char:PivotTo(asiento.CFrame * CFrame.new(0, 3, 0))
			raiz.Anchored = false
			hum.UseJumpPower = true
			hum.JumpPower = 0
			asiento:Sit(hum)
			pl:SetAttribute("Zona", "Helicoptero")
			table.insert(dentro, pl)
		end
	end

	-- botín: el primero que llega se lo queda (inventario PROVISIONAL, solo nombres)
	for _, obj in cab.objetos do
		local agarre = obj.PrimaryPart
		local pp = agarre and agarre:FindFirstChildOfClass("ProximityPrompt")
		if pp then
			pp.Triggered:Connect(function(pl: Player)
				if not table.find(dentro, pl) or not obj.Parent then
					return
				end
				local valor = Instance.new("StringValue")
				valor.Name = obj.Name
				valor.Value = obj.Name
				valor.Parent = botin(pl)
				obj:Destroy()
			end)
		end
	end
	for _, mochila in cab.paracaidas do
		local agarre = mochila.PrimaryPart
		local pp = agarre and agarre:FindFirstChildOfClass("ProximityPrompt")
		if pp then
			pp.Triggered:Connect(function(pl: Player)
				local char = humanoide(pl)
				if not char or not table.find(dentro, pl) or pl:GetAttribute("Paracaidas") or not mochila.Parent then
					return
				end
				mochila:Destroy()
				pl:SetAttribute("Paracaidas", true)
				Cabina.equiparMochila(char)
			end)
		end
	end

	-- charla y posesión
	local posesion = false
	for i, linea in I.LINEAS do
		if linea.poseido and not posesion then
			posesion = true
			modelo:SetAttribute("Fase", "posesion")
			task.wait(I.PAUSA_POSESION)
		end
		modelo:SetAttribute("Linea", i)
		task.wait(linea.segundos)
	end

	-- cuenta atrás
	local fin = workspace:GetServerTimeNow() + I.CUENTA
	modelo:SetAttribute("Fin", fin)
	modelo:SetAttribute("Fase", "cuenta")
	for _, asiento in cab.asientos do
		asiento.Disabled = true
	end
	for _, pl in dentro do
		local _, hum = humanoide(pl)
		if hum then
			hum.Sit = false
			hum.JumpPower = 50
		end
	end
	for _, d in modelo:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = true
		end
	end
	cab.abrirRampa(2.2)
	cab.luzRoja.Material = Enum.Material.SmoothPlastic
	cab.luzRoja.Color = Color3.fromRGB(60, 20, 18)
	local luzRoja = cab.luzRoja:FindFirstChildOfClass("PointLight")
	if luzRoja then
		luzRoja.Enabled = false
	end
	cab.luzVerde.Material = Enum.Material.Neon
	cab.luzVerde.Color = Color3.fromRGB(60, 255, 90)
	local luzVerde = Instance.new("PointLight")
	luzVerde.Color = Color3.fromRGB(80, 255, 110)
	luzVerde.Range = 14
	luzVerde.Brightness = 2
	luzVerde.Parent = cab.luzVerde

	local saltados = 0
	local function saltar(pl: Player)
		local char, _, raiz = humanoide(pl)
		local i = table.find(dentro, pl)
		if i then
			table.remove(dentro, i)
		end
		if not char or not raiz then
			return
		end
		saltados += 1
		local destino = destinos[(saltados - 1) % #destinos + 1]
		pl:SetAttribute("Zona", "Saltando")
		raiz.Anchored = true
		pcall(function()
			pl:RequestStreamAroundAsync(destino, 3)
		end)
		char:PivotTo(CFrame.lookAt(destino + Vector3.new(0, 3, 0), destino + Vector3.new(0, 3, 0) + mirar))
		Remotes.Intro:FireClient(pl, "salto", destino, mirar)
		task.delay(I.SALTO, function()
			local c2, _, r2 = humanoide(pl)
			if c2 and r2 and pl:GetAttribute("Zona") == "Saltando" then
				local mochila = c2:FindFirstChild("MochilaParacaidas")
				if mochila then
					mochila:Destroy()
				end
				r2.Anchored = false
				alAterrizar(pl)
			end
		end)
	end

	while workspace:GetServerTimeNow() < fin and #dentro > 0 do
		for _, pl in table.clone(dentro) do
			local _, hum, raiz = humanoide(pl)
			if not hum or not raiz then
				local i = table.find(dentro, pl)
				if i then
					table.remove(dentro, i)
				end
				continue
			end
			local local_ = cab.base:PointToObjectSpace(raiz.Position)
			local fuera = local_.Z > 25.5 or local_.Y < -6 or math.abs(local_.X) > 9
			if fuera then
				if pl:GetAttribute("Paracaidas") then
					saltar(pl)
				else
					local i = table.find(dentro, pl)
					if i then
						table.remove(dentro, i)
					end
					Remotes.Aviso:FireClient(pl, "Saltaste sin paracaídas…", 4)
					hum.Health = 0
				end
			end
		end
		task.wait(0.1)
	end

	-- el helicóptero se estrella con quien siga dentro
	modelo:SetAttribute("Fase", "choque")
	for _, pl in dentro do
		Remotes.Intro:FireClient(pl, "choque")
	end
	task.wait(1.6)
	for _, pl in dentro do
		local _, hum = humanoide(pl)
		if hum then
			hum.Health = 0
		end
	end
	table.clear(dentro)
	task.delay(I.SALTO + 2, function()
		if actual == cab then
			cab.destruir()
			actual = nil
		end
	end)
end

return Intro
