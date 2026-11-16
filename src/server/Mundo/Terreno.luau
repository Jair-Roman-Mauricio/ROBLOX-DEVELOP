--!strict
--!native
--[[
	Terreno de la selva: calcula un mapa de alturas a partir de la disposición y lo escribe
	con WriteVoxels por bloques (receta "Chunked heightfield write" del baúl,
	06 World Building and Art/Terrain Tools and Terrain API).

	Capas, en orden:
	  1. relieve de selva baja (Config.Mapa.Relieve): llanura inundable, terrazas y colinas
	     disecadas por quebradas, montañas y peñascos lejos de la ruta + borde montañoso +
	     crestas de la salida + cochas
	  2. mesetas de las zonas
	  3. senderos con altura suavizada y pendiente limitada
	  4. cauce y orillas del río
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Disposicion = require(script.Parent.Disposicion)
local Ruido = require(script.Parent.Ruido)

local C = Config.Mapa
local S = C.TAMANO
local MITAD = S / 2
local CELDA = C.CELDA
local N = S // CELDA
local AGUA = C.NIVEL_AGUA
local ANCHO = C.ANCHO_CAMINO
local RIO = C.ANCHO_RIO
local ORILLA = C.ORILLA
local R = C.Relieve
local BLOQUE = 64 -- celdas por lado en cada escritura

local M = Enum.Material

export type Datos = {
	alturas: { number },
	materiales: { Enum.Material },
	distCamino: { number },
	distRio: { number },
	distCocha: { number },
	altura: (x: number, z: number) -> number,
	distanciaCamino: (x: number, z: number) -> number,
	distanciaRio: (x: number, z: number) -> number,
}

local Terreno = {}

local function indice(ix: number, iz: number): number
	return (ix - 1) * N + iz
end

local function celdaDe(v: number): number
	return math.clamp(math.floor((v + MITAD) / CELDA) + 1, 1, N)
end

local function centro(i: number): number
	return -MITAD + (i - 0.5) * CELDA
end

-- Guarda en `dist` la distancia de cada celda a la muestra más cercana (y su valor asociado).
local function estampar(
	dist: { number },
	valor: { number }?,
	muestras: { Vector2 },
	valores: { number }?,
	radio: number
)
	local rc = math.ceil(radio / CELDA)
	for k, p in muestras do
		local cx, cz = celdaDe(p.X), celdaDe(p.Y)
		for ix = math.max(1, cx - rc), math.min(N, cx + rc) do
			local dx = centro(ix) - p.X
			for iz = math.max(1, cz - rc), math.min(N, cz + rc) do
				local dz = centro(iz) - p.Y
				local d = math.sqrt(dx * dx + dz * dz)
				local i = indice(ix, iz)
				if d < dist[i] then
					dist[i] = d
					if valor and valores then
						valor[i] = valores[k]
					end
				end
			end
		end
	end
end

function Terreno.calcular(disp: Disposicion.Disposicion, rng: Random, semilla: number): Datos
	local ox, oz = rng:NextNumber(-2000, 2000), rng:NextNumber(-2000, 2000)
	local crestas = disp.crestas

	local total = N * N
	local distRio = table.create(total, math.huge)
	estampar(distRio, nil, disp.rio, nil, RIO + ORILLA + R.VALLE_RIO)

	-- Distancia a la ruta (senderos y zonas): las montañas y los peñascos solo se levantan lejos
	-- de ella, así los senderos corren por los valles y no tienen que cortar un macizo.
	local distRuta = table.create(total, math.huge)
	do
		local puntos: { Vector2 } = {}
		for _, cam in disp.caminos do
			for j = 1, #cam.puntos, 4 do
				table.insert(puntos, cam.puntos[j])
			end
		end
		estampar(distRuta, nil, puntos, nil, R.MONTE_LEJOS + 16)
	end
	local function lejosDeRuta(x: number, z: number): number
		local d = distRuta[indice(celdaDe(x), celdaDe(z))]
		for _, zona in disp.zonas do
			local dx, dz = x - zona.pos.X, z - zona.pos.Y
			d = math.min(d, math.sqrt(dx * dx + dz * dz) - zona.radio)
		end
		return Ruido.suave(R.MONTE_CERCA, R.MONTE_LEJOS, d)
	end

	-- Quebradas: 0 en el eje del cauce y crece hacia las lomas. Los ceros de un ruido fractal
	-- forman líneas que se ramifican, parecidas a una red de drenaje; una segunda red más fina
	-- hace de afluentes, menos hondos.
	local function quebrada(wx: number, wz: number): number
		local f = R.F_QUEBRADA
		local principal = math.abs(Ruido.fbm(wx * f + 91.3, wz * f - 37.1, 3, ox, oz)) * 2
		local afluente = math.abs(Ruido.fbm(wx * f * 2.6 + 7.1, wz * f * 2.6 + 57.9, 2, oz, ox)) * 2 + 0.14
		return math.min(principal, afluente)
	end

	local function distorsion(x: number, z: number): (number, number)
		-- distorsión de dominio: formas menos redondas (baúl: Domain warping)
		return x + Ruido.fbm(x * 0.003 + 11.3, z * 0.003, 2, ox, oz) * 90,
			z + Ruido.fbm(x * 0.003, z * 0.003 + 7.7, 2, oz, ox) * 90
	end

	-- Relieve de selva baja amazónica, ordenado por el drenaje (ver docs/TOPOGRAFIA-SELVA.md):
	--   llanura inundable junto al río, con restinga (dique natural) y bajial detrás
	--   terrazas escalonadas que suben al alejarse del río
	--   colinas disecadas por quebradas: fondo plano y húmedo, ladera corta y cima redondeada
	local function base(x: number, z: number): number
		local wx, wz = distorsion(x, z)
		local piso = AGUA + 3
		local dr = distRio[indice(celdaDe(x), celdaDe(z))]
		-- 0 en la llanura inundable, 1 en tierra firme
		local firme = Ruido.suave(RIO + ORILLA * 0.5, RIO + ORILLA + R.VALLE_RIO, dr)

		local g = math.clamp(0.5 + Ruido.fbm(wx * 0.0024, wz * 0.0024, 4, ox, oz) * 1.15, 0, 1) * firme
		local e = g * R.TERRAZAS
		local peldano = math.floor(e)
		local escalon = (peldano + Ruido.suave(0.5 - R.TALUD, 0.5 + R.TALUD, e - peldano)) / R.TERRAZAS
		g += (escalon - g) * R.ESCALON
		local h = piso + g * R.GRANDE

		-- unas partes onduladas (lomadas) y otras quebradas (colinas), para que no se repita
		local quebrado = Ruido.suave(-0.3, 0.25, Ruido.fbm(x * 0.0021 + 31.7, z * 0.0021 + 5.1, 2, oz, ox))
		local v = quebrada(wx, wz)
		local ladera = Ruido.suave(R.FONDO, R.FONDO + R.LADERA, v)
		local cima = Ruido.suave(R.FONDO + R.LADERA, 1.1, v)
		local desnivel = R.COLINAS * (0.3 + 0.7 * quebrado) * (0.25 + 0.75 * g) * firme
		h += desnivel * (ladera * (1 + 0.35 * cima) - 0.45)
		h = math.max(h, piso - 1 + ladera)

		-- Montañas de selva alta: macizos de paredes casi verticales y cumbre en meseta con filos,
		-- y peñascos sueltos (torres de roca) entre ellos.
		local libre = lejosDeRuta(x, z) * firme
		if libre > 0 then
			local macizo = Ruido.fbm(wx * R.F_MONTE + 40.2, wz * R.F_MONTE - 12.8, 4, oz, ox)
			local pared = Ruido.suave(R.MONTE_UMBRAL, R.MONTE_UMBRAL + 0.09, macizo)
			if pared > 0 then
				local cumbre = Ruido.suave(R.MONTE_UMBRAL + 0.05, 0.45, macizo)
				local filo = 1 - math.min(1, math.abs(Ruido.fbm(wx * 0.0052 + 3.3, wz * 0.0052 + 9.4, 3, ox, oz)) * 2.4)
				h += libre * pared * (R.MONTE_BASE + R.MONTE_CUMBRE * cumbre * (0.5 + 0.5 * filo))
			end
			local torre = Ruido.suave(0.27, 0.33, Ruido.fbm(x * 0.0105 + 5.5, z * 0.0105 + 70.1, 2, ox, oz))
			if torre > 0 then
				h += libre * torre * R.PENASCO * (0.65 + 0.7 * math.abs(Ruido.fbm(x * 0.004, z * 0.004, 1, oz, ox)))
			end
		end

		local b = dr - (RIO + ORILLA)
		if b > -6 and b < 70 then
			h += R.RESTINGA * math.exp(-((b - 8) / 7) ^ 2) - 1.2 * math.exp(-((b - 36) / 13) ^ 2)
		end

		local borde = math.max(math.abs(x), math.abs(z)) / MITAD
		h += Ruido.suave(0.8, 0.97, borde) * (100 + 45 * Ruido.fbm(x * 0.01, z * 0.01, 2, oz, ox))
		for _, c in crestas do
			local dx, dz = x - c.X, z - c.Y
			h += 72 * math.exp(-(dx * dx + dz * dz) / (2 * 36 * 36))
		end
		return h
	end

	-- Cochas: meandros abandonados en la llanura inundable, con forma de herradura abierta
	-- hacia el río. Solo donde no pisan senderos ni zonas.
	local distCocha = table.create(total, math.huge)
	do
		local hechas, intentos = 0, 0
		local radio = R.COCHA_RADIO
		while hechas < R.COCHAS and intentos < 40 do
			intentos += 1
			local k = rng:NextInteger(2, #disp.rio - 1)
			local p = disp.rio[k]
			local dir = (disp.rio[k + 1] - disp.rio[k - 1])
			if dir.Magnitude == 0 then
				continue
			end
			local normal = Vector2.new(-dir.Y, dir.X).Unit * (if rng:NextNumber() < 0.5 then -1 else 1)
			local c = p + normal * (RIO + ORILLA + radio + rng:NextNumber(12, 26))
			local hacia = math.atan2(-normal.Y, -normal.X) -- ángulo que mira al río
			local arco: { Vector2 } = {}
			local valido = true
			for a = hacia + 0.9, hacia + math.pi * 2 - 0.9, 3 / radio do
				local q = c + Vector2.new(math.cos(a), math.sin(a)) * radio
				if math.max(math.abs(q.X), math.abs(q.Y)) > MITAD * 0.74 then
					valido = false
					break
				end
				if distRio[indice(celdaDe(q.X), celdaDe(q.Y))] < RIO + ORILLA + 10 then
					valido = false
					break
				end
				for _, zona in disp.zonas do
					if (q - zona.pos).Magnitude < zona.radio + 40 then
						valido = false
					end
				end
				for _, cam in disp.caminos do
					for j = 1, #cam.puntos, 3 do
						if (q - cam.puntos[j]).Magnitude < ANCHO + 44 then
							valido = false
							break
						end
					end
				end
				if not valido then
					break
				end
				table.insert(arco, q)
			end
			if valido and distCocha[indice(celdaDe(c.X), celdaDe(c.Y))] > radio * 3 then
				estampar(distCocha, nil, arco, nil, 18)
				hechas += 1
			end
		end
	end

	for _, zona in disp.zonas do
		local h = math.clamp(base(zona.pos.X, zona.pos.Y), AGUA + 6, R.TOPE_ZONA)
		zona.altura = if zona.tipo == "salida" then h + 14 else h
	end

	local function conZonas(x: number, z: number, h: number): number
		for _, zona in disp.zonas do
			local dx, dz = x - zona.pos.X, z - zona.pos.Y
			local d = math.sqrt(dx * dx + dz * dz)
			if d < zona.radio + 40 then
				h += (zona.altura - h) * (1 - Ruido.suave(zona.radio, zona.radio + 40, d))
			end
		end
		return h
	end

	-- alturas de los senderos: siguen el terreno suavizado, bajan poco a poco hasta la orilla
	-- antes de cruzar el río y nunca superan PENDIENTE_CAMINO entre muestras. Los limitadores
	-- solo rebajan (forman cortes en las lomas), así nunca dejan escalones.
	local d = C.PENDIENTE_CAMINO
	local orilla = AGUA + 1.5
	for _, cam in disp.caminos do
		local n = #cam.puntos
		local crudo = table.create(n, 0)
		local tope = table.create(n, 0)
		for i, p in cam.puntos do
			crudo[i] = conZonas(p.X, p.Y, base(p.X, p.Y))
			local dr = distRio[indice(celdaDe(p.X), celdaDe(p.Y))]
			tope[i] = orilla + math.max(0, dr - RIO) * (d / CELDA) * 0.9
		end
		for _ = 1, 2 do
			local s = table.create(n, 0)
			for i = 1, n do
				local suma, cuenta = 0, 0
				for j = math.max(1, i - 6), math.min(n, i + 6) do
					suma += crudo[j]
					cuenta += 1
				end
				s[i] = suma / cuenta
			end
			crudo = s
		end
		for i = 1, n do
			crudo[i] = math.max(math.min(crudo[i], tope[i]), orilla)
		end
		for i = 2, n do
			crudo[i] = math.min(crudo[i], crudo[i - 1] + d)
		end
		for i = n - 1, 1, -1 do
			crudo[i] = math.min(crudo[i], crudo[i + 1] + d)
		end
		cam.alturas = crudo
	end

	local distCamino = table.create(total, math.huge)
	local alturaCamino = table.create(total, 0)
	for _, cam in disp.caminos do
		estampar(distCamino, alturaCamino, cam.puntos, cam.alturas, ANCHO + 22)
	end

	local alturas = table.create(total, 0)
	for ix = 1, N do
		local x = centro(ix)
		for iz = 1, N do
			local z = centro(iz)
			local i = indice(ix, iz)
			local h0 = base(x, z)
			local h = conZonas(x, z, h0)
			-- relieve fino fuera de las mesetas
			if math.abs(h - h0) < 0.5 then
				h += Ruido.fbm(x * 0.05, z * 0.05, 2, oz, ox) * R.FINO
			end
			local dc = distCamino[i]
			local wc = 0
			if dc < ANCHO + 20 then
				wc = 1 - Ruido.suave(ANCHO, ANCHO + 20, dc)
				h += (alturaCamino[i] - h) * wc
			end
			local dr = distRio[i]
			if dr < RIO + ORILLA then
				local fondo = AGUA - 2.5
				if dr < RIO then
					local t = dr / RIO
					h = math.min(h, fondo - 6 * (1 - t * t))
				else
					-- la orilla no se excava bajo el sendero: el puente arranca en el borde del cauce
					local talud = math.min(h, fondo + (h - fondo) * Ruido.suave(RIO, RIO + ORILLA, dr))
					h = talud + (h - talud) * wc
				end
			end
			local dk = distCocha[i]
			if dk < 15 then
				local lecho = AGUA - 0.6 - 3.2 * (1 - math.min(1, dk / 7) ^ 2)
				h = math.min(h, lecho + (h - lecho) * Ruido.suave(6, 15, dk))
			end
			alturas[i] = h
		end
	end

	-- materiales por columna
	local materiales = table.create(total, M.LeafyGrass)
	for ix = 1, N do
		local x = centro(ix)
		for iz = 1, N do
			local z = centro(iz)
			local i = indice(ix, iz)
			local h = alturas[i]
			local pend = math.max(
				math.abs(alturas[indice(math.min(N, ix + 1), iz)] - alturas[indice(math.max(1, ix - 1), iz)]),
				math.abs(alturas[indice(ix, math.min(N, iz + 1))] - alturas[indice(ix, math.max(1, iz - 1))])
			) / (2 * CELDA)
			local dr, dc = distRio[i], distCamino[i]
			local ruido = math.noise(x * 0.03 + ox, z * 0.03 + oz, 1.7)
			local azar = Ruido.azar(ix, iz, semilla)
			local mat: Enum.Material
			if distCocha[i] < 17 then
				mat = M.Mud
			elseif h < AGUA + 0.5 and dr < RIO + ORILLA then
				mat = if ruido > 0.15 then M.Ground else M.Mud
			elseif dr < RIO + ORILLA + 3 then
				mat = if azar < 0.6 then M.Mud else M.LeafyGrass
			elseif dc < ANCHO - 1 then
				mat = if ruido > 0.3 then M.Mud else M.Ground
			elseif dc < ANCHO + 3 and azar < (ANCHO + 3 - dc) / 4 then
				mat = M.Ground
			else
				local zona: Disposicion.Zona? = nil
				local dz = 0
				for _, zn in disp.zonas do
					local dist = (Vector2.new(x, z) - zn.pos).Magnitude
					if dist < zn.radio * 0.92 then
						zona, dz = zn, dist
						break
					end
				end
				if zona then
					if zona.tipo == "pueblo" then
						mat = if ruido > 0.2 then M.Mud elseif azar < 0.15 then M.LeafyGrass else M.Ground
					elseif zona.tipo == "helicoptero" then
						mat = if dz < 16 and azar < 0.7 then M.Basalt elseif ruido > 0 then M.Ground else M.Mud
					elseif zona.tipo == "inicio" then
						mat = if ruido > 0.1 then M.Grass else M.Ground
					else
						mat = if ruido > 0 then M.Rock else M.Ground
					end
				elseif pend > 1.15 then
					mat = M.Rock
				elseif h > 100 and pend > 0.45 then
					mat = if ruido > 0 then M.Rock else M.Slate
				elseif pend > 0.7 then
					mat = if ruido > 0 then M.Ground else M.Rock
				elseif quebrada(distorsion(x, z)) < R.FONDO * 0.9 and h < 70 then
					-- fondo de quebrada: suelo encharcado
					mat = if azar < 0.7 then M.Mud else M.LeafyGrass
				elseif dr > RIO + ORILLA + 24 and dr < RIO + ORILLA + 52 and h < AGUA + 6 then
					-- bajial detrás de la restinga
					mat = if ruido > -0.1 then M.Mud else M.LeafyGrass
				else
					local manchas = Ruido.fbm(x * 0.012, z * 0.012, 2, ox, oz)
					mat = if manchas > 0.22 then M.Grass elseif manchas < -0.28 then M.Mud else M.LeafyGrass
				end
			end
			materiales[i] = mat
		end
	end

	local datos: Datos
	datos = {
		alturas = alturas,
		materiales = materiales,
		distCamino = distCamino,
		distRio = distRio,
		distCocha = distCocha,
		-- interpolación bilineal entre centros de celda
		altura = function(x: number, z: number): number
			local fx = math.clamp((x + MITAD) / CELDA + 0.5, 1, N)
			local fz = math.clamp((z + MITAD) / CELDA + 0.5, 1, N)
			local ix, iz = math.min(math.floor(fx), N - 1), math.min(math.floor(fz), N - 1)
			local tx, tz = fx - ix, fz - iz
			local a = alturas[indice(ix, iz)] + (alturas[indice(ix + 1, iz)] - alturas[indice(ix, iz)]) * tx
			local b = alturas[indice(ix, iz + 1)] + (alturas[indice(ix + 1, iz + 1)] - alturas[indice(ix, iz + 1)]) * tx
			return a + (b - a) * tz
		end,
		distanciaCamino = function(x: number, z: number): number
			return distCamino[indice(celdaDe(x), celdaDe(z))]
		end,
		distanciaRio = function(x: number, z: number): number
			return distRio[indice(celdaDe(x), celdaDe(z))]
		end,
	}
	return datos
end

function Terreno.escribir(datos: Datos, progreso: (number) -> ())
	local terreno = workspace.Terrain
	local alturas, materiales, distRio, distCocha = datos.alturas, datos.materiales, datos.distRio, datos.distCocha
	local bloques = N // BLOQUE
	local hechos = 0
	for bx = 0, bloques - 1 do
		for bz = 0, bloques - 1 do
			local ix0, iz0 = bx * BLOQUE + 1, bz * BLOQUE + 1
			local hmin, hmax, agua = math.huge, -math.huge, false
			for ix = ix0, ix0 + BLOQUE - 1 do
				for iz = iz0, iz0 + BLOQUE - 1 do
					local i = indice(ix, iz)
					hmin = math.min(hmin, alturas[i])
					hmax = math.max(hmax, alturas[i])
					agua = agua or distRio[i] < RIO + ORILLA + 8 or distCocha[i] < 16
				end
			end
			local y0 = math.floor((hmin - 16) / CELDA) * CELDA
			local y1 = math.ceil((math.max(hmax, if agua then AGUA else hmax) + 4) / CELDA) * CELDA
			local ny = (y1 - y0) // CELDA
			local region = Region3.new(
				Vector3.new(centro(ix0) - CELDA / 2, y0, centro(iz0) - CELDA / 2),
				Vector3.new(centro(ix0 + BLOQUE - 1) + CELDA / 2, y1, centro(iz0 + BLOQUE - 1) + CELDA / 2)
			)
			local mats, occs = table.create(BLOQUE), table.create(BLOQUE)
			for lx = 1, BLOQUE do
				local mx, ox = table.create(ny), table.create(ny)
				for ly = 1, ny do
					mx[ly], ox[ly] = table.create(BLOQUE), table.create(BLOQUE)
				end
				for lz = 1, BLOQUE do
					local i = indice(ix0 + lx - 1, iz0 + lz - 1)
					local h, mat = alturas[i], materiales[i]
					local mojado = distRio[i] < RIO + ORILLA + 8 or distCocha[i] < 16
					for ly = 1, ny do
						local fondo = y0 + (ly - 1) * CELDA
						local occ = (h - fondo) / CELDA
						if occ >= 0.08 then
							ox[ly][lz] = math.min(occ, 1)
							-- lo profundo es roca: se ve en los acantilados
							mx[ly][lz] = if fondo < h - 10 then M.Rock else mat
						elseif mojado and fondo < AGUA then
							ox[ly][lz] = 1
							mx[ly][lz] = M.Water
						else
							ox[ly][lz] = 0
							mx[ly][lz] = M.Air
						end
					end
				end
				mats[lx], occs[lx] = mx, ox
			end
			terreno:WriteVoxels(region, CELDA, mats, occs)
			hechos += 1
			progreso(hechos / (bloques * bloques))
			task.wait()
		end
	end
end

-- Colores del terreno y del agua. Terrain.Decoration (hierba 3D) NO se puede cambiar desde
-- scripts en juego (requiere capacidad de plugin): se activa a mano en Studio.
function Terreno.estilo()
	local terreno = workspace.Terrain
	local ok, err = pcall(function()
		terreno:SetMaterialColor(M.Grass, Color3.fromRGB(58, 92, 46))
		terreno:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(64, 90, 48))
		terreno:SetMaterialColor(M.Mud, Color3.fromRGB(72, 58, 44))
		terreno:SetMaterialColor(M.Ground, Color3.fromRGB(96, 78, 58))
		terreno:SetMaterialColor(M.Rock, Color3.fromRGB(92, 94, 86))
		terreno:SetMaterialColor(M.Basalt, Color3.fromRGB(40, 38, 36))
		terreno.WaterColor = Color3.fromRGB(34, 58, 52)
		terreno.WaterTransparency = 0.55
		terreno.WaterReflectance = 0.6
		terreno.WaterWaveSize = 0.12
		terreno.WaterWaveSpeed = 6
	end)
	if not ok then
		warn("[Selva] no se pudo ajustar el estilo del terreno: " .. tostring(err))
	end
end

-- Borra solo la región del mapa (el lobby tiene su propio terreno).
function Terreno.limpiar()
	local terreno = workspace.Terrain
	local paso = BLOQUE * CELDA
	for x = -MITAD, MITAD - 1, paso do
		for z = -MITAD, MITAD - 1, paso do
			terreno:FillBlock(CFrame.new(x + paso / 2, 300, z + paso / 2), Vector3.new(paso, 760, paso), M.Air)
		end
		task.wait()
	end
end

Terreno.MITAD = MITAD

return Terreno
