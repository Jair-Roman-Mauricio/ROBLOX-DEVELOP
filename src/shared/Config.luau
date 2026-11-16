--!strict
--[[
	Ajustes compartidos entre servidor y cliente.

	Las medidas del mapa son una propuesta de trabajo (ver CONTEXT.md): requieren
	pruebas de recorrido y rendimiento antes de darlas por buenas.
]]

local Config = {}

Config.MAX_POR_EQUIPO = 4

-- Helicóptero del lobby: `false` = hecho con partes (carga para cualquier cuenta);
-- `true` = mallas importadas de ReplicatedStorage.Modelos.HelicopteroAMZ07, que solo cargan si
-- la cuenta o la experiencia tiene permiso sobre esos assets.
Config.HELICOPTERO_MALLAS = false

-- Modelos importados de ReplicatedStorage.Modelos (rocas). `true` = se usan si sus mallas cargan
-- con la cuenta o experiencia que ejecuta el juego, y si no, se construye la versión de partes.
-- `false` = siempre partes. Ver server/Modelos/Mallas y assets/README.md.
Config.USAR_MALLAS = true

Config.Lobby = {
	CENTRO = Vector3.new(0, 60, 1700), -- lejos del mapa para que nunca se vean
	VUELOS = 4,
	CUENTA_ATRAS = 15, -- segundos desde que se acerca el primer jugador; al terminar despega aunque vaya uno solo
	CUENTA_EQUIPO_LLENO = 5, -- segundos cuando el equipo ya es de 4
	RADIO_HELIPUERTO = 15,
	RADIO_EMBARQUE = 22, -- basta con estar a esta distancia del helicóptero
	RADIO_LIMITE = 170,
	CINEMATICA = 14.5, -- embarque épico (6.5 s) + despegue hasta perderse en el cielo (8 s)
}

-- Intro dentro del helicóptero: el piloto bromea, lo posee un espíritu y da 30 s para saltar.
Config.Intro = {
	CABINA = Vector3.new(2600, 700, 0), -- escenario de la cabina, lejos del mapa y del lobby
	CUENTA = 30,
	SALTO = 9, -- cinemática de la caída en paracaídas
	PAUSA_POSESION = 6.5, -- tormenta, apagón, el rayo ilumina la cara del piloto poseído
	LINEAS = {
		{
			quien = "Piloto",
			texto = "¡Bienvenidos a bordo de Expediciones Amazonas! Abróchense los cinturones… bueno, los que encuentren uno.",
			segundos = 5.5,
		},
		{
			quien = "Piloto",
			texto = "Hoy sobrevolamos la zona roja. Los de los pueblos dicen que ahí hay cosas que caminan de espaldas.",
			segundos = 5.5,
		},
		{ quien = "Piloto", texto = "Tranquilos, es mentira. Caminan de frente… y muy rápido.", segundos = 4.5 },
		{
			quien = "Piloto",
			texto = "El último grupo que traje quería fotos de lo que vive en el río. Volvieron las fotos. Solo las fotos.",
			segundos = 5.5,
		},
		{
			quien = "Piloto",
			texto = "Si de noche alguien los llama por su nombre desde los árboles, no contesten. Salvo que sea el guía: ese nunca contesta.",
			segundos = 6,
		},
		{
			quien = "Piloto",
			texto = "¡Ja! No pongan esa cara. Veinte años volando por aquí y nunca me ha pasado nad—",
			segundos = 4,
		},
		{
			quien = "???",
			texto = "Tienen treinta segundos para salir de aquí… o morirán.",
			segundos = 4.5,
			poseido = true,
		},
		{ quien = "???", texto = "La prueba ha comenzado.", segundos = 3, poseido = true },
	},
	-- PROVISIONAL: el inventario aún no está definido (CONTEXT.md). Solo se guardan los nombres.
	BOTIN = { "Linterna", "Botiquín", "Cantimplora", "Machete", "Bengala", "Cuerda", "Brújula", "Radio" },
}

