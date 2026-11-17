--!strict
local roblox = require("@lune/roblox")
local descubrir = require("./DescubrirVegetacion")
local clasificar = require("./ClasificarVegetacion")
local function objeto(clase, nombre, padre)
	local v = roblox.Instance.new(clase)
	v.Name = nombre
	v.Parent = padre
	return v
end
local raiz = objeto("Model", "Model", nil)
local paquete = objeto("Model", "Trees / Foliage - Tropical Jungle Island", raiz)
local grupo = objeto("Model", "Trees", paquete)
local arbol = objeto("Model", "TropicalTree01", grupo)
local tronco = objeto("Model", "Trunk", arbol)
objeto("MeshPart", "Wood", tronco)
local hojas = objeto("Model", "Leaves", arbol)
objeto("MeshPart", "LeafCards", hojas)
local palma = objeto("Model", "Palm Tree", grupo)
objeto("MeshPart", "Trunk", palma)
local bush = objeto("Model", "Bush", paquete)
objeto("MeshPart", "Foliage", bush)
objeto("MeshPart", "Rock", paquete)
local custom = objeto("Model", "PlantaSinNombre", paquete)
custom:SetAttribute("TipoVegetacion", "helecho")
objeto("MeshPart", "Plant", custom)
local encontrados = {}
descubrir(raiz, clasificar, function(modelo, tipo)
	encontrados[modelo.Name] = tipo
end)
assert(encontrados.TropicalTree01 == "arbol", "Falta árbol completo")
assert(encontrados["Palm Tree"] == "palmera", "Falta palmera")
assert(encontrados.Bush == "arbusto", "Falta arbusto")
assert(encontrados.PlantaSinNombre == "helecho", "No se respeta TipoVegetacion")
assert(encontrados.Trunk == nil and encontrados.Leaves == nil, "No separar hojas y tronco")
assert(encontrados.Rock == nil, "No convertir piedras en árboles por el nombre del paquete")
assert(encontrados[paquete.Name] == nil and encontrados.Trees == nil, "No clonar una colección como un solo árbol")
local total = 0
for _ in encontrados do
	total += 1
end
assert(total == 4, "Deben seleccionarse exactamente cuatro plantas")
print("Jerarquía de kits: 4 plantas completas; sin colecciones, piedras ni árboles partidos.")
