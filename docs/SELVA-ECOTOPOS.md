# Estructura de la vegetación: ecotopos y capas

La selva sigue siendo aleatoria (cambia con la semilla), pero ya no reparte objetos al azar: cada
punto pertenece a un **ecotopo** y la vegetación se siembra **por capas**, cada una apoyada en la
anterior. Código: `src/server/Mundo/Dispersion.luau`. Valores: `Config.Mapa.Vegetacion`.

## De dónde sale

| Idea | Fuente | Cómo se aplica |
|---|---|---|
| Ecotopos: el tipo de entorno decide qué especies crecen y con qué densidad | Horizon Zero Dawn (Guerrilla, GDC 2017): toda la vegetación se coloca por reglas a partir de mapas de entrada | `ecotopo(x, z)` a partir de la distancia al río, la pendiente y los claros |
| Distancia mínima entre árboles, nada de grumos y huecos | Baúl: *Foliage Props and Scatter* (Poisson-disk) | Rejilla `dosel` con espacio por ecotopo (`ESPACIO`) |
| Capas: muros densos en los bordes, interior más abierto, unos pocos árboles protagonistas | Baúl: *Foliage Props and Scatter* | Hitos, dosel, rocas, troncos y sotobosque, en ese orden |
| Estratos de la selva: emergentes, dosel, sotobosque y suelo | Ecología de la selva tropical (Smithsonian STRI, CDU) | Las ceibas son emergentes; los arbustos y helechos crecen al pie de los árboles |
| Claros: un árbol cae, abre el dosel y la vegetación baja invade el hueco por los bordes | Dinámica de claros (investigación en Panamá) | `CLAROS` con un tronco caído en el centro y arbustos en el anillo |
| Efecto borde: donde entra la luz hay más vegetación baja | Ecología de bordes de bosque | Muros de arbustos y helechos junto a senderos y zonas |
| Hitos que se ven desde lejos y guían al jugador; encuadre del camino | Baúl: *Zone and Biome Art Direction*; artículos de diseño de niveles sobre vistas y encuadre | Una ceiba junto a cada zona y cada `HITO_SENDERO` studs; árboles alternos a los lados del sendero (`CORREDOR`) |

## Ecotopos

| Ecotopo | Dónde | Dosel | Suelo |
|---|---|---|---|
| Ribera | a menos de `RIBERA` studs de la orilla | 70 % palmeras, espacio 14 | hojas grandes, rocas de orilla |
| Claro | `CLAROS` círculos lejos de senderos, zonas y río | sin árboles | tronco caído en el centro, arbustos en el borde |
| Ladera | pendiente > `LADERA` | 40 % árboles secos, espacio 30 | peñascos y grupos de rocas |
| Selva | el resto | 80 % árboles, 15 % palmeras, espacio 19 | arbustos y helechos al pie de los árboles |

Las arboledas más y menos tupidas siguen saliendo de un ruido a escala de unos 200 studs.

## Capas

1. **Hitos.** Una ceiba emergente junto a cada zona y otras cada `HITO_SENDERO` studs de sendero,
   a 30–45 studs a un lado, con al menos `HITO_ESPACIO` entre ellas.
2. **Dosel.** Primero un árbol cada `CORREDOR` studs alternando lados del sendero, que lo enmarca;
   luego el resto, según el ecotopo.
3. **Rocas.** Peñascos en laderas. Las pequeñas van en grupos: una central y otras alrededor, a
   7–14 studs.
4. **Troncos.** Uno en el centro de cada claro; los demás junto a árboles en pie.
5. **Sotobosque.**
   - Arbustos: 35 % al pie de los árboles, 30 % en bordes de senderos y zonas, 15 % en el borde
     de los claros y 20 % sueltos.
   - Hojas grandes: 50 % en la ribera, 25 % en los bordes de los senderos y 25 % al pie de los
     árboles.
   - Helechos: 30 % bordeando senderos, 20 % abrazando rocas y troncos, 25 % al pie de los
     árboles y 25 % sueltos.

Las cantidades totales no cambian (`ARBOLES`, `ARBUSTOS`…), así que el rendimiento es el mismo.
Las carpetas de `Selva.Vegetacion` mantienen sus nombres (las usan la serpiente y el acecho).

## Fuentes

- https://www.guerrilla-games.com/read/gpu-based-procedural-placement-in-horizon-zero-dawn
- https://80.lv/articles/real-time-procedural-placement-in-horizon-zero-dawn/
- https://striresearch.si.edu/rainforest/home/canopy/
- https://learnline.cdu.edu.au/units/env509/module3/fundamentals.html
- https://code.tutsplus.com/level-design-views-and-vistas--cms-25036a
- https://worldofleveldesign.com/categories/level_design_tutorials/alan-wake-guide-the-player.php
- Baúl: *06 World Building and Art/Foliage Props and Scatter*, *Zone and Biome Art Direction*,
  *34 Procedural Generation/Noise Functions and Terrain Generation*
