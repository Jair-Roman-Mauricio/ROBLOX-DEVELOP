--!strict
-- Descubre modelos completos, no las piezas Trunk/Leaves ni todo un paquete a la vez.
local TIPOS = { arbol = true, palmera = true, seco = true, helecho = true, arbusto = true, hojaGrande = true }
return function(raiz: Instance, clasificar: (string) -> string?, registrar: (Instance, string) -> ())
	local function recorrer(nodo: Instance, heredado: string?)
		local atributo = nodo:GetAttribute("TipoVegetacion")
		local explicito = if typeof(atributo) == "string" and TIPOS[atributo] then atributo else nil
		local nombre = string.lower(nodo.Name)
		local propio = clasificar(nodo.Name)
		local paquete = string.find(nombre, "pack", 1, true) ~= nil
			or string.find(nombre, "foliage", 1, true) ~= nil
			or string.find(nombre, "/", 1, true) ~= nil
			or string.find(nombre, "collection", 1, true) ~= nil
		local grupo = paquete
			or nombre == "trees"
			or nombre == "bushes"
			or nombre == "ferns"
			or nombre == "palms"
			or string.find(nombre, "models", 1, true) ~= nil
		local tipo = explicito or (if paquete then nil else propio or heredado)
		local hijos = nodo:GetChildren()
		local modelos = false
		local partesDirectas = nodo:IsA("BasePart")
		for _, hijo in hijos do
			modelos = modelos or hijo:IsA("Model") or hijo:IsA("Folder")
			partesDirectas = partesDirectas or hijo:IsA("BasePart")
		end
		if
			tipo
			and nodo ~= raiz
			and (nodo:IsA("Model") or nodo:IsA("BasePart"))
			and (explicito or not grupo)
			and (partesDirectas or not modelos or propio ~= nil or explicito ~= nil)
		then
			registrar(nodo, tipo)
			return
		end
		for _, hijo in hijos do
			if hijo:IsA("Model") or hijo:IsA("Folder") or hijo:IsA("BasePart") then
				recorrer(hijo, tipo)
			end
		end
	end
	recorrer(raiz, nil)
end
