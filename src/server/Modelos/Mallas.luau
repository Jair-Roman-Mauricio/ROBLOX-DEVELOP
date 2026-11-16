--!strict
--[[
	Modelos importados (MeshParts) que viven en ReplicatedStorage.Modelos (carpeta assets/).

	Una malla es un asset de Roblox con dueño. Si el dueño tiene activada la privacidad de
	assets, la malla solo carga para él y para las experiencias o grupos con permiso: a otra
	cuenta le llega el MeshPart, pero invisible. Por eso antes de usar un modelo se comprueba que
	sus mallas cargan con la cuenta (en Studio) o la experiencia (publicado) que ejecuta el
	servidor. Si no cargan, `obtener` devuelve nil y quien llama construye la versión de partes.

	Cómo dar permiso al equipo: assets/README.md.
	Baúl: Creator Store and Toolbox Safety (Asset privacy), Exporting and Validating Models for
	Roblox (Creator), Parts Unions and MeshParts.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Mallas = {}

local resueltos: { [string]: Model | false } = {}
local pendientes: { [string]: { thread } } = {}

local function carga(molde: Model): (boolean, string?)
	local vistos: { [string]: boolean } = {}
	for _, d in molde:GetDescendants() do
		if d:IsA("MeshPart") and d.MeshId ~= "" and not vistos[d.MeshId] then
			vistos[d.MeshId] = true
			-- CreateMeshPartAsync descarga la malla: falla si esta cuenta no tiene acceso
			local ok, err = pcall(function()
				AssetService:CreateMeshPartAsync(Content.fromUri(d.MeshId)):Destroy()
			end)
			if not ok then
				return false, ("%s (%s): %s"):format(d.Name, d.MeshId, tostring(err))
			end
		end
	end
	return next(vistos) ~= nil, "no contiene ningún MeshPart"
end

-- Devuelve el modelo si existe y sus mallas cargan; si no, nil. Cede la primera vez que se pide
-- cada nombre (comprobación en red) y luego responde de memoria.
function Mallas.obtener(nombre: string): Model?
	if not Config.USAR_MALLAS then
		return nil
	end
	local r = resueltos[nombre]
	if r == nil then
		local cola = pendientes[nombre]
		if cola then
			table.insert(cola, coroutine.running())
			coroutine.yield()
		else
			pendientes[nombre] = {}
			local carpeta = ReplicatedStorage:FindFirstChild("Modelos")
			local m = carpeta and carpeta:FindFirstChild(nombre)
			local valor: Model | false = false
			if m and m:IsA("Model") then
				local ok, motivo = carga(m)
				if ok then
					valor = m
				else
					warn(
						("[Selva] El modelo '%s' no carga con esta cuenta; se usa la versión de partes. %s. Ver assets/README.md"):format(
							nombre,
							motivo or ""
						)
					)
				end
			end
			resueltos[nombre] = valor
			for _, hilo in pendientes[nombre] do
				task.spawn(hilo)
			end
			pendientes[nombre] = nil
		end
		r = resueltos[nombre]
	end
	return if typeof(r) == "Instance" then r else nil
end

return Mallas
