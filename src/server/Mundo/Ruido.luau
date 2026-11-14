--!strict
--!native
-- Funciones numéricas puras para la generación (ver baúl: 34 Procedural Generation/Noise Functions).

local Ruido = {}

-- Ruido fractal. Gira las coordenadas en cada octava para ocultar la rejilla de math.noise
-- y usa un desfase no entero porque math.noise vale 0 en los enteros.
function Ruido.fbm(x: number, z: number, octavas: number, ox: number, oz: number): number
	local suma, amp, norm = 0, 1, 0
	for _ = 1, octavas do
		suma += amp * math.noise(x + ox, z + oz, 0.317)
		norm += amp
		amp *= 0.5
		x, z = (x * 0.8 - z * 0.6) * 2.03, (x * 0.6 + z * 0.8) * 2.03
	end
	return suma / norm
end

function Ruido.suave(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

function Ruido.mezclar(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Valor pseudoaleatorio estable por celda, para decisiones visuales (bordes difuminados).
function Ruido.azar(ix: number, iz: number, semilla: number): number
	local v = math.sin(ix * 12.9898 + iz * 78.233 + semilla * 0.0137) * 43758.5453
	return v - math.floor(v)
end

return Ruido