-- Audio de la biblioteca con licencia de Roblox (APM Music y ProSoundEffects, uso libre en
-- cualquier experiencia). Cambia un id aquí para cambiar la pista en todo el juego.
Config.Audio = {
	Musica = {
		Vuelo = { id = 1845215540, volumen = 0.4 }, -- APM "Adventure Awaits!": despegue y bromas del piloto
		Cuenta = { id = 9041774484, volumen = 0.6 }, -- APM "Epic Countdown": los 30 segundos
		Caida = { id = 1837059881, volumen = 0.55 }, -- APM "Descent": salto en paracaídas
	},
	-- selva de noche: lista con silencios entre temas para que no canse (baúl: Music and Adaptive Audio)
	Selva = {
		{ id = 1836390477, volumen = 0.32 }, -- APM "Night Mist"
		{ id = 1836289781, volumen = 0.3 }, -- APM "Unseen Danger"
		{ id = 1843781882, volumen = 0.28 }, -- APM "Tension Repeat Drones 5"
		{ id = 1836290021, volumen = 0.32 }, -- APM "Footsteps Of Horror"
	},
	SILENCIO_SELVA = { 25, 70 },
	Ambiente = {
		Lobby = { id = 9112807589, volumen = 0.35 }, -- "Jungle Dusk 1"
		SelvaNoche = { id = 9112837538, volumen = 0.5 }, -- "Night Jungle 2"
		Insectos = { id = 9112810388, volumen = 0.22 }, -- "Jungle Insects 3"
		Rotor = { id = 9125390086, volumen = 0.32 }, -- Bell Huey, filtrado para sonar desde dentro
		Viento = { id = 9125742262, volumen = 0.7 },
		Susurros = { id = 1845391099, volumen = 0.55 }, -- APM "Demonic Whispers"
		Alarma = { id = 1835348569, volumen = 0.22 },
		Tictac = { id = 79953809679486, volumen = 0.35 },
		Lluvia = { id = 9112853287, volumen = 0.5 }, -- "Rain Heavy 1"
	},
	Efectos = {
		Despegue = { id = 9113417552, volumen = 0.8 },
		Posesion = { id = 1841354419, volumen = 0.9 }, -- APM "Supernaturalizer Hit 2"
		Prueba = { id = 1841353932, volumen = 0.9 }, -- APM "Rising Fear Hit 2"
		Paracaidas = { id = 9117234408, volumen = 0.9 },
		Choque = { id = 1843492223, volumen = 1 },
		Trueno = { id = 9120016037, volumen = 1 }, -- "Thunder Cracks Big Rumbling Blasts Booming 1"
		Rayo = { id = 9116282544, volumen = 0.8 }, -- "Lightning Strike Sharp Hissing Crack 1"
		Pajaro = { id = 9125614774, volumen = 0.5 },
	},
}

