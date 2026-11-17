--!strict
-- Kits de Creator Store: las descargas nunca se parentan al DataModel. Solo se extrae
-- arte mediante una lista de clases visuales permitidas. Ningún script ajeno se ejecuta.
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local clasificar = require(script.Parent.ClasificarVegetacion)
local descubrirModelos = require(script.Parent.DescubrirVegetacion)
local Kit = require(script.Parent.Kit)

local Catalogo = {}
local preparado = false
-- tipos que ya tienen plantillas propias (assets/VegetacionStore): los kits descargados no los
-- mezclan, así un modelo propio sustituye por completo a los de la tienda en su tipo
local propios: { [string]: boolean } = {}
local catalogo: { [string]: { Model } } = {}
local cache = Instance.new("Folder")
cache.Name = "CatalogoVegetacion"
cache.Parent = ServerStorage

local copiarVisual = require(script.Parent.ArteSeguro)

-- Una malla subida por una cuenta solo carga para esa cuenta y las experiencias con permiso:
-- a otra cuenta le llega invisible. Antes de usar una plantilla propia se comprueba que sus
-- mallas cargan aquí; si no, se descarta y se usa la vegetación de respaldo.
local function mallasCargan(raiz: Instance): (boolean, string?)
	local vistos: { [string]: boolean } = {}
	for _, d in raiz:GetDescendants() do
		if d:IsA("MeshPart") and d.MeshId ~= "" and not vistos[d.MeshId] then
			vistos[d.MeshId] = true
			local ok, err = pcall(function()
				AssetService:CreateMeshPartAsync(Content.fromUri(d.MeshId)):Destroy()
			end)
			if not ok then
				return false, ("%s (%s): %s"):format(d.Name, d.MeshId, tostring(err))
			end
		end
	end
	return true, nil
end

local function registrar(original: Instance, tipo: string, id: number)
	if id ~= 0 and propios[tipo] then
		return
	end
	if id == 0 then
		local ok, motivo = mallasCargan(original)
		if not ok then
			warn(
				("[VegetacionStore] '%s' no carga con esta cuenta y se omite: %s. Ver assets/README.md"):format(
					original.Name,
					motivo or ""
				)
			)
			return
		end
	end
	local modelo = Instance.new("Model")
	modelo.Name = original.Name
	local partes = original:GetDescendants()
	if original:IsA("BasePart") then
		table.insert(partes, original)
	end
	local tronco: BasePart? = nil
	for _, parte in partes do
		if parte:IsA("BasePart") and parte.Transparency < 1 then
			local nombre = string.lower(parte.Name)
			if not string.find(nombre, "soil", 1, true) and not string.find(nombre, "groundplane", 1, true) then
				local copia = copiarVisual(parte)
				if copia and copia:IsA("BasePart") then
					copia.Parent = modelo
					if string.find(nombre, "trunk", 1, true) or string.find(nombre, "tronco", 1, true) then
						tronco = copia
					end
				end
			end
		end
	end
	if #modelo:GetChildren() == 0 then
		modelo:Destroy()
		return
	end
	local caja, tam = modelo:GetBoundingBox()
	if tam.Y < 0.2 or math.max(tam.X, tam.Y, tam.Z) > 400 then
		modelo:Destroy()
		return
	end
	-- Colisión simple solo en el tronco; nunca en las hojas o la copa.
	if tipo == "arbol" or tipo == "palmera" or tipo == "seco" then
		local d = if tronco then math.min(tronco.Size.X, tronco.Size.Z) else tam.Y * 0.025
		d = math.clamp(d, 0.4, math.max(0.4, tam.Y * 0.08))
		local pos = if tronco then tronco.Position else caja.Position
		Kit.parte(
			modelo,
			CFrame.new(pos.X, caja.Position.Y - tam.Y * 0.27, pos.Z),
			Vector3.new(d, tam.Y * 0.46, d),
			Color3.new(),
			Enum.Material.SmoothPlastic,
			{ transparencia = 1, sombra = false, consulta = false, nombre = "ColisionTronco" }
		)
	end
	modelo.PrimaryPart = nil
	modelo.WorldPivot = CFrame.new(caja.Position - Vector3.yAxis * tam.Y / 2)
	modelo:PivotTo(CFrame.identity)
	modelo:SetAttribute("AlturaOriginal", tam.Y)
	-- una plantilla puede pedir otra escala (p. ej. un árbol de copa muy ancha)
	local escala = original:GetAttribute("EscalaAlto")
	modelo:SetAttribute("EscalaAlto", if typeof(escala) == "number" then escala else 1)
	modelo:SetAttribute("CreatorStoreId", id)
	modelo:SetAttribute("TipoVegetacion", tipo)
	modelo.Parent = cache
	local lista = catalogo[tipo]
	if not lista then
		lista = {}
		catalogo[tipo] = lista
	end
	table.insert(lista, modelo)
