--!strict
--[[
	Forma y recorrido de la serpiente, compartidos por servidor y cliente.

	Forma: la plantilla `ReplicatedStorage.Modelos.Serpiente` (importada de
	art/export/Serpiente.glb) trae la serpiente recta, con la cabeza hacia delante y estas piezas:
	  Cabeza, Ojos           la cabeza y sus ojos, rígidas
	  CuerpoNN, LomoNN       el tubo del segmento NN (01 = junto a la cabeza) y lo que crece encima
	El centro de cada CuerpoNN está sobre el eje de la columna. Si la plantilla no existe se
	construye una de partes con los mismos nombres, para poder probar sin la malla.

	Recorrido: puntos de la superficie cada PASO studs. El eje de la columna va por debajo del
	suelo (HUNDIDO * radio); al principio y al final baja en rampa hasta perderse bajo tierra.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.Serpiente

local Serpiente = {}

Serpiente.PASO = 4

export type Pieza = { parte: BasePart, desplazamiento: CFrame }
export type Segmento = { atras: number, piezas: { Pieza } } -- atras: studs detrás de la cabeza
export type Forma = {
	modelo: Model,
	radio: number,
	largo: number, -- de la cabeza a la punta de la cola
	cabeza: Segmento,
	segmentos: { Segmento },
}

export type Pasada = {
	puntos: { Vector3 }, -- superficie del suelo a lo largo del recorrido, cada PASO studs
	t0: number, -- hora del servidor (GetServerTimeNow) en que la cabeza pasa por el primer punto
	velocidad: number,
	primera: boolean, -- con cinemática
	testigo: Player?, -- a quién se le abre la tierra delante la primera vez
}

---------------------------------------------------------------------------------------------
-- Plantilla de partes (respaldo): misma estructura que la importada
---------------------------------------------------------------------------------------------

local ESCAMAS = Color3.fromRGB(38, 30, 20)
local VIENTRE = Color3.fromRGB(28, 22, 14)
local MUSGO = Color3.fromRGB(48, 62, 20)
local CORTEZA = Color3.fromRGB(44, 32, 18)
local HOJAS = Color3.fromRGB(30, 46, 16)

local function parte(
	padre: Instance,
	nombre: string,
	cf: CFrame,
	tam: Vector3,
	color: Color3,
	material: Enum.Material,
	forma: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CFrame = cf
	p.Size = tam
	p.Color = color
	p.Material = material
	if forma then
		p.Shape = forma
	end
	p.Parent = padre
	return p
end

local function plantillaDePartes(): Model
	local m = Instance.new("Model")
	m.Name = "Serpiente"
	local n, largo, radio = 24, 26, 7
	-- recta hacia -Z; la cabeza en z = 0
	local cab = parte(
		m,
		"Cabeza",
		CFrame.new(0, 0.5, -2),
		Vector3.new(12, 8, 22),
		ESCAMAS,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	cab.Name = "Cabeza"
	local ojos = Instance.new("Model")
	ojos.Name = "Ojos"
	for lado = -1, 1, 2 do
		parte(
			ojos,
			"Ojo",
			CFrame.new(lado * 4.6, 2.4, -8),
			Vector3.new(1.6, 1.2, 2),
			Color3.new(1, 1, 1),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	end
	ojos.Parent = m
	for i = 1, n do
		local z = 6 + (i - 0.5) * largo
		local r = radio * math.clamp(1 - math.max(0, i - n * 0.6) / (n * 0.45), 0.25, 1)
		local cuerpo = parte(
			m,
			("Cuerpo%02d"):format(i),
			CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(largo * 1.2, r * 2, r * 2),
			if i % 2 == 0 then ESCAMAS else VIENTRE,
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
		cuerpo.Reflectance = 0.04
		local lomo = Instance.new("Model")
		lomo.Name = ("Lomo%02d"):format(i)
		local rng = Random.new(i * 97)
		for _ = 1, 3 do
			local x, dz = rng:NextNumber(-r * 0.5, r * 0.5), rng:NextNumber(-largo * 0.4, largo * 0.4)
			parte(
				lomo,
				"Musgo",
				CFrame.new(x, r * 0.8, z + dz),
				Vector3.new(r * 0.9, r * 0.5, r * 0.9),
				MUSGO,
				Enum.Material.Grass,
				Enum.PartType.Ball
			)
		end
		if rng:NextNumber() < 0.7 then
			local alto = rng:NextNumber(10, 22)
			local x = rng:NextNumber(-r * 0.3, r * 0.3)
			parte(
				lomo,
				"Tronco",
				CFrame.new(x, r + alto / 2, z),
				Vector3.new(1.4, alto, 1.4),
				CORTEZA,
				Enum.Material.Wood
			)
			parte(
				lomo,
				"Copa",
				CFrame.new(x, r + alto, z),
				Vector3.one * rng:NextNumber(7, 11),
				HOJAS,
				Enum.Material.LeafyGrass,
				Enum.PartType.Ball
			)
		end
		lomo.Parent = m
	end
	return m
end

---------------------------------------------------------------------------------------------
-- Medidas de la plantilla
---------------------------------------------------------------------------------------------

local function partesDe(i: Instance): { BasePart }
	local lista: { BasePart } = {}
	if i:IsA("BasePart") then
		table.insert(lista, i)
	end
	for _, d in i:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(lista, d)
		end
	end
	return lista
end

-- Devuelve una copia de la plantilla (sin padre) ya medida. `importada` dice si es la malla.
function Serpiente.forma(): (Forma, boolean)
	local modelos = ReplicatedStorage:FindFirstChild("Modelos")
	local original = modelos and modelos:FindFirstChild("Serpiente")
	local importada = original ~= nil and original:IsA("Model")
	local modelo: Model = if original and original:IsA("Model") then original:Clone() else plantillaDePartes()
	for _, p in partesDe(modelo) do
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end

	local cuerpos: { [number]: BasePart } = {}
	local n = 0
	for _, hijo in modelo:GetDescendants() do
		local k = tonumber(string.match(hijo.Name, "^Cuerpo(%d+)$"))
		if k and hijo:IsA("BasePart") then
			cuerpos[k] = hijo
			n = math.max(n, k)
		end
	end
	assert(n >= 2 and cuerpos[1] and cuerpos[n], "[Serpiente] la plantilla necesita Cuerpo01..CuerpoNN")

	-- eje y orientación de la plantilla: de la cola hacia la cabeza, arriba = +Y
	local primero, ultimo = cuerpos[1].Position, cuerpos[n].Position
	local delante = (primero - ultimo).Unit
	local paso = (primero - ultimo).Magnitude / (n - 1)
	local refCabeza = primero + delante * paso
	local function marco(p: Vector3): CFrame
		return CFrame.lookAt(p, p + delante, Vector3.yAxis)
	end

	local radio = 0
	local segmentos: { Segmento } = {}
	for k = 1, n do
		local c = cuerpos[k]
		if c then
			local m = marco(c.Position)
			local piezas: { Pieza } = {}
			for _, p in partesDe(c) do
				table.insert(piezas, { parte = p, desplazamiento = m:ToObjectSpace(p.CFrame) })
			end
			local lomo = modelo:FindFirstChild(("Lomo%02d"):format(k), true)
			if lomo and not S.LOMO then
				lomo:Destroy()
			elseif lomo then
				for _, p in partesDe(lomo) do
					table.insert(piezas, { parte = p, desplazamiento = m:ToObjectSpace(p.CFrame) })
				end
			end
			-- el radio útil es el de la parte gruesa (no la cola)
			if k <= math.ceil(n * 0.5) then
				radio = math.max(radio, math.min(c.Size.Y, if c:IsA("Part") then c.Size.Z else c.Size.X) / 2)
			end
			table.insert(segmentos, { atras = (refCabeza - c.Position):Dot(delante), piezas = piezas })
		end
	end

	local mc = marco(refCabeza)
	local piezasCabeza: { Pieza } = {}
	for _, nombre in { "Cabeza", "Ojos" } do
		local i = modelo:FindFirstChild(nombre, true)
		if i then
			for _, p in partesDe(i) do
				table.insert(piezasCabeza, { parte = p, desplazamiento = mc:ToObjectSpace(p.CFrame) })
			end
		end
	end

	return {
		modelo = modelo,
		radio = radio,
		largo = (refCabeza - ultimo):Dot(delante) + paso / 2,
		cabeza = { atras = 0, piezas = piezasCabeza },
		segmentos = segmentos,
	},
		importada
end

---------------------------------------------------------------------------------------------
-- Recorrido
---------------------------------------------------------------------------------------------

export type Ruta = {
	total: number, -- studs de recorrido en superficie
	-- marco del eje de la columna a `s` studs desde el principio (puede ser < 0 o > total)
	marco: (s: number, extraHondo: number?) -> CFrame,
	superficie: (s: number) -> Vector3,
}

function Serpiente.ruta(puntos: { Vector3 }, radio: number): Ruta
	local paso = Serpiente.PASO
	local n = #puntos
	local total = (n - 1) * paso

	local function superficie(s: number): Vector3
		local f = math.clamp(s / paso, 0, n - 1)
		local i = math.min(math.floor(f), n - 2)
		return puntos[i + 1]:Lerp(puntos[i + 2], f - i)
	end

	-- cuánto baja el eje: hundido normal en el tramo, y en rampa hasta 4 radios en los extremos
	local function hondo(s: number): number
		local base = radio * S.HUNDIDO
		local rampa = math.max(0, (S.RAMPA - s) / S.RAMPA, (s - (total - S.RAMPA)) / S.RAMPA)
		return base + radio * 4 * math.min(rampa, 2.5) ^ 1.4
	end

	local function eje(s: number): Vector3
		local p = superficie(s)
		-- fuera del recorrido sigue recto por la tangente del extremo
		if s < 0 then
			p += (puntos[1] - puntos[2]).Unit * -s
		elseif s > total then
			p += (puntos[n] - puntos[n - 1]).Unit * (s - total)
		end
		return p - Vector3.yAxis * hondo(s)
	end

	local function marco(s: number, extraHondo: number?): CFrame
		local a = eje(s) - Vector3.yAxis * (extraHondo or 0)
		local b = eje(s + 3) - Vector3.yAxis * (extraHondo or 0)
		if (b - a).Magnitude < 1e-3 then
			b = a + Vector3.new(0, 0, -1)
		end
		return CFrame.lookAt(a, b, Vector3.yAxis)
	end

	return { total = total, marco = marco, superficie = superficie }
end

return Serpiente
