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

Config.Lobby = {
	-- Centro de la plataforma a nivel del mar, lejos del mapa para que nunca se vean. Con la
	-- plataforma importada la cubierta queda ~107 studs más arriba.
	CENTRO = Vector3.new(0, 40, 6000),
	VUELOS = 4,
	CUENTA_ATRAS = 15, -- segundos desde que se acerca el primer jugador; al terminar despega aunque vaya uno solo
	CUENTA_EQUIPO_LLENO = 5, -- segundos cuando el equipo ya es de 4
	RADIO_HELIPUERTO = 15,
	RADIO_EMBARQUE = 22, -- basta con estar a esta distancia del helicóptero
	RADIO_LIMITE = 170,
	CINEMATICA = 14.5, -- embarque épico (6.5 s) + despegue hasta perderse en el cielo (8 s)
	-- Plataforma importada (art/export/Plataforma.glb, docs/PLATAFORMA.md). Las medidas del
	-- modelo están en metros; 1 stud = 0,28 m.
	Plataforma = {
		STUDS_POR_METRO = 1 / 0.28,
		-- 1 = tamaño real (cubierta de 535 studs): demasiado grande para caminar. Con 0.42 la
		-- cubierta mide ~225 studs, queda ~45 sobre el mar y cada helipuerto es como el antiguo.
		ESCALA = 0.42,
		HELIPUERTOS = { "West", "NE", "East", "SE" }, -- uno por vuelo, en este orden
		SEPARACION_HELIPUERTOS = 259, -- metros entre los helipuertos East y West
		ALTURA_HELIPUERTOS = 32.4, -- metros sobre el mar de los helipuertos East y West
		SPAWN = Vector3.new(-50, 8, 0), -- metros (x, y en el plano de la plataforma; la altura la da el suelo)
		MIRAR = Vector3.new(0, 0, 0),
		PATAS = { Vector2.new(55, 55), Vector2.new(-55, 55), Vector2.new(-55, -55), Vector2.new(55, -55) },
		RADIO_PATA = 6, -- metros
		VIENTO = 20, -- grados desde +X hacia donde van el viento y las olas
		LUCES_MAX = 28, -- lámparas que además de brillar iluminan (las demás solo brillan)
	},
	-- Mar de tormenta: agua de terreno alrededor de la plataforma y un plano oscuro hasta el
	-- horizonte, que la neblina tapa.
	Mar = {
		RADIO = 1536, -- studs de agua de terreno alrededor del centro
		PROFUNDIDAD = 12,
		HORIZONTE = 9000,
		Agua = {
			WaterColor = Color3.fromRGB(24, 54, 64),
			WaterTransparency = 0.3,
			WaterReflectance = 0.75,
			WaterWaveSize = 1,
			WaterWaveSpeed = 22,
		},
	},
}

