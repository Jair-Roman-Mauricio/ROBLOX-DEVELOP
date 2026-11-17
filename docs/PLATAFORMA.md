# Plataforma offshore y mar de tormenta (lobby)

Origen: `Descargas/storm-rig/storm_rig` (platform.blend, ocean.blend, legs.json, README). Una
plataforma semisumergible a tamaño real en un mar del Norte en tormenta.

## Plataforma

- `art/blender/plataforma_hornear.py` hace un UV a cada una de las 69 mallas únicas y hornea el
  shader procedural (óxido, sal, zona húmeda, percebes) a color, relieve y oclusión. Sin esto,
  Roblox solo recibe el color base y se ve de plástico.
- Metal: el original deja el metal en 0,15 con rugosidad alta (pintura mate). El horneado
  genera un mapa de metal y rugosidad. El acero limpio queda casi del todo metálico, la
  pintura semimetálica y el óxido sin metal. La rugosidad del metal limpio baja para que
  refleje el cielo, y la oclusión oscurece juntas y rincones. Las lámparas, las marcas y las ventanas
  quedan de color plano.
- En el juego (`Plataforma.importada`):
  - **Escala:** se calcula con la distancia entre los helipuertos East y West (259 m).
    `Config.Lobby.Plataforma.ESCALA` = 0.42 del tamaño real (1 stud = 0,28 m). Así la cubierta
    mide ~225 studs, queda ~45 sobre el mar y cada helipuerto es como el antiguo. A tamaño
    real (1) los helicópteros quedaban demasiado lejos.
  - **Orientación:** sale de los mismos helipuertos (East-West y SE-NE).
  - **Vuelos:** van en los helipuertos West, NE, East y SE. El de la acomodación (Quarters)
    queda libre.
  - **Aparición:** los jugadores aparecen en la cubierta oeste, entre las tiendas y el borde,
    mirando a la torre.
  - **Lámparas:** pasan a Neon; una de cada tres ilumina (`LUCES_MAX`).

## Mar

ocean.blend es una simulación de Blender (oleaje desplazado, espuma, rociones, niebla
volumétrica) que no se puede importar. `src/server/Lobby/Mar.luau` reproduce lo mismo con
herramientas de Roblox:

| ocean.blend | Roblox |
|---|---|
| Superficie con oleaje de 4 m | Agua de terreno (3.072 × 3.072 studs) con `WaterWaveSize` 1 y `WaterWaveSpeed` 22 |
| Agua oscura verde azulada | `Config.Iluminacion.Lobby.Agua` (cada cliente la aplica; en la selva vuelve el agua del río) |
| Plano lejano hasta el horizonte | Planos oscuros fuera del agua de terreno, fundidos por la neblina |
| Espuma alrededor de las patas | Partículas planas sobre el agua en cada pata |
| Rociones del lado del viento | Golpes de gotas y bruma cada 2–5 s en cada pata (viento a 20°) |
| Niebla baja | Partículas grandes y lentas pegadas al agua |
| Cielo de tormenta | Preset `Lobby`: cielo gris, luz fría, neblina densa, nubes de Roblox |

El sonido del lobby pasa a oleaje fuerte ("Waves Long Rolling In Constantly Heavy Surf") y cada
pata suena a olas rompiendo. Quien cae al mar vuelve a la cubierta.

El lobby está en z = 6000, lejos del mapa de la selva, así que `Terreno.limpiar` no borra este agua.

## Pendiente

- Las 16 tiendas y los 5 helipuertos tienen colisión por defecto de Roblox. Comprobar en Play
  que se puede caminar por la cubierta, las alas y las escaleras.
