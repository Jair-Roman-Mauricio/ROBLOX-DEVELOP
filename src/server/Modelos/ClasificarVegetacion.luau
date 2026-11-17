--!strict
-- Nombres de los kits en inglés/español. Las hojas/troncos de un árbol no son plantas sueltas.
local function contiene(s: string, patron: string): boolean
	return string.find(s, patron, 1, true) ~= nil
end

return function(nombre: string): string?
	local n = string.lower(nombre)
	local ACENTOS: { [string]: string } = {
		["Á"] = "a",
		["á"] = "a",
		["É"] = "e",
		["é"] = "e",
		["Í"] = "i",
		["í"] = "i",
		["Ó"] = "o",
		["ó"] = "o",
		["Ú"] = "u",
		["ú"] = "u",
	}
	for acento, simple in ACENTOS do
		n = (string.gsub(n, acento, simple))
	end
	if contiene(n, "stump") or contiene(n, "tocon") then
		return nil
	elseif contiene(n, "dead") or contiene(n, "drytree") or contiene(n, "seco") then
		return "seco"
	elseif contiene(n, "palm") or contiene(n, "palmera") then
		return "palmera"
	elseif contiene(n, "fern") or contiene(n, "helecho") then
		return "helecho"
	elseif contiene(n, "monstera") or contiene(n, "colocasia") or contiene(n, "elephant") or contiene(n, "banana") then
		return "hojaGrande"
	elseif contiene(n, "bush") or contiene(n, "shrub") or contiene(n, "arbusto") then
		return "arbusto"
	elseif contiene(n, "tree") or contiene(n, "arbol") or contiene(n, "árbol") or contiene(n, "ceiba") then
		return "arbol"
	end
	return nil
end