-- Correr: mantener Shift (L3 en mando, botón en pantalla táctil). De momento solo en el lobby;
-- en la selva queda pendiente de decidir si hay resistencia.
Config.Correr = {
	ZONAS = { Lobby = true },
	CAMINAR = 16,
	CORRER = 28,
	FOV_EXTRA = 6, -- la cámara se abre un poco al correr (0 si el jugador pide reducir movimiento)
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
		Lobby = { id = 9126201834, volumen = 0.45 }, -- "Waves Long Rolling In Constantly Heavy Surf"
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
		-- montañas: macizos de paredes casi verticales, solo lejos de senderos y zonas
		F_MONTE = 0.0017, -- frecuencia de los macizos (más bajo = macizos más grandes)
		MONTE_UMBRAL = 0.06, -- más bajo = más superficie montañosa
		MONTE_BASE = 150, -- altura de la pared
		MONTE_CUMBRE = 190, -- altura extra hasta la cumbre
		MONTE_CERCA = 40, -- a esta distancia de la ruta empieza a levantarse
		MONTE_LEJOS = 170, -- y a esta ya tiene toda su altura
		PENASCO = 75, -- altura de las torres de roca sueltas
		COCHAS = 2, -- lagunas de meandro abandonado
		COCHA_RADIO = 30,
		TOPE_ZONA = 80, -- altura máxima de la meseta de una zona
		LADERA_ALDEA = 16, -- desnivel entre el centro y el borde de la aldea de ladera
	},
	ANCHO_CAMINO = 7, -- medio ancho del sendero
	ANCHO_RIO = 16, -- medio ancho del cauce
	ORILLA = 14,
	PENDIENTE_CAMINO = 1.6, -- desnivel máximo entre muestras de sendero (cada 4 studs)
	PUENTE_MAX = 140, -- un cruce más largo invalida la semilla
	INTENTOS = 12,
	-- Mapa fijo (decisión del 18-nov-2026, ver CONTEXT.md): todas las expediciones juegan la
	-- misma selva. nil = una selva distinta en cada partida, como antes.
	SEMILLA_FIJA = 20261118 :: number?,
	-- Sitios de aterrizaje además del claro inicial; Partida elige uno al azar en cada
	-- expedición, así el mapa es el mismo pero no se empieza siempre en el mismo sitio.
	APARICIONES = 4,
	APARICION_LEJOS_ZONAS = 90, -- distancia mínima al borde de cualquier zona
	APARICION_SEPARACION = 300, -- distancia mínima entre sitios de aterrizaje
	ATAJOS = { 2, 3 }, -- caminos extra además de la ruta A-B-C-D-E-F
	ESPEJO_ALEATORIO = true, -- refleja el mapa este-oeste en la mitad de las semillas
	Vegetacion = {
		-- alturas en studs (1 stud ≈ 0,28 m): dosel real de 30 a 45 m, emergentes de 50 a 60 m
		ALTO_CEIBA = { 150, 210 },
		ALTO_ARBOL = { 62, 118 },
		ALTO_PALMERA = { 34, 62 },
		ALTO_SECO = { 40, 70 },
		ARBOLES = 990,
		HELECHOS = 2090,
		ARBUSTOS = 860,
		HOJAS_GRANDES = 530,
		ROCAS = 180, -- total, contando los peñascos (~120 partes cada roca)
		ROCAS_GRANDES = 30, -- peñascos con árboles (~540 partes cada uno)
		TRONCOS = 90,
		-- Estructura (docs/SELVA-ECOTOPOS.md): cada punto pertenece a un ecotopo y la vegetación
		-- se siembra por capas, las bajas alrededor de las altas.
		RIBERA = 42, -- studs desde la orilla que cuentan como ribera
		LADERA = 0.42, -- pendiente (desnivel / distancia) a partir de la cual es ladera
		CLAROS = 16, -- claros abiertos por la caída de un árbol
		CLARO_RADIO = { 16, 30 },
		-- distancia mínima entre árboles del dosel
		ESPACIO = { selva = 19, ribera = 14, ladera = 30, pantano = 24, santuario = 13, borde = 13 },
		CORREDOR = 30, -- cada cuántos studs un árbol enmarca el sendero (alternando lados)
		HITO_SENDERO = 280, -- cada cuántos studs de sendero hay una ceiba emergente a la vista
		HITO_ESPACIO = 150, -- distancia mínima entre ceibas
		-- ecotopos del culto (docs/SELVA-CULTO.md)
		BORDE = 0.8, -- fracción de la mitad del mapa a partir de la cual empieza el borde no jugable
		ARBOLES_BORDE = 200, -- árboles extra solo en el borde: muro de selva que cierra el mapa
		ARBOLES_SANTUARIO = 70, -- árboles extra alrededor del templo
		SANTUARIO = 150, -- studs alrededor del templo que cuentan como santuario
		PANTANO = 45, -- studs alrededor del lago negro donde todo está muerto
		MUERTOS_EN_LAGO = 10, -- árboles secos de pie dentro del lago negro
	},
	-- Agua además del río: lagos, cascada, arroyos y rápidos (docs/SELVA-CULTO.md)
	Agua = {
		PANTANO_RADIO = { 38, 58 }, -- lago negro junto a la aldea de palafitos
		CASCADA_RADIO = 34, -- lago pequeño al pie de la cascada
		CASCADA_ALTO = 46, -- caída de la cascada desde la cresta
		ARROYOS = { 3, 4 }, -- nacimientos (con el del lago); los que se atascan no se excavan: llegan 1–3
		ARROYO_ANCHO = 4, -- medio ancho del cauce
		ARROYO_HONDO = 2.2,
		RAPIDOS = 3, -- tramos del río poco profundos, con rocas
		RAPIDO_LARGO = 36,
		TRONCO_MAX = 26, -- un cruce más corto se pasa por un tronco caído en vez de un puente
		Sonidos = {
			Cascada = { id = 9120552550, volumen = 0.8 }, -- ProSoundEffects "Waterfall Steady Stream 1"
			Arroyo = { id = 9113996221, volumen = 0.45 }, -- "Creek Night Water Flowing Softly 2"
			Pantano = { id = 9112881910, volumen = 0.4 }, -- "Swamp Insect Swells 2"
		},
	},
	-- El culto a la serpiente que une el mapa: santuarios en los senderos, un altar en cada
	-- aldea y el templo escalonado (docs/SELVA-CULTO.md)
	Culto = {
		SANTUARIOS = 5,
		SANTUARIO_ESPACIO = 260, -- distancia mínima entre santuarios
		TEMPLO_PISOS = 7,
		TEMPLO_BASE = 120, -- lado de la base en studs
		TEMPLO_PISO = 12, -- alto de cada piso: con la cabeza supera el dosel (62–118)
		OFRENDAS_CADA = 18, -- studs entre ofrendas del rastro que lleva al templo
		-- tallas, escamas y espirales iguales en todos los altares
		PIEDRA = Color3.fromRGB(74, 76, 68), -- #4A4C44
		MUSGO = Color3.fromRGB(79, 107, 42), -- #4F6B2A
		RAIZ = Color3.fromRGB(58, 42, 27), -- #3A2A1B
	},
	-- Atmósfera de la selva (docs/SELVA-CULTO.md)
	Atmosfera = {
		HACES = 14, -- haces de luna en claros y sobre el agua
		LUNA = Color3.fromRGB(169, 194, 214), -- #A9C2D6
		HONGOS = Color3.fromRGB(127, 224, 176), -- #7FE0B0, muy tenue
		HONGOS_TRONCOS = 40, -- troncos caídos cerca de senderos con hongos que guían
		ARANAZOS = 26,
		MUDAS = 14, -- pieles mudadas colgando de los árboles
		NIEBLA_RIO = 160, -- studs entre bancos de niebla sobre el río
		RAICES_SENDERO = 0.3, -- probabilidad de raíces cruzando el sendero cada 60 studs
		CHARCOS = 40,
	},
	-- true = la selva de día (bruma verde y luz suave). También el atributo SelvaDia de Workspace.
	DIA = false,
}

