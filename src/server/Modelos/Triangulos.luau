--!strict
--[[
	Superficies hechas con partes a partir de una lista de triángulos: cada triángulo se cubre
	con dos WedgeParts (se parte por la altura sobre su lado más largo). Sirve para copiar con
	partes la silueta de un modelo 3D sin subir ninguna malla a Roblox.

	Los datos salen de art/blender/modelos_a_partes.py: `v` = x,y,z por vértice y
	`t` = i,j,k,r,g,b por triángulo (índices desde 1, color 0-255).
]]

local Kit = require(script.Parent.Kit)

local Triangulos = {}

export type Malla = { v: { number }, t: { number } }

local function cuna(padre: Instance, cf: CFrame, tam: Vector3, color: Color3, material: Enum.Material, o: Kit.Opciones)
	if tam.Y > 0.02 and tam.Z > 0.02 then
		Kit.parte(padre, cf, tam, color, material, o)
	end
end

-- `mover` lleva cada vértice de los datos a su sitio (escala y posición). `grosor` es el espesor
-- de la lámina, que crece hacia dentro para tapar las juntas. `pintar` decide color y material
-- de cada cara a partir del color de los datos y de la normal.
function Triangulos.construir(
	padre: Instance,
	datos: Malla,
	mover: (Vector3) -> Vector3,
	grosor: number,
	pintar: (Color3, Vector3) -> (Color3, Enum.Material),
	o: Kit.Opciones?
)
	local v, t = datos.v, datos.t
	local puntos = table.create(#v // 3)
	for i = 1, #v, 3 do
		table.insert(puntos, mover(Vector3.new(v[i], v[i + 1], v[i + 2])))
	end
	local op: Kit.Opciones = table.clone(o or {})
	op.cuna = true
	for i = 1, #t, 6 do
		local a, b, c = puntos[t[i]], puntos[t[i + 1]], puntos[t[i + 2]]
		local normal = (b - a):Cross(c - a)
		if normal.Magnitude < 1e-4 then
			continue
		end
		normal = normal.Unit
		local color, material = pintar(Color3.fromRGB(t[i + 3], t[i + 4], t[i + 5]), normal)

		-- el lado más largo pasa a ser b-c
		local ab, ac, bc = b - a, c - a, c - b
		local lab, lac, lbc = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if lab > lac and lab > lbc then
			c, a = a, c
		elseif lac > lbc and lac > lab then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local derecha = ac:Cross(ab).Unit
		local arriba = bc:Cross(derecha).Unit
		local atras = bc.Unit
		local alto = math.abs(ab:Dot(arriba))
		local dentro = -normal * (grosor / 2)
		cuna(
			padre,
			CFrame.fromMatrix((a + b) / 2 + dentro, derecha, arriba, atras),
			Vector3.new(grosor, alto, math.abs(ab:Dot(atras))),
			color,
			material,
			op
		)
		cuna(
			padre,
			CFrame.fromMatrix((a + c) / 2 + dentro, -derecha, arriba, -atras),
			Vector3.new(grosor, alto, math.abs(ac:Dot(atras))),
			color,
			material,
			op
		)
	end
end

return Triangulos
