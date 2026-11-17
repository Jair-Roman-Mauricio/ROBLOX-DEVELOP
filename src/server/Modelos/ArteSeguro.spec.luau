--!strict
-- Ejecutar con Lune: instancia real deserializable, sin arrancar Studio ni ejecutar scripts.
local roblox = require("@lune/roblox")
local copiar = require("./ArteSeguro")
local original = roblox.Instance.new("MeshPart")
original.Name = "Fern"
original.Anchored = false
original.CanCollide = true
local material = roblox.Instance.new("SurfaceAppearance")
material.Name = "PBR"
material.Parent = original
local codigo = roblox.Instance.new("Script")
codigo.Name = "ScriptOculto"
codigo.Parent = material
local luz = roblox.Instance.new("PointLight")
luz.Parent = original
local carpeta = roblox.Instance.new("Folder")
carpeta.Parent = original
local remoto = roblox.Instance.new("RemoteEvent")
remoto.Parent = carpeta
local copia = copiar(original)
assert(copia and copia.ClassName == "MeshPart", "Se debe conservar la geometría")
assert(
	copia.Anchored and not copia.CanCollide and not copia.CanTouch and not copia.CanQuery,
	"El arte no debe alterar la física ni las consultas de la partida"
)
assert(copia:FindFirstChild("PBR"), "Se deben conservar los materiales PBR")
for _, objeto in copia:GetDescendants() do
	assert(not objeto:IsA("LuaSourceContainer"), "No debe copiar scripts, ni dentro de PBR")
	assert(not objeto:IsA("Light"), "La vegetación no debe iluminar la selva")
	assert(not objeto:IsA("RemoteEvent"), "No debe incorporar remotes")
end
assert(original:FindFirstChild("PBR"):FindFirstChild("ScriptOculto"), "No modificar el modelo original")
assert(copiar(codigo) == nil, "Nunca copiar scripts directamente")
assert(copiar(carpeta) == nil, "Nunca copiar contenedores arbitrarios")
print("Arte seguro: conserva MeshPart/PBR, descarta código anidado, luces y remotes; no modifica el original.")