-- IDs aprobados: nunca cargar un asset proporcionado por un cliente.
Config.VegetacionStore = {
	ACTIVADO = true,
	PAQUETES = {
		{ id = 6432306802, nombre = "Forest Pack - Roblox", oficial = true },
		{ id = 5678316277, nombre = "Realistic Jungle Foliage - vx0rn", oficial = false },
		{ id = 12157426374, nombre = "Tropical Jungle Island - PSY0PZ", oficial = false },
	},
}

-- Agua viva (server/Agua.luau y client/Agua.luau). Los peligros (pirañas y anaconda) son
-- PROPUESTA: el catálogo de amenazas sigue abierto en CONTEXT.md.
Config.Agua = {
	CORRIENTE = 7, -- studs/s que te arrastra el río mientras nadas en él
	MUESTRA_RIO = 24, -- separación de los puntos del río que se mandan a los clientes
	PIRANAS = {
		TRAMOS = 3, -- tramos del río con pirañas
		RADIO = 26,
		SEPARACION = 220,
		DANO = 6, -- por mordisco
		CADA = 0.6, -- segundos entre mordiscos mientras sigas nadando ahí
	},
	ANACONDA = {
		ACTIVA = true,
		RONDA = 5, -- velocidad rondando el lago
		CAZA = 12, -- persiguiendo (nadar es más rápido: se puede escapar)
		VISTA = 45,
		ALCANCE = 6,
		DANO = 30,
		ENFRIAMIENTO = 5,
		PROFUNDIDAD = 3, -- bajo la superficie mientras ronda
		GRACIA = 25, -- segundos tras aterrizar sin peligros del agua
	},
	DELFINES = 3, -- delfines rosados cerca del jugador (solo visuales)
	RESTOS = 14, -- hojas y ramas que flotan río abajo (solo visuales)
}

