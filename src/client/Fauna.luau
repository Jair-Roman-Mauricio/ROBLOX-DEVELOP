--!strict
--[[
	Anima en cada cliente a los animales que mueve el servidor (de momento, el jaguar).

	El servidor solo mueve la raíz (una pieza por animal, barato de replicar); aquí se doblan
	las patas al paso, la cola se mece y la cabeza cabecea o mira alrededor. Se hace cambiando
	el C0 de las soldaduras solo en este cliente: no se replica ni cambia el juego.
	Las piezas llevan el atributo Grupo ("Pata", "Cola", "Cabeza"), Articulacion (punto de giro
	en coordenadas de la raíz) y Paso (desfase de cada pata), puestos por Modelos/Animales.
]]

local RunService = game:GetService("RunService")

type Pieza = { weld: Weld, base: CFrame, grupo: string, articulacion: CFrame, paso: number }
type Animal = {
	raiz: BasePart,
	piezas: { Pieza },
	ultima: Vector3,
	vel: number,
	fase: number,
	t: number,
}

local DISTANCIA = 180 -- más lejos no se anima

local Fauna = {}

local animales: { [Model]: Animal } = {}

local function preparar(m: Model): Animal?
	local raiz = m:FindFirstChild("Raiz")
	if not raiz or not raiz:IsA("BasePart") then
		return nil
	end
	local piezas: { Pieza } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Weld") and d.Part1 then
			local parte = d.Part1
			local grupo = parte:GetAttribute("Grupo")
			local articulacion = parte:GetAttribute("Articulacion")
			if typeof(grupo) == "string" and typeof(articulacion) == "Vector3" then
				local paso = parte:GetAttribute("Paso")
				table.insert(piezas, {
					weld = d,
					base = d.C0,
					grupo = grupo,
					articulacion = CFrame.new(articulacion),
					paso = if typeof(paso) == "number" then paso else 0,
				})
			end
		end
	end
	return {
		raiz = raiz,
		piezas = piezas,
		ultima = raiz.Position,
		vel = 0,
		fase = math.random() * 6,
		t = math.random() * 10,
	}
end

local function animar(a: Animal, dt: number)
	local pos = a.raiz.Position
	local v = (pos - a.ultima).Magnitude / math.max(dt, 1 / 240)
	a.ultima = pos
	a.vel += (math.min(v, 30) - a.vel) * math.min(1, dt * 6)
	-- k: 0 quieto, 1 corriendo
	local k = math.clamp(a.vel / 12, 0, 1)
	a.fase += dt * (2 + a.vel * 0.55)
	a.t += dt

	for _, p in a.piezas do
		local giro: CFrame
		if p.grupo == "Pata" then
			local amplitud = 0.15 + 0.5 * k
			giro = if a.vel > 0.5 then CFrame.Angles(math.sin(a.fase + p.paso) * amplitud, 0, 0) else CFrame.identity
		elseif p.grupo == "Cola" then
			-- se mece despacio parado y se estira hacia atrás al correr
			giro = CFrame.Angles(-0.25 * k + math.sin(a.t * 1.3) * 0.08, math.sin(a.t * 1.7) * (0.35 - 0.2 * k), 0)
		else
			-- cabeza: parado mira a los lados; andando cabecea al paso
			local mira = math.sin(a.t * 0.45) * 0.3 * (1 - k)
			local cabeceo = math.sin(a.fase * 2) * 0.06 * k + math.sin(a.t * 1.1) * 0.03
			giro = CFrame.Angles(cabeceo, mira, 0)
		end
		p.weld.C0 = p.articulacion * giro * p.articulacion:Inverse() * p.base
	end
end

function Fauna.iniciar()
	RunService.RenderStepped:Connect(function(dt: number)
		local cam = workspace.CurrentCamera
		local selva = workspace:FindFirstChild("Selva")
		local carpeta = selva and selva:FindFirstChild("Fauna")
		if not cam or not carpeta then
			table.clear(animales)
			return
		end
		for m in animales do
			if not m.Parent then
				animales[m] = nil
			end
		end
		local ojo = cam.CFrame.Position
		for _, m in carpeta:GetChildren() do
			if m:IsA("Model") then
				local a = animales[m]
				if not a then
					local nuevo = preparar(m)
					if nuevo then
						animales[m] = nuevo
						a = nuevo
					end
				end
				if a and (a.raiz.Position - ojo).Magnitude < DISTANCIA then
					animar(a, dt)
				end
			end
		end
	end)
end

return Fauna
