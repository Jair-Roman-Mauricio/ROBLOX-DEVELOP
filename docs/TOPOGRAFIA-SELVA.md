# Topografía de la selva baja amazónica y cómo la imita el generador

Investigación hecha para que el terreno de `Mundo/Terreno.luau` se parezca a una selva real y no
a colinas de ruido. Los valores del juego están en `Config.Mapa.Relieve`.

## Cómo es el terreno real

La selva baja no es montañosa: es relieve bajo **ordenado por el agua**. Lo que da la sensación
de altos y bajos es la red de quebradas, no la altura.

| Forma | Cómo es | Fuente |
|---|---|---|
| Llanura inundable | Franja casi plana junto al río, que se inunda cada año | IIAP; SERFOR |
| Restinga | Dique natural: lomo bajo pegado a la orilla, formado por el sedimento de las crecientes | Pisces Conservation |
| Bajial y aguajal | Depresión mal drenada detrás de la restinga; suelo encharcado, palmeras | IIAP; SERFOR |
| Cocha | Laguna en un cauce o meandro abandonado, dentro de la llanura | SERFOR |
| Terrazas | Escalones planos (baja, media, alta) que suben al alejarse del río; las altas ya no se inundan | SERFOR; IIAP |
| Lomadas y colinas bajas | Cimas redondeadas, 20 a 40 m de alto, pendientes de 15 a 25 %; predominan sobre las colinas altas (80 a 300 m) | IIAP; SERFOR |
| Tierra firme disecada | Mesetas, laderas cortas y fondos de valle planos y húmedos. En un área de 18.000 km² al oeste de Manaos: 30 % meseta, 11 % ladera y 58 % fondo de valle | Rennó et al. (HAND) |

Conclusión para el juego: mucho suelo plano o suave (cimas y fondos), laderas cortas y
marcadas entre ambos, y todo conectado por quebradas que bajan hacia el río.

## Cómo lo imita el generador

- **Llanura inundable** (`VALLE_RIO`): cerca del río el relieve se apaga y queda una franja baja.
- **Restinga y bajial** (`RESTINGA`): lomo de 3 studs junto a la orilla y una depresión
  embarrada detrás.
- **Cochas** (`COCHAS`, `COCHA_RADIO`): herraduras con agua en la llanura, abiertas hacia el río,
  lejos de senderos y zonas.
- **Terrazas** (`GRANDE`, `TERRAZAS`, `ESCALON`, `TALUD`): la elevación general sube en escalones.
- **Colinas disecadas** (`COLINAS`, `F_QUEBRADA`, `FONDO`, `LADERA`): una red de quebradas
  (ceros de un ruido fractal) con fondo plano y embarrado, ladera corta y cima redondeada. Son
  lomadas en las terrazas bajas y colinas en las altas.

## Montañas y árboles gigantes (decisión del equipo)

La selva baja real casi no tiene montañas, pero jugando se sentía como un bosque llano. El mapa
mezcla ahora selva baja en los valles con relieve de selva alta:

- **Macizos** (`F_MONTE`, `MONTE_UMBRAL`, `MONTE_BASE`, `MONTE_CUMBRE`): montañas de 150 a 340
  studs con paredes casi verticales y cumbre en meseta con filos.
- **Peñascos** (`PENASCO`): torres de roca sueltas de 50 a 100 studs.
- Solo se levantan lejos de senderos y zonas (`MONTE_CERCA`, `MONTE_LEJOS`): la ruta corre por
  los valles, entre paredes, y nunca tiene que cortar una montaña.
- **Árboles** (`Config.Mapa.Vegetacion.ALTO_*`): el dosel real mide de 30 a 45 m y los emergentes
  de 50 a 60 m. En studs: árboles de 62 a 118, ceibas de 150 a 210.

## Escala

1 stud ≈ 0,28 m. Una colina real de 20 a 40 m serían 70 a 140 studs; el juego usa hasta 40
studs de desnivel por colina para que los senderos sigan siendo caminables. Es una decisión de
jugabilidad, no un dato.

El mapa mide 2.304 studs por lado (unos 645 m), 2,25 veces la superficie anterior. `CONTEXT.md`
propone 1.000 m: queda pendiente de pruebas de rendimiento.

## Lo que no se imita todavía

- Agua corriendo por las quebradas (solo el fondo embarrado).
- Playas de arena en el interior de las curvas del río.
- Zonas de inundación estacional.

## Fuentes

- IIAP, *Folia Amazónica* y documento técnico de Rodríguez (1995): https://repositorio.iiap.gob.pe/bitstream/20.500.12921/235/2/Rodriguez_documentotecnico_1995.pdf
- SERFOR, memoria descriptiva del mapa de ecozonas: https://cdn.www.gob.pe/uploads/document/file/155136/memoria_descriptiva_del_mapa_de_ecozonas_del_inffs.pdf
- Rennó et al. (2008), HAND y ambientes de tierra firme: https://daac.ornl.gov/LBA/lbaconferencia/2008_lba_conf/eng/abstracts/24.1.html
- Pisces Conservation, *Lakes and Floodplain Habitats*: https://amazon.pisces-conservation.com/c40.html
- Baúl: `Noise Functions and Terrain Generation`, `Terrain Tools and Terrain API`, `Infinite and Streamed Worlds`