Config.Partida = {
	-- Primera persona estable: tensión por encuadre y periferia, sin movimiento artificial.
	Camara = {
		FOV = 70,
		VINETA = 0.26,
	},
}

-- Primer monstruo: una serpiente gigante que repta bajo la selva con árboles y rocas sobre el
-- lomo. Por ahora solo se mueve, no ataca. La primera vez aparece con una cinemática; luego
-- vuelve a pasar de vez en cuando. Abre el suelo a su paso y el terreno se regenera después.
Config.Serpiente = {
	ACTIVADA = true,
	PRIMERA = { 45, 90 }, -- segundos desde que aterriza el primero hasta que tiembla
	REPETIR = { 150, 260 }, -- pausa entre pasadas siguientes
	AVISO = 6, -- segundos de temblor antes de que asome
	VELOCIDAD = 34, -- studs por segundo
	DISTANCIA = { 95, 130 }, -- a qué distancia del testigo abre la tierra la primera vez
	RECORRIDO = 1500, -- studs de recorrido antes de volver a hundirse
	RAMPA = 70, -- studs que tarda en subir desde lo hondo hasta asomar el lomo
	HUNDIDO = 0.55, -- fracción del radio del cuerpo que va bajo el suelo
	HUNDIDO_CABEZA = 1.1, -- la cabeza va más honda: no se la ve de frente
	REGENERA = 50, -- segundos que tarda el suelo abierto en cerrarse
	MARGEN_ZONA = 45, -- distancia mínima a pueblos, claro inicial, helicóptero y salida
	MAX_ARRASTRADOS = 80, -- árboles, rocas y plantas que puede romper en una pasada
	CRATER = 3.2, -- radio del cráter de entrada y de salida, en radios del cuerpo
	LOMO = false, -- la vegetación que trae el modelo sobre el lomo (se ve mal al hundirse)
	-- ProSoundEffects (biblioteca con licencia de Roblox)
	Sonidos = {
		Temblor = { id = 9112775181, volumen = 1 }, -- "Earthquake Rumble 2"
		Derrumbe = { id = 9113218938, volumen = 0.9 }, -- "Avalanche Deep Crumbling 4"
		Raices = { id = 9120818969, volumen = 0.6 }, -- "Wood Crack Busy Clunky Splintering 3"
		Rocas = { id = 9125884445, volumen = 0.7 }, -- "Rocks Tumble Falling Down Cliff"
		Rugido = { id = 9113980680, volumen = 0.7 }, -- "Creature Mix Giant Crab Monster Roar Growl 5"
		Pajaros = { id = 9125738421, volumen = 0.8 }, -- "Pigeon Surges Sudden Bursts Of Birds Flying"
		Infrasonido = { id = 9112795571, volumen = 1 }, -- "Hollow Rumble 2", tocado más grave
		Presencia = { id = 9112775612, volumen = 0.7 }, -- "Eerie Presence 1"
		Siseo = { id = 9119302978, volumen = 0.9 }, -- "Snake Hiss 2"
	},
	-- Cómo da miedo sin enseñarse (docs/SERPIENTE-MIEDO.md): se oye antes de verse, la selva se
	-- calla, la linterna falla cerca de ella, asoma solo los ojos y te sigue con la mirada.
	Miedo = {
		SILENCIO = 1.5, -- segundos en que la selva se calla después de que huyan los pájaros
		LINTERNA = 180, -- a menos de esta distancia la linterna parpadea
		SISEO = { 6, 14 }, -- segundos entre siseos cuando está a menos de 140 studs
		ASOMAR_CADA = 34, -- cada cuántos segundos asoma los ojos (no en la cinemática)
		ASOMAR_DURA = 4,
		-- valle inquietante: cada TIRON_CADA s se mueve unos segundos a pocos fotogramas
		TIRON_CADA = 23,
		TIRON_DURA = 2.2,
		TIRON_FPS = 5,
	},
	-- filtro de miedo: cuanto más cerca está la serpiente, más se apaga el color de la pantalla
	Filtro = {
		DISTANCIA = 420,
		SATURACION = -0.45,
		CONTRASTE = 0.22,
		TINTE = Color3.fromRGB(255, 220, 206),
		SILUETA = Color3.fromRGB(120, 34, 18), -- borde casi invisible: se intuye, no se ve
		SILUETA_TRANSPARENCIA = 0.88,
		OJOS = Color3.fromRGB(214, 226, 70),
	},
}

