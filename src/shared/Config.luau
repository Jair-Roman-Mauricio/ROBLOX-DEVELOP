--!strict
--[[
	Ajustes compartidos entre servidor y cliente.

	Las medidas del mapa son una propuesta de trabajo (ver CONTEXT.md): requieren
	pruebas de recorrido y rendimiento antes de darlas por buenas.
]]

local Config = {}

Config.MAX_POR_EQUIPO = 4

Config.Lobby = {
	CENTRO = Vector3.new(0, 60, 1700), -- lejos del mapa para que nunca se vean
	VUELOS = 4,
	CUENTA_ATRAS = 15, -- segundos desde que se acerca el primer jugador; al terminar despega aunque vaya uno solo
	CUENTA_EQUIPO_LLENO = 5, -- segundos cuando el equipo ya es de 4
	RADIO_HELIPUERTO = 15,
	RADIO_EMBARQUE = 22, -- basta con estar a esta distancia del helicóptero
	RADIO_LIMITE = 170,
	CINEMATICA = 12, -- segundos de la cinemática de despegue
}

Config.Mapa = {
	TAMANO = 1536, -- studs por lado (~430 m). CONTEXT.md propone 1.000 m: pendiente de pruebas de rendimiento
	CELDA = 4, -- tamaño de vóxel del terreno
	NIVEL_AGUA = 16, -- múltiplo de CELDA para que la superficie del agua quede plana
	ALTURA_BASE = 30,
	ANCHO_CAMINO = 7, -- medio ancho del sendero
	ANCHO_RIO = 16, -- medio ancho del cauce
	ORILLA = 14,
	PENDIENTE_CAMINO = 1.6, -- desnivel máximo entre muestras de sendero (cada 4 studs)
	PUENTE_MAX = 140, -- un cruce más largo invalida la semilla
	INTENTOS = 12,
	ATAJOS = { 2, 3 }, -- caminos extra además de la ruta A-B-C-D-E-F
	ESPEJO_ALEATORIO = true, -- refleja el mapa este-oeste en la mitad de las semillas
	Vegetacion = {
		ARBOLES = 520,
		HELECHOS = 1100,
		ARBUSTOS = 450,
		HOJAS_GRANDES = 280,
		ROCAS = 160,
		TRONCOS = 45,
	},
}

Config.Partida = {
	ZOOM_MAXIMO = 18,
}

-- Presets de iluminación que aplica cada cliente. Base: receta "Readable night" del baúl
-- (07 Lighting VFX and Audio/Stylized Lighting Recipes): la noche se marca con tono azul y
-- menos saturación, no con oscuridad. Debe verse una silueta a 50 studs.
Config.Iluminacion = {
	-- receta "Golden hour" del baúl: sol bajo, sombras largas, arriba cálido y abajo violeta
	Lobby = {
		Lighting = {
			ClockTime = 17.6,
			GeographicLatitude = 30,
			Brightness = 2.2,
			Ambient = Color3.fromRGB(90, 70, 70),
			OutdoorAmbient = Color3.fromRGB(130, 100, 90),
			ColorShift_Top = Color3.fromRGB(255, 190, 120),
			ColorShift_Bottom = Color3.fromRGB(60, 40, 80),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.5,
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.35,
			Offset = 0.2,
			Color = Color3.fromRGB(255, 200, 160),
			Decay = Color3.fromRGB(200, 120, 110),
			Glare = 0.4,
			Haze = 1.5,
		},
		Bloom = { Intensity = 0.7, Size = 32, Threshold = 1.1 },
		Color = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.1, TintColor = Color3.fromRGB(255, 245, 235) },
		Rayos = { Intensity = 0.06, Spread = 0.6 },
		Luciernagas = 20,
		Niebla = 7,
	},
	Noche = {
		Lighting = {
			ClockTime = 21.8,
			Brightness = 0.9,
			Ambient = Color3.fromRGB(52, 66, 92),
			OutdoorAmbient = Color3.fromRGB(80, 100, 130),
			ColorShift_Top = Color3.fromRGB(150, 175, 255),
			ColorShift_Bottom = Color3.fromRGB(20, 30, 45),
			EnvironmentDiffuseScale = 0.25,
			EnvironmentSpecularScale = 0.3,
			ExposureCompensation = 0.3,
		},
		Atmosphere = {
			Density = 0.36,
			Offset = 0.05,
			Color = Color3.fromRGB(62, 86, 104),
			Decay = Color3.fromRGB(26, 40, 54),
			Glare = 0,
			Haze = 1.4,
		},
		Bloom = { Intensity = 0.8, Size = 30, Threshold = 0.95 },
		Color = { Brightness = 0, Contrast = 0.12, Saturation = -0.12, TintColor = Color3.fromRGB(214, 232, 240) },
		Rayos = { Intensity = 0, Spread = 0.6 },
		Luciernagas = 24,
		Niebla = 6,
	},
}

return Config
