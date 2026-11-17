# La selva del culto a la serpiente

Nueva cara del mapa procedural. Plano aprobado: lienzo «Selva: culto a la serpiente»
(https://claude.ai/artifact/WHiyRfqjQjnvjYWw1oyHAT). Todo se genera en el juego con cada semilla,
detrás de `SelvaProcedural`; no hay piezas armadas a mano ni Blender.

## Historia que cuenta el mapa

Algo viejo se adoraba aquí: una serpiente. Los santuarios marcan los senderos, cada pueblo tenía un
altar para protegerse de ella y el templo, en lo más hondo, es su casa. Los pueblos se abandonaron
con prisa: enseres tirados, puertas rotas, nada vivo.

## Zonas

| Zona | Qué es | Código |
|---|---|---|
| B | Aldea de ladera: el terreno se inclina siguiendo la pendiente natural; chozas con techo hundido, hamacas, cercas podridas, vasijas volcadas, lianas | `Zonas.pueblo`, estilo `ladera` |
| D | Aldea de palafitos junto al lago-pantano: chozas sobre pilotes, pasarelas rotas, alguna choza hundida | estilo `palafitos`, `Aldea.palafito`, `Aldea.pasarela` |
| E | Ruinas: plaza empedrada, pozo, casa de reuniones en ruinas | estilo `ruinas`, `Aldea.pozo`, `Aldea.sala` |
| T | Templo de la Serpiente, unido a la salida F | `Zonas.templo`, `Culto.templo` |

Cada pueblo tiene su altar mirando al centro (`Culto.altar`). El templo tiene siete pisos con musgo,
espirales y grietas, una escalera con barandillas de serpiente, dos serpientes enroscadas y una
cabeza gigante con la boca abierta sobre la losa del altar, con un brasero encendido.

## Agua

Cada lago y arroyo tiene su propio nivel, múltiplo de la celda de 4 studs para que la superficie
quede plana; un bordo en la orilla evita que el agua flote.

- **Río**: el de siempre, con `RAPIDOS` tramos poco profundos con rocas.
- **Lago-pantano**: junto a la aldea de palafitos, fondo de barro, árboles muertos dentro,
  nenúfares y niebla. Si no cabe sin tocar senderos ni zonas, se omite.
- **Lago de la cascada**: en la franja del borde, con una pared de roca detrás; la cascada es una
  lámina escalonada, dos Beams con textura que baja, espuma, niebla y sonido.
- **Arroyos**: nacen en el lago de la cascada (por su orilla más baja) y en la franja del borde, y
  bajan siguiendo la pendiente con un empujón hacia el río. El nivel baja a saltos (pequeños
  rápidos) y nunca sube; el cauce es un barranco en V que no toca los senderos. Si se atasca en un
  hoyo o tendría que cortar un cañón de más de 24 studs, no se excava. Suelen llegar de 1 a 3.
- **Cruces**: un cruce de `TRONCO_MAX` studs o menos se salva con un tronco caído (con una tabla
  invisible para caminar); los más largos con puente.

## Ecotopos nuevos

Además de ribera, claro, ladera y selva (docs/SELVA-ECOTOPOS.md):

| Ecotopo | Dónde | Vegetación |
|---|---|---|
| Pantano | alrededor del lago-pantano | solo árboles secos, poco sotobosque |
| Santuario | alrededor del templo | tupido, árboles extra |
| Borde | franja exterior del mapa | muro tupido que cierra el mapa |

## Detalles (`Mundo/Detalles.luau`)

Escasos a propósito: niebla baja en río, lagos, arroyos y valles; haces de luna en claros y sobre
el pantano; nenúfares; rocas en los rápidos; raíces en orillas y senderos; charcos; arañazos y
mudas de serpiente en troncos cerca de los senderos; rastro de ofrendas en el sendero F–T, más
denso hacia el templo; hongos tenues en troncos caídos como guía.

## Día y noche

`Config.Iluminacion.Dia` es un preset de bruma verde. Se elige con el atributo `SelvaDia` en
`workspace` (o `Config.Mapa.DIA`); la noche sigue siendo la predeterminada.

## Parámetros

Todo en `Config.Mapa`: `Agua` (lagos, cascada, arroyos, rápidos, troncos, sonidos), `Culto`
(santuarios, templo, ofrendas, colores), `Atmosfera` (haces, hongos, arañazos, mudas, niebla,
raíces, charcos), `Vegetacion` (ecotopos nuevos) y `DIA`.

## Pruebas fuera de Studio

Con Lune, cargando los módulos reales: sobre 16 semillas, 15 pasan la validación de ruta (la otra se
descarta y el generador prueba otra semilla, como antes). Partes por pieza:

| Pieza | Partes |
|---|---|
| Santuario | ~106 |
| Altar | ~311 |
| Templo (zona entera) | ~821 |
| Aldea ladera / palafitos / ruinas | ~1094 / ~1329 / ~804 |
| Detalles | ~635 |

Total añadido aproximado: unas 5 600 partes además de la vegetación. Falta medir en Studio
(StreamingEnabled y FPS en móvil).