-- Ciclo de día y noche de la selva (server/Ciclo.luau). PROPUESTA: duración y ritmo del día y
-- la noche siguen abiertos en CONTEXT.md. Con ACTIVO = false la selva es siempre de noche y
-- vuelve a mandar el atributo SelvaDia puesto a mano.
Config.Ciclo = {
	ACTIVO = true,
	DURACION = 1200, -- segundos reales por día completo (20 min: ~7,5 min de noche, 10 de día)
	HORA_INICIO = 21, -- el equipo aterriza de noche
	AMANECER = 6,
	ANOCHECER = 18.5,
	TRANSICION = 20, -- segundos que dura el paso de la luz de noche a la de día y al revés
}

-- Linterna. PROVISIONAL: el inventario y las herramientas son una decisión abierta (CONTEXT.md).
-- Cada superviviente recibe una al aterrizar; no gasta batería.
Config.Linterna = {
	OBJETO = "Linterna",
	TECLA = Enum.KeyCode.F,
	BOTON_MANDO = Enum.KeyCode.ButtonY,
	ALCANCE = 120, -- studs (máximo del motor: 120)
	ANGULO = 58,
	BRILLO = 6,
	COLOR = Color3.fromRGB(255, 240, 214),
	ESPERA = 0.25, -- segundos mínimos entre pulsaciones (lo valida el servidor)
}

-- Fauna. PROPUESTA: el catálogo de amenazas sigue abierto en CONTEXT.md; valores para probar.
-- Velocidades pensadas contra el WalkSpeed por defecto (16): el jaguar solo es más rápido en la
-- embestida corta, así que siempre se le puede dejar atrás (baúl: Horror Monster Chase AI).
Config.Fauna = {
	JAGUARES = 5, -- 0 = sin jaguares
	JAGUAR = {
		VELOCIDAD = { Merodea = 6, Acecha = 9, Agazapa = 0, Embiste = 24, Persigue = 13, Huye = 18, Vuelve = 8 },
		GIRO = 5, -- rapidez de giro
		VISTA = 60, -- studs
		CONO = 70, -- medio ángulo de visión, en grados
		SENTIR = 10, -- te nota a esta distancia aunque esté de espaldas
		PERDER = 4, -- segundos sin verte antes de rendirse
		EMBESTIDA_DISTANCIA = 22,
		AGAZAPADO = 0.7, -- aviso antes de saltar
		EMBESTIDA_SEGUNDOS = 1.4,
		EMBESTIDA_ENFRIAMIENTO = 6,
		ALCANCE = 5.5,
		DANO = 35,
		ENFRIAMIENTO_JUGADOR = 2.5, -- un mismo jugador no recibe mordiscos más seguidos que esto
		GRACIA = 25, -- segundos tras aterrizar en los que no ataca
		CORREA = 180, -- distancia máxima a su territorio
		PATRULLA = 80, -- radio de paseo
		PAUSA = { 2, 6 },
		DESPERTAR = 260, -- solo piensa con un jugador a esta distancia
		DISTANCIA_ZONAS = 70, -- su territorio queda al menos a esto de cualquier zona
		AHUYENTAR = {
			GRUPO = 2, -- jugadores juntos cerca que lo hacen huir
			RADIO_GRUPO = 16,
			ENCARAR_DISTANCIA = 18,
			ENCARAR_ANGULO = 30,
			ENCARAR_SEGUNDOS = 1.2, -- plantarle cara este tiempo mientras acecha
			HUIDA = 8,
			MIEDO = 20, -- tras huir, no vuelve a acechar en este tiempo
		},
	},
	-- Aves solo visuales, en cada cliente (no afectan al juego)
	AVES = {
		BANDADAS = 3,
		POR_BANDADA = { 4, 7 },
		ALTURA = { 40, 62 }, -- sobre el suelo, por encima del dosel
		RADIO = { 22, 46 },
		VELOCIDAD = { 16, 24 },
		RECICLAR = 320, -- una bandada más lejos que esto reaparece cerca del jugador
		SUSTO = { 35, 80 }, -- cada cuánto sale una bandada asustada de entre los árboles
	},
}

