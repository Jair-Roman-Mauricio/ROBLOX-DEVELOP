--!strict
-- Ejecutar con `luau src/server/Modelos/ClasificarVegetacion.spec.luau`.
local clasificar = require("./ClasificarVegetacion")
local casos = {
	{ "Palm Tree 03", "palmera" },
	{ "Dead Tree", "seco" },
	{ "Tree Stump", false },
	{ "Trunk", false },
	{ "Leaves", false },
	{ "Butterfly", false },
	{ "GroundPlane", false },
	{ "Monstera Deliciosa", "hojaGrande" },
	{ "Elephant Ear", "hojaGrande" },
	{ "Fern02", "helecho" },
	{ "Bush_Forest", "arbusto" },
	{ "Árbol", "arbol" },
	{ "CEIBA", "arbol" },
	{ "Tropical Tree", "arbol" },
}
for _, caso in casos do
	local esperado = if caso[2] == false then nil else caso[2]
	assert(clasificar(caso[1] :: string) == esperado, "Clasificación incorrecta: " .. (caso[1] :: string))
end
print(
	"14 clasificaciones correctas: palmeras y árboles secos no se confunden con árboles genéricos; no se importan tocones ni fauna."
)
