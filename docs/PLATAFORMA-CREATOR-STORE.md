# Plataforma marítima, Creator Store y carga inicial

## Qué cambia y por qué

El lobby pasa del campamento de selva a una plataforma de acero en alta mar. Conserva los cuatro vuelos, sus plazas y la cuenta atrás. Añade cubierta modular, pasarelas con huecos de acceso en las barandas, helipuertos de chapa, pilotes y arriostramientos, contenedores, sala de operaciones, torre de control acristalada, focos y baliza. El mar es decorativo: planos anclados, sin escribir Terrain ni cambiar el agua del río. El conjunto está centrado en (0, 60, 6000), fuera de la selva y de la cabina de la intro.

La linterna pasa de 55 a 120 studs de alcance; ángulo de 44° a 58°; brillo de 4 a 6. Usa los mismos valores tanto para el foco propio como para la luz que ven los compañeros. Conserva la oscuridad ambiental y las luces locales de lugares.

El generador usa preferentemente los siguientes paquetes, manteniendo las cantidades de vegetación:

| Paquete | Autor | ID | Página |
| --- | --- | --- | --- |
| Forest Pack | Roblox | 6432306802 | https://create.roblox.com/store/asset/6432306802/Forest-Pack |
| Realistic Jungle Foliage | vx0rn | 5678316277 | https://create.roblox.com/store/asset/5678316277/Realistic-Jungle-Foliage |
| Trees / Foliage — Tropical, Jungle, Island | PSY0PZ | 12157426374 | https://create.roblox.com/store/asset/12157426374/Trees-Foliage-Tropical-Jungle-Island |

Se intenta descargar los kits una vez por servidor, en paralelo y con límite conjunto de 15 segundos. Las raíces descargadas nunca se parentan al DataModel. Se copian únicamente BaseParts y las clases visuales permitidas (materiales PBR, mallas, texturas y decals); se descartan scripts, luces, remotes, prompts, sonidos y constraints. Las plantillas se guardan en ServerStorage, se alinean por su base y se clonan con escala/rotación. Solo los troncos reciben colisión simplificada.

La pantalla temprana en `ReplicatedFirst.Carga` muestra las etapas reales: replicación inicial, lobby listo, precarga de recursos de la base, primera generación de selva y breve preparación de renderizado. Bloquea movimiento durante la carga y lo devuelve al terminar; no altera la cámara. La precarga tiene límite de 20 segundos, no espera RequestQueueSize ni intenta descargar todo Workspace. Si un recurso tarda, su descarga sigue en segundo plano.

Roblox no expone una señal de fin de compilación de shaders; tampoco soporta precargar SurfaceAppearance directamente con PreloadAsync. La pantalla reduce la aparición de trabajo inicial visible, pero no garantiza eliminar todo tirón en cualquier dispositivo. La espera de renderizado está limitada a cinco segundos.

## Notas del baúl consultadas

- Creator Store and Toolbox Safety
- Packages and Asset Reuse
- Foliage Props and Scatter
- Water Sky and Atmosphere Art
- Modular Environment Kits
- Case Study - Fast Join and Deferred Loading
- Materials MaterialVariants and SurfaceAppearance (revisión anterior)

La aprobación explícita de usar Creator Store sustituye la convención anterior del proyecto de representar toda la vegetación mediante partes. Se conserva el respaldo procedural si un kit no carga. Se aplica la recomendación de mar decorativo con planos para no llenar miles de studs de vóxeles de agua.

## Cómo probar en Studio

