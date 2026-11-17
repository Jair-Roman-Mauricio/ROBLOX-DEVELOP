--!strict
-- Copia exclusivamente arte; nunca incorpora código ni comportamiento del paquete.
local VISUAL = {
	SurfaceAppearance = true,
	SpecialMesh = true,
	BlockMesh = true,
	CylinderMesh = true,
	Texture = true,
	Decal = true,
}

local function copiarVisual(original: Instance): Instance?
	if not (original:IsA("BasePart") or VISUAL[original.ClassName]) then
		return nil
	end
	local copia = original:Clone()
	-- Se reconstruyen los hijos permitidos: no quedan scripts, luces, emisores,
	-- PackageLinks, prompts, sonidos ni constraints escondidos dentro de las piezas.
	copia:ClearAllChildren()
	for _, hijo in original:GetChildren() do
		if VISUAL[hijo.ClassName] then
			local visual = copiarVisual(hijo)
			if visual then
				visual.Parent = copia
			end
		end
	end
	if copia:IsA("BasePart") then
		copia.Anchored = true
		copia.CanCollide = false
		copia.CanTouch = false
		copia.CanQuery = false
	end
	return copia
end

return copiarVisual
