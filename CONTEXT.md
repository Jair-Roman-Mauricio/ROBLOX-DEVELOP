# Selva / Supervivencia

Documento de contexto para agentes de IA Roblox · Cooperativo · Mapa procedural

Versión de concepto 1.0 | 13 de noviembre de 2026

## Visión del juego

Hasta cuatro turistas sufren un accidente de helicóptero y quedan atrapados en una selva amazónica generada en cada partida. Deben explorar, conseguir recursos y fabricar herramientas para sobrevivir a criaturas y anomalías. La partida termina al escapar de la selva.

Objetivo principal: sobrevivir y escapar. Objetivo secundario: encontrar pueblos indígenas fantasma y buscar señales de vida. Estos pueblos sirven como zonas de descanso y preparación.

## Reglas confirmadas

- Equipos de hasta 4 jugadores. El mapa cambia entre partidas y debe generar todo lo necesario para avanzar y escapar.

- El accidente ocurre en un helicóptero. Los jugadores pueden encontrar sus restos más adelante y utilizar su radar.

- No habrá construcción de refugios. Se fabricarán herramientas con materiales encontrados en los pueblos fantasma de la selva.

- Las entidades constituyen amenazas de terror y supervivencia. La orientación del concepto es evadirlas o ahuyentarlas temporalmente mediante objetos y comportamientos específicos.

- La muerte es definitiva por defecto. Las excepciones serán revivir con Robux o mediante eventos especiales, como ofrendas.

- La pantalla de muerte identifica al responsable: «Jugador eliminado por [nombre del monstruo]».

- Los pueblos son zonas protegidas. Al descubrirlos, el tiempo pasa al periodo diurno sin anomalías.

- En la selva, la cámara permanece en primera persona y no debe girar, balancearse ni cambiar el zoom por sí sola durante la exploración.

- La selva permanece casi completamente oscura: sin linterna apenas se distinguen las siluetas de la vegetación. La linterna es la única fuente de luz personal y alumbra un área limitada; las luces de edificios y lugares permanecen activas.

- El lobby es una plataforma industrial de hierro/acero en medio del mar, con helipuertos para los vuelos a la selva.

- Se aprueba usar los paquetes gratuitos de vegetación seleccionados de Creator Store, conservando la densidad de la selva y sus materiales.

- Antes de entrar al lobby se muestra una pantalla de carga que prepara los recursos iniciales y el renderizado. La API de Roblox no permite comprobar que hayan terminado todos los shaders.

## Cómo interpretar este documento

Las reglas anteriores vienen de las decisiones del equipo. Las medidas, distribución espacial y recomendaciones de las páginas siguientes son una propuesta de trabajo, no requisitos aprobados. No asumir que ideas antiguas de la lluvia de ideas siguen vigentes si contradicen estas reglas.

# Sistemas y progresión

## Ciclo de una partida

Accidente y entrada a la selva → exploración y búsqueda de recursos → encuentros y evasión → descubrimiento de un pueblo protegido → fabricación y preparación durante el día → nueva expedición → localización de la salida → escape.

## Pueblos y cambio de hora

Confirmado: protección dentro de los pueblos y cambio al día sin anomalías al encontrarlos. La protección no debe depender de construir un refugio.

Propuesta pendiente: activar el salto de hora una sola vez por pueblo y cuando todos los supervivientes estén dentro. El equipo todavía debe aprobar cómo tratar a jugadores alejados, desconectados o perseguidos. No implementar estas condiciones como definitivas.

## Generación procedural

El generador debe producir una ruta válida desde la zona inicial hasta la salida. Los pueblos, el helicóptero y los recursos esenciales deben resultar alcanzables. Todo bloqueo obligatorio necesita su herramienta o solución disponible antes del bloqueo.

Recomendación técnica: generar primero un grafo de zonas conectadas; colocar inicio, pueblos, helicóptero y salida; construir terreno y conexiones; distribuir recursos; validar accesibilidad. Si falla una validación, reparar o regenerar la semilla.

Variar recorridos, relieve, vegetación, suministros y puntos de interés. Conservar reglas de progresión. El ejemplo visual adjunto representa una semilla ilustrativa, no un mapa fijo obligatorio.

## Decisiones todavía abiertas

- Duración objetivo, ritmo del día y la noche, y momento exacto de aparición de anomalías.

- Forma de escape y si basta con que escape una persona o debe hacerlo todo el equipo vivo.

- Radar: alcance, consumo, reparación y tipos de señales detectadas.

- Inventario, recetas, materiales, límites de carga y herramientas iniciales.

- Catálogo final de monstruos, señales de peligro, defensas y comportamiento.

- Condiciones y coste de ofrendas; reglas de resurrección y ubicación al revivir.

- Cordura, hambre, clases, botín inicial cronometrado y cinemáticas: ideas previas sin aprobación definitiva.

# Referencia para Blender

Propuesta espacial para construir un kit modular reutilizable

## Distribución del ejemplo visual

Orientación: norte arriba. Propuesta de superficie: 1.000 × 1.000 m; altura máxima aproximada de 120 m. Estas dimensiones son orientativas y requieren pruebas de recorrido y rendimiento en Roblox.

| ID | Zona propuesta | Función |
| --- | --- | --- |
| A | Claro inicial / sur | Entrada del equipo |
| B | Pueblo 1 / suroeste | Descanso y materiales |
| C | Helicóptero / centro-oeste | Radar y orientación |
| D | Pueblo 2 / centro-este | Descanso y materiales |
| E | Pueblo 3 / noroeste | Descanso y materiales |
| F | Salida / noreste | Final de partida |

Conectar A-B-C-D-E-F mediante una red transitable con bifurcaciones y atajos. Un río atraviesa el centro; disponer pasos accesibles para evitar que el agua divida el nivel en áreas incomunicadas. La salida noreste se representa como un paso entre elevaciones; su mecanismo definitivo sigue pendiente.

## Instrucciones para el agente de modelado

Construir terreno, río, senderos, claros, pueblos abandonados y restos del helicóptero como componentes separados. Mantener despejado el suelo jugable; distribuir árboles y follaje en capas para permitir ajustar densidad y visibilidad. Los pueblos deben parecer abandonados sin asociar a sus habitantes con los monstruos.

Usar metros como unidad en Blender y documentar la conversión a studs al importar. Crear colecciones Terrain, Water, Paths, Vegetation, Villages, Helicopter y Exit. Pivotes coherentes, escala aplicada y colisiones simplificadas. Preparar variantes de módulos para evitar repeticiones evidentes.

La imagen es una referencia artística de conjunto: no contiene geometría reconstruible ni cotas fiables. Priorizar estas especificaciones escritas frente a cualquier detalle ambiguo de la imagen. No incluir monstruos ni efectos atmosféricos permanentes en la malla del terreno.

## Primera entrega verificable

Producir primero un blockout con las seis zonas, conexiones transitables y límites de protección de los pueblos. Verificar recorrido completo, acceso a recursos y funcionamiento del radar antes de añadir detalle visual. Mantener separados el kit de Blender y la lógica procedural del juego.