-- Presets locales. Por petición del equipo, la selva apenas revela siluetas: la
-- lectura del suelo depende de la linterna y de las luces locales de los lugares.

-- Presets de iluminación que aplica cada cliente. Base: receta "Readable night" del baúl
-- (07 Lighting VFX and Audio/Stylized Lighting Recipes): la noche se marca con tono azul y
-- menos saturación, no con oscuridad. Debe verse una silueta a 50 studs.
Config.Iluminacion = {
	-- tormenta en el mar del Norte (como los renders de la plataforma): cielo gris, luz fría,
	-- neblina que se come el horizonte
	Lobby = {
		Lighting = {
			ClockTime = 14.5,
			GeographicLatitude = 30,
			Brightness = 1.4,
			Ambient = Color3.fromRGB(70, 78, 86),
			OutdoorAmbient = Color3.fromRGB(110, 120, 130),
			ColorShift_Top = Color3.fromRGB(200, 215, 230),
			ColorShift_Bottom = Color3.fromRGB(40, 48, 58),
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 1, -- el metal refleja el cielo de tormenta
			ExposureCompensation = 0,
		},
		Atmosphere = {
			Density = 0.42,
			Offset = 0.1,
			Color = Color3.fromRGB(170, 182, 192),
			Decay = Color3.fromRGB(86, 97, 106),
			Glare = 0,
			Haze = 2.4,
		},
		Bloom = { Intensity = 0.5, Size = 28, Threshold = 1.2 },
		Color = { Brightness = -0.02, Contrast = 0.12, Saturation = -0.3, TintColor = Color3.fromRGB(230, 238, 245) },
		Rayos = { Intensity = 0, Spread = 0.6 },
		Luciernagas = 0,
		Niebla = 10,
		Agua = Config.Lobby.Mar.Agua,
		Nubes = { Cover = 0.9, Density = 0.75, Color = Color3.fromRGB(150, 158, 166) },
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
	-- Selva: muy oscura, pero sin linterna se distinguen las siluetas de troncos, suelo y
	-- compañeros a unos 40 studs aun bajo el dosel. Antes era negro total (Ambient 3,4,6, Brightness 0) y fuera
	-- de la linterna y las fogatas no se veía nada. Punto medio entre la "selva oscura" que
	-- pidió el equipo y la receta "Readable night" del baúl (07 Lighting VFX and Audio/
	-- Stylized Lighting Recipes): la noche se marca con tono azul, no con negro.
	-- Las luces locales de edificios y antorchas no se tocan.
	Noche = {
		Lighting = {
			ClockTime = 0,
			Brightness = 0.6,
			Ambient = Color3.fromRGB(60, 70, 110),
			OutdoorAmbient = Color3.fromRGB(80, 95, 140),
			ColorShift_Top = Color3.fromRGB(150, 170, 255),
			ColorShift_Bottom = Color3.new(0, 0, 0),
			EnvironmentDiffuseScale = 0.2,
			EnvironmentSpecularScale = 0.15,
			ExposureCompensation = 0.3,
		},
		Atmosphere = {
			Density = 0.34,
			Offset = 0.05,
			Color = Color3.fromRGB(60, 75, 120),
			Decay = Color3.fromRGB(30, 35, 70),
			Glare = 0,
			Haze = 1.6,
		},
		Bloom = { Intensity = 0.4, Size = 22, Threshold = 1.2 }, -- antorchas y hongos brillan
		Color = { Brightness = 0, Contrast = 0.14, Saturation = -0.25, TintColor = Color3.fromRGB(230, 237, 250) },
		Rayos = { Intensity = 0, Spread = 0.6 },
		Luciernagas = 12,
		Niebla = 4,
		-- el río de la selva: casi quieto (mismos valores que Terreno.estilo)
		Agua = {
			WaterColor = Color3.fromRGB(34, 58, 52),
			WaterTransparency = 0.55,
			WaterReflectance = 0.6,
			WaterWaveSize = 0.12,
			WaterWaveSpeed = 6,
		},
	},
}

-- Selva de día (Config.Mapa.DIA o atributo SelvaDia de Workspace): bruma verde, luz suave
-- filtrada por el dosel, como la primera foto de referencia.
Config.Iluminacion.Dia = {
	Lighting = {
		ClockTime = 9.5,
		GeographicLatitude = 0,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(46, 60, 44),
		OutdoorAmbient = Color3.fromRGB(96, 118, 88),
		ColorShift_Top = Color3.fromRGB(214, 236, 196),
		ColorShift_Bottom = Color3.fromRGB(30, 46, 30),
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0.6,
		ExposureCompensation = 0,
	},
	Atmosphere = {
		Density = 0.4,
		Offset = 0.1,
		Color = Color3.fromRGB(150, 178, 132),
		Decay = Color3.fromRGB(70, 96, 64),
		Glare = 0.2,
		Haze = 2.2,
	},
	Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.3 },
	Color = { Brightness = 0, Contrast = 0.08, Saturation = 0.05, TintColor = Color3.fromRGB(232, 246, 222) },
	Rayos = { Intensity = 0.12, Spread = 0.8 },
	Luciernagas = 0,
	Niebla = 3,
	Agua = (Config.Iluminacion :: any).Noche.Agua,
}

