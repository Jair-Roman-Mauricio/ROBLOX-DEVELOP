--!strict
-- Utilidades para construir modelos con partes. Todo anclado y con CanTouch apagado.

local CollectionService = game:GetService("CollectionService")

local Kit = {}

export type Opciones = {
	forma: Enum.PartType?,
	cuna: boolean?,
	colision: boolean?,
	sombra: boolean?,
	consulta: boolean?,
	transparencia: number?,
	reflejo: number?,
	nombre: string?,
}

-- Opciones habituales para follaje: sin colisión, sin raycasts y sin sombra (rendimiento).
Kit.FOLLAJE = { colision = false, consulta = false, sombra = false } :: Opciones
Kit.COPA = { colision = false, consulta = false } :: Opciones

function Kit.modelo(nombre: string, padre: Instance?): Model
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre
	return m
end

function Kit.parte(
	padre: Instance,
	cf: CFrame,
	tam: Vector3,
	color: Color3,
	material: Enum.Material,
	o: Opciones?
): BasePart
	local op: Opciones = o or {}
	local p: BasePart
	if op.cuna then
		p = Instance.new("WedgePart")
	else
		local parte = Instance.new("Part")
		if op.forma then
			parte.Shape = op.forma
		end
		p = parte
	end
	p.Anchored = true
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = op.colision ~= false
	p.CastShadow = op.sombra ~= false
	p.CanQuery = op.consulta ~= false
	if op.transparencia then
		p.Transparency = op.transparencia
	end
	if op.reflejo then
		p.Reflectance = op.reflejo
	end
	if op.nombre then
		p.Name = op.nombre
	end
	p.Parent = padre
	return p
end

-- Elipsoide: parte con SpecialMesh esférica que se estira al tamaño de la parte. Sirve para
-- cascos y carenados curvos. La colisión sería la caja entera, así que por defecto no colisiona.
function Kit.ovoide(
	padre: Instance,
	cf: CFrame,
	tam: Vector3,
	color: Color3,
	material: Enum.Material,
	o: Opciones?
): BasePart
	local op: Opciones = table.clone(o or {})
	if op.colision == nil then
		op.colision = false
	end
	local p = Kit.parte(padre, cf, tam, color, material, op)
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = p
	return p
end

local function arriba(dir: Vector3): Vector3
	if math.abs(dir.Unit.Y) > 0.98 then
		return Vector3.xAxis
	end
	return Vector3.yAxis
end

-- Cilindro entre dos puntos.
function Kit.cilindro(
	padre: Instance,
	desde: Vector3,
	hasta: Vector3,
	diametro: number,
	color: Color3,
	material: Enum.Material,
	o: Opciones?
): BasePart
	local dir = hasta - desde
	if dir.Magnitude < 0.05 then
		dir = Vector3.new(0, 0.05, 0)
		hasta = desde + dir
	end
	local cf = CFrame.lookAt((desde + hasta) / 2, hasta, arriba(dir)) * CFrame.Angles(0, math.pi / 2, 0)
	local op: Opciones = table.clone(o or {})
	op.forma = Enum.PartType.Cylinder
	return Kit.parte(padre, cf, Vector3.new(dir.Magnitude, diametro, diametro), color, material, op)
end

-- Tabla o viga entre dos puntos (el largo va en Z). `giro` la rota sobre su eje.
function Kit.viga(
	padre: Instance,
	desde: Vector3,
	hasta: Vector3,
	ancho: number,
	grosor: number,
	color: Color3,
	material: Enum.Material,
	o: Opciones?,
	giro: number?
): BasePart
	local dir = hasta - desde
	if dir.Magnitude < 0.05 then
		dir = Vector3.new(0, 0, 0.05)
		hasta = desde + dir
	end
	local cf = CFrame.lookAt((desde + hasta) / 2, hasta, arriba(dir))
	if giro then
		cf *= CFrame.Angles(0, 0, giro)
	end
	return Kit.parte(padre, cf, Vector3.new(ancho, grosor, dir.Magnitude), color, material, o)
end

function Kit.variar(c: Color3, rng: Random, cantidad: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(
		(h + rng:NextNumber(-0.015, 0.015)) % 1,
		math.clamp(s + rng:NextNumber(-cantidad, cantidad), 0, 1),
		math.clamp(v + rng:NextNumber(-cantidad, cantidad), 0, 1)
	)
end

function Kit.elegir<T>(rng: Random, lista: { T }): T
	return lista[rng:NextInteger(1, #lista)]
end

function Kit.luz(padre: BasePart, color: Color3, rango: number, brillo: number, sombras: boolean?): PointLight
	local luz = Instance.new("PointLight")
	luz.Color = color
	luz.Range = rango
	luz.Brightness = brillo
	luz.Shadows = sombras == true
	luz.Parent = padre
	return luz
end

function Kit.etiquetar(i: Instance, etiqueta: string)
	CollectionService:AddTag(i, etiqueta)
end

local soloTerreno = RaycastParams.new()
soloTerreno.FilterType = Enum.RaycastFilterType.Include
soloTerreno.FilterDescendantsInstances = { workspace.Terrain }

-- Superficie del terreno bajo (x, z). Raycast solo contra Terrain (baúl: Grounding props on terrain only).
function Kit.suelo(x: number, z: number): (Vector3?, Enum.Material?)
	local hit = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -1400, 0), soloTerreno)
	if hit then
		return hit.Position, hit.Material
	end
	return nil, nil
end

return Kit
