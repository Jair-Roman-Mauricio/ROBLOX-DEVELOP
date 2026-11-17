# Cámara estable, selva oscura y vegetación

## Qué cambia y por qué

La cámara de exploración conserva primera persona y brazos visibles, pero elimina los giros de respiración, cabeceo, alabeo y zoom automático al caminar. Mantiene FOV 70 y viñeta suave, y restaura el FOV previo al abandonar la selva.

La noche reduce iluminación ambiental y lunar hasta dejar siluetas. Se conservan luces de edificios y antorchas. Cada superviviente recibe una linterna encendida al aterrizar: haz de 44°, alcance de 55 studs; F, Y o botón táctil la alternan. La asignación se hace en servidor antes de anunciar la entrada a la selva.

Se recuperan exactamente las cantidades originales de vegetación (990 árboles, 2090 helechos, 860 arbustos, 530 plantas de hoja grande), las ceibas originales y sus raíces. Los demás árboles reciben troncos segmentados, ramas, raíces, lianas y copas continuas de lóbulos elipsoidales. Cuatro variantes por especie. Las palmeras y helechos usan frondas con foliolos y las hojas grandes tienen curvatura y nervadura geométrica. Todo se construye con primitivas y materiales de Roblox; no se generan ni importan assets nuevos con Blender.

## Notas del baúl consultadas

- Motion Sensitivity and Camera Comfort
- Camera Systems
- Foliage Props and Scatter
- Zone and Biome Art Direction
- Modelling Nuance Start Here
- Spending Triangles Where the Camera Looks
- Modelling to the Roblox Camera and Player Scale
- Critiquing a Model - Paintovers and Iteration
- Organic and Creature Modeling
- Parts Unions and MeshParts
- Materials MaterialVariants and SurfaceAppearance
- Stylised vs Realistic Material Pipelines

La petición explícita del usuario de una selva casi negra prevalece sobre la recomendación de noche legible del baúl. El usuario solicita hacer personalmente la validación visual: no continuar inspeccionando Studio mediante Computer Use.

## Cómo probar en Studio

1. Compilar `rojo build prueba.project.json -o /tmp/SelvaOscuraRevision.rbxl` y abrir ese archivo local, o sincronizar `src/` a un place personal. No probar sobre el place compartido.
2. Play, embarcar en un vuelo, equipar paracaídas y saltar.
3. Al aterrizar, comprobar primera persona y linterna propia encendida. Quieto, no debe haber giro ni balanceo; caminar no cambia el FOV.
4. Apagar con F: el suelo queda casi negro y apenas se distinguen siluetas. Encender: haz limitado al frente, orientable con la mirada. Repetir con mando y táctil.
5. Acercarse a un pueblo: comprobar que las antorchas conservan luz local. La protección y el salto al día siguen siendo sistemas pendientes.
6. Inspeccionar árboles y plantas bajo la linterna; confirmar densidad. Probar con cuatro jugadores, muerte, vuelta al lobby y segunda expedición.
7. Medir FPS, memoria y tiempo de generación en dispositivos objetivo. Esta revisión no certifica rendimiento móvil ni calidad AAA.

## Requiere en Studio

- `Workspace.SelvaProcedural = true` (el proyecto de prueba ya lo incluye).
- `Lighting.Technology = Future` para las sombras del haz (incluido en el proyecto de prueba).
- No necesita reemplazar el mundo, insertar assets externos ni habilitar Mesh/Image APIs.

## Validación y límites

StyLua, Selene y ambos builds Rojo pasan. La primera versión se inspeccionó en un place local; se descartó tras el feedback del usuario. La versión final de modelos, oscuridad y linterna queda pendiente de su prueba visual, según su instrucción. No se afirma que alcance calidad AAA.

Trabajo preparado en rama aislada `feature/camara-vegetacion-nativa`, creada desde la referencia local de dev e incorporando los cinco commits de `feature/relieve-y-rocas` para conservar el mapa actual. Fetch/push/PR bloqueados por falta de resolución DNS de github.com. La carpeta original impide escribir metadatos de Git; las fuentes finales se exportan a su working tree para la prueba, sin cambiar su rama ni crear commits allí. Antes de abrir PR a dev, actualizar la base y volver a validar.