-- Sensación de estar observado entre pasadas de la serpiente (docs/SERPIENTE-MIEDO.md). Empieza
-- cuando termina la primera cinemática. Los intervalos son al azar a propósito: una amenaza
-- impredecible mantiene la ansiedad, una predecible solo da un susto.
Config.Acecho = {
	ESPERA_INICIAL = 30, -- segundos tras la primera aparición antes del primer evento
	ENTRE = { 5, 16 }, -- segundos al azar entre eventos
	-- peso de cada evento al elegir el siguiente
	Pesos = { Susurro = 4, Ojos = 3, Arbusto = 2, Rama = 2, Respiracion = 1 },
	OJOS_DISTANCIA = { 35, 70 },
	OJOS_ANGULO = { 38, 62 }, -- grados desde donde mira el jugador: en el borde de la vista
	OJOS_MIRADA = 12, -- si el jugador los mira a menos de estos grados, desaparecen
	OJOS_DURA = 7,
	Sonidos = {
		Susurros = { 9126213995, 9126214616, 9126213744 }, -- "Whisper Bursts Unintelligible ..."
		Arbusto = { 9114518560, 9114515722, 9114518077 }, -- "Foliage Rustle", "Foliage Movement"
		Rama = { 9113582284, 9113581977, 9113582139, 9120258724 }, -- "Branch Snap ..."
		Respiracion = { 9113984056 }, -- "Creature Mix Weird Deep Monster Breathing 3"
	},
	VOLUMEN = { Susurro = 0.75, Arbusto = 0.9, Rama = 0.8, Respiracion = 0.45 },
}

return Config