Config.Mapa = {
	TAMANO = 2304, -- studs por lado (~645 m; múltiplo de 256). CONTEXT.md propone 1.000 m: pendiente de pruebas de rendimiento
	CELDA = 4, -- tamaño de vóxel del terreno
	NIVEL_AGUA = 16, -- múltiplo de CELDA para que la superficie del agua quede plana
	-- Relieve de selva baja amazónica, en studs (docs/TOPOGRAFIA-SELVA.md). Los senderos siguen
	-- respetando PENDIENTE_CAMINO (cortan las lomas), así que la ruta sigue siendo caminable.
	Relieve = {
		VALLE_RIO = 170, -- ancho de la llanura inundable y de la subida a tierra firme
		RESTINGA = 3, -- altura del dique natural junto a la orilla
		GRANDE = 46, -- desnivel entre la llanura y la terraza más alta
		TERRAZAS = 3, -- número de escalones
		ESCALON = 0.75, -- 0 = rampa continua, 1 = terrazas planas con talud
		TALUD = 0.18, -- medio ancho del talud entre terrazas (fracción del escalón)
		COLINAS = 40, -- desnivel máximo entre el fondo de una quebrada y la cima
		F_QUEBRADA = 0.0046, -- frecuencia de la red de quebradas (más alto = más juntas)
		FONDO = 0.1, -- ancho del fondo plano de la quebrada
		LADERA = 0.5, -- ancho de la ladera
		FINO = 2.2, -- irregularidad a ras de suelo
		COCHAS = 2, -- lagunas de meandro abandonado
		COCHA_RADIO = 30,
		TOPE_ZONA = 80, -- altura máxima de la meseta de una zona
	},
	ANCHO_CAMINO = 7, -- medio ancho del sendero
	ANCHO_RIO = 16, -- medio ancho del cauce
	ORILLA = 14,
	PENDIENTE_CAMINO = 1.6, -- desnivel máximo entre muestras de sendero (cada 4 studs)
	PUENTE_MAX = 140, -- un cruce más largo invalida la semilla
	INTENTOS = 12,
	ATAJOS = { 2, 3 }, -- caminos extra además de la ruta A-B-C-D-E-F
	ESPEJO_ALEATORIO = true, -- refleja el mapa este-oeste en la mitad de las semillas
	Vegetacion = {
		CEIBAS = 0.1, -- fracción de los árboles que son ceibas gigantes (modelo ArbolSelva)
		ARBOLES = 990,
		HELECHOS = 2090,
		ARBUSTOS = 860,
		HOJAS_GRANDES = 530,
		ROCAS = 300, -- total, contando los peñascos
		ROCAS_GRANDES = 60, -- peñascos con árboles (modelo RocaSelva completo)
		TRONCOS = 90,
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
	-- por encima de las nubes, último sol: cálido, poca niebla
	Vuelo = {
		Lighting = {
			ClockTime = 17.9,
			GeographicLatitude = 30,
			Brightness = 2.4,
			Ambient = Color3.fromRGB(96, 78, 80),
			OutdoorAmbient = Color3.fromRGB(140, 110, 100),
			ColorShift_Top = Color3.fromRGB(255, 180, 120),
			ColorShift_Bottom = Color3.fromRGB(70, 50, 90),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.5,
			ExposureCompensation = 0.15,
		},
		Atmosphere = {
			Density = 0.22,
			Offset = 0.1,
			Color = Color3.fromRGB(255, 196, 160),
			Decay = Color3.fromRGB(190, 110, 120),
			Glare = 0.6,
			Haze = 0.8,
		},
		Bloom = { Intensity = 0.8, Size = 34, Threshold = 1.05 },
		Color = { Brightness = 0.03, Contrast = 0.1, Saturation = 0.12, TintColor = Color3.fromRGB(255, 240, 228) },
		Rayos = { Intensity = 0.08, Spread = 0.7 },
		Luciernagas = 0,
		Niebla = 0,
	},
	-- la posesión: el cielo se cierra en una tormenta
	Tormenta = {
		Lighting = {
			ClockTime = 19.4,
			Brightness = 0.35,
			Ambient = Color3.fromRGB(34, 38, 48),
			OutdoorAmbient = Color3.fromRGB(44, 50, 64),
			ColorShift_Top = Color3.fromRGB(120, 140, 190),
			ColorShift_Bottom = Color3.fromRGB(10, 12, 20),
			EnvironmentDiffuseScale = 0.15,
			EnvironmentSpecularScale = 0.3,
			ExposureCompensation = -0.2,
		},
		Atmosphere = {
			Density = 0.58,
			Offset = 0.05,
			Color = Color3.fromRGB(64, 70, 84),
			Decay = Color3.fromRGB(24, 28, 38),
			Glare = 0,
			Haze = 2.6,
		},
		Bloom = { Intensity = 1, Size = 30, Threshold = 0.9 },
		Color = { Brightness = -0.02, Contrast = 0.28, Saturation = -0.4, TintColor = Color3.fromRGB(196, 208, 230) },
		Rayos = { Intensity = 0, Spread = 0.6 },
		Luciernagas = 0,
		Niebla = 0,
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