end

local function descubrir(raiz: Instance, id: number)
	descubrirModelos(raiz, clasificar, function(modelo, tipo)
		registrar(modelo, tipo, id)
	end)
end

function Catalogo.preparar()
	if preparado then
		return
	end
	preparado = true
	if not Config.VegetacionStore.ACTIVADO then
		return
	end
	-- Plantillas insertadas a mano o versionadas en assets tienen prioridad y no necesitan
	-- red. Mantener estos contenedores fuera de Workspace evita código ajeno en ejecución.
	local locales = ServerStorage:FindFirstChild("VegetacionStore")
		or ReplicatedStorage.Modelos:FindFirstChild("VegetacionStore")
	if locales then
		descubrir(locales, 0)
		for tipo in catalogo do
			propios[tipo] = true
		end
	end
	-- Descargar en paralelo, procesar en orden fijo. Un CDN lento no bloquea la partida.
	local resultados: { [number]: { listo: boolean, ok: boolean, raiz: any } } = {}
	local aceptar = true
	for i, paquete in Config.VegetacionStore.PAQUETES do
		resultados[i] = { listo = false, ok = false, raiz = nil }
		task.spawn(function()
			local ok, raiz = pcall(function()
				return AssetService:LoadAssetAsync(paquete.id)
			end)
			if not ok and paquete.oficial then
				ok, raiz = pcall(function()
					return InsertService:LoadAsset(paquete.id)
				end)
			end
			if not aceptar then
				if ok and typeof(raiz) == "Instance" then
					raiz:Destroy()
				end
				return
			end
			resultados[i] = { listo = true, ok = ok, raiz = raiz }
		end)
	end
	local fin = os.clock() + 15
	while os.clock() < fin do
		local todos = true
		for _, resultado in resultados do
			todos = todos and resultado.listo
		end
		if todos then
			break
		end
		task.wait(0.1)
	end
	aceptar = false
	for i, paquete in Config.VegetacionStore.PAQUETES do
		local resultado = resultados[i]
		local raiz = resultado.raiz
		if resultado.ok and typeof(raiz) == "Instance" then
			local ok, err = pcall(descubrir, raiz, paquete.id)
			raiz:Destroy()
			if not ok then
				warn(("[VegetacionStore] Error leyendo %s: %s"):format(paquete.nombre, tostring(err)))
			end
		else
			warn(
				("[VegetacionStore] No se pudo cargar %s (%d). Inserta el kit en ServerStorage.VegetacionStore. %s"):format(
					paquete.nombre,
					paquete.id,
					if resultado.listo then tostring(raiz) else "Tiempo agotado"
				)
			)
		end
	end
	local total = 0
	for tipo, lista in catalogo do
		table.sort(lista, function(a, b)
			return a.Name < b.Name
		end)
		total += #lista
		print(("[VegetacionStore] %s: %d variantes"):format(tipo, #lista))
	end
	workspace:SetAttribute("VariantesCreatorStore", total)
	if total == 0 then
		warn("[VegetacionStore] Sin modelos disponibles: se mantiene la vegetación anterior, sin vaciar la selva.")
	end
end

function Catalogo.crear(tipo: string, rng: Random, suelo: Vector3, padre: Instance, rango: { number }): Model?
	local lista = catalogo[tipo]
	if not lista or #lista == 0 then
		return nil
	end
	local plantilla = lista[rng:NextInteger(1, #lista)]
	local copia = plantilla:Clone()
	local alto = plantilla:GetAttribute("AlturaOriginal") :: number
	local escala = (plantilla:GetAttribute("EscalaAlto") or 1) :: number
	copia:ScaleTo(rng:NextNumber(rango[1], rango[2]) * escala / alto)
	-- `suelo` ya viene hundido por Dispersion según la pendiente bajo el árbol
	copia:PivotTo(CFrame.new(suelo) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	copia.Parent = padre
	return copia
end

return Catalogo