1. Compilar `rojo build prueba.project.json -o /tmp/SelvaPlataformaStore.rbxl` y abrir **ese archivo nuevo** en un place personal. No sincronizar contra el place compartido.
2. Play: comprobar pantalla de carga, progreso por etapas y entrada al lobby con movimiento restaurado. Repetir en un segundo Play con caché caliente.
3. Recorrer las cuatro pasarelas: verificar que los huecos de las barandas permiten llegar a cada helicóptero, que no hay caídas entre cubierta/pasarela/helipuerto y que las cuentas atrás funcionan con 1–4 jugadores.
4. Embarcar y completar la intro. Verificar que la cinemática conserva referencias a Helicoptero, Interior, Puerta, Rotor y RotorCola.
5. En Output, revisar `[VegetacionStore]`: variantes por especie o errores de descarga/permisos. `Workspace.VariantesCreatorStore` informa el total de variantes aceptadas. Un total de cero significa que se está usando la vegetación anterior, no los modelos de la tienda.
6. En la selva, comprobar que los árboles importados mantienen tronco y hojas juntos, materiales y texturas, apoyo en suelo y copas sin colisión. Inspeccionar con linterna, conservando la noche oscura.
7. Comprobar F, Y y botón táctil; comparar alcance de 120 studs, periferia iluminada y luz visible de compañeros. La linterna sigue siendo la única luz personal.
8. Medir tiempo de entrada, FPS/memoria y tirones en los dispositivos objetivo. La validación visual y el playtest quedan a cargo del usuario por petición expresa; no se usa Computer Use para inspeccionarlos.

## Requiere en Studio

- `Workspace.SelvaProcedural = true` y Lighting.Future, incluidos en el proyecto de prueba.
- En lugares sincronizados existentes, mantener `src/first` mapeado como `ReplicatedFirst.Carga`; ambos proyectos Rojo ya lo incluyen.
- Los kits comunitarios pueden estar bloqueados por permisos de carga. En ese caso: insertarlos desde Toolbox en un place personal, desactivar sus scripts y mover el kit completo a `ServerStorage.VegetacionStore`. Volver a Play. No hace falta habilitar carga global de terceros.
- Si los nombres de plantas son ambiguos, colocar `TipoVegetacion` en cada modelo completo: `arbol`, `palmera`, `seco`, `helecho`, `arbusto` u `hojaGrande`.
- Alternativa reproducible: exportar los kits revisados a `assets/VegetacionStore/*.rbxm` o `.rbxmx`, conservando atribución y permisos. No incluir archivos .rbxl en Git.
- No reemplaza ni borra el mundo editado: el nuevo lobby se construye solo durante Play, detrás del flag existente. No se migró el mundo de ningún place compartido.

## Validación y límites

- StyLua, Selene, comprobación de whitespace y ambos builds Rojo.
- 14 casos de clasificación con Luau.
- Prueba con Lune de copia visual: conserva MeshPart/PBR y elimina código anidado, luces y remotes sin modificar el original.
- Prueba con Lune de jerarquías: conserva árboles completos, distingue palmeras y arbustos y excluye colecciones/piedras.
- No se han descargado los kits a disco ni confirmado su carga real: el entorno no resuelve assetdelivery.roblox.com. Los intentos dentro de Roblox se comprueban en Output durante la prueba del usuario.
- Las descargas usan la versión disponible del kit, no una revisión fijada. Antes de publicar, conviene guardar plantillas revisadas para estabilizar el resultado.
- La carpeta original impide escribir metadatos de Git. Trabajo preparado en rama aislada `feature/plataforma-vegetacion`, creada desde la referencia local de dev e incorporando las revisiones anteriores. Las fuentes se exportan al working tree original para probar, sin cambiar su rama ni hacer commits allí.
- Fetch/push y apertura de PR contra dev bloqueados por falta de resolución DNS de github.com. Antes del PR, actualizar base, resolver conflictos y repetir checks. No se realizó merge a dev/main.

## Fuentes técnicas oficiales

- https://create.roblox.com/docs/reference/engine/classes/AssetService
- https://create.roblox.com/docs/reference/engine/classes/InsertService
- https://create.roblox.com/docs/players/loading-screens
- https://create.roblox.com/docs/reference/engine/classes/ContentProvider
- https://create.roblox.com/docs/performance-optimization/improve
