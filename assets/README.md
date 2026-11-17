# Modelos importados desde Studio (.rbxmx)

Se sincronizan a `ReplicatedStorage.Modelos`. Los scripts que generan los `.glb` están en
`art/blender`; los `.glb` listos para importar, en `art/export`.

| Modelo | Origen | Lo usa |
|---|---|---|
| `HelicopteroAMZ07` | `art/blender/build_helicoptero.py` | `Modelos/Helicoptero` si `Config.HELICOPTERO_MALLAS` |

Las rocas, los peñascos y las ceibas **ya no usan modelos importados**: son copias hechas con
partes (`server/Modelos/Triangulos` + `server/Modelos/Datos/ModelosSelva`, generado por
`art/blender/modelos_a_partes.py`). Cargan para cualquier cuenta sin permisos.

## Por qué a un compañero no le sale un modelo

El `.rbxmx` del repo **no contiene la geometría**: solo guarda el id del asset de Roblox
(`rbxassetid://…`). La malla y sus texturas viven en la nube de Roblox y tienen dueño: la cuenta
que las importó. Con la privacidad de assets activada, solo cargan para esa cuenta y para las
experiencias o grupos con permiso. A cualquier otra cuenta que abra el place le llega el
MeshPart, pero invisible. Comprobado: los assets del helicóptero responden 403 a quien no es su
dueño.

Git no puede arreglar esto; se arregla en Roblox, de una de estas formas:

1. **Grupo (recomendado por el baúl).** Crear un grupo de Roblox con todo el equipo y, en el
   importador 3D, elegir el grupo como *Creator* al importar. La experiencia también debe ser
   del grupo. Los assets del grupo cargan para sus miembros con permiso de edición.
2. **Un place compartido con Team Create.** Publicar el place, invitar a los compañeros como
   colaboradores y trabajar todos en ese place (el código se sigue sincronizando con Rojo). Al
   insertar un asset propio en la experiencia, Studio pide darle permiso a la experiencia, y
   desde entonces carga para quien la edite o la juegue. No funciona con copias locales `.rbxl`.
3. **Open Use.** En el Creator Hub, abrir cada asset y marcarlo como *Open Use*: carga para
   cualquiera, en cualquier place. Es irreversible, y solo es válido si la licencia del modelo
   lo permite.

## Regla del proyecto

Para rocas y los respaldos procedurales se mantienen versiones con partes. Un modelo 3D externo puede usarse como
referencia: `modelos_a_partes.py` saca de él triángulos de baja resolución con el color de la
textura y el juego los monta con WedgeParts. El helicóptero importado solo se usa si
`Config.HELICOPTERO_MALLAS` es `true`.

## Añadir un modelo

1. Generar el `.glb` (menos de 20.000 triángulos por malla, texturas de 1024 como máximo).
2. Importarlo en Studio con el importador 3D, con el grupo como *Creator* si existe.
3. Guardarlo como `.rbxmx` en esta carpeta (clic derecho → *Save to File*).
4. Dejar siempre una versión de partes: a quien no tenga permiso el modelo le sale invisible.

## Excepción aprobada: vegetación de Creator Store

Los árboles y plantas usan preferentemente sus MeshParts y SurfaceAppearances originales para conservar la calidad visual. Los paquetes aprobados son Forest Pack (Roblox, 6432306802), Realistic Jungle Foliage (vx0rn, 5678316277) y Trees / Foliage — Tropical, Jungle, Island (PSY0PZ, 12157426374).

`CatalogoVegetacion` intenta obtenerlos en ejecución y conserva únicamente sus elementos visuales. También acepta kits guardados como `.rbxm`/`.rbxmx` bajo `assets/VegetacionStore/` (se sincronizan a ReplicatedStorage.Modelos.VegetacionStore), o colocados en `ServerStorage.VegetacionStore` desde Studio. Preferir ServerStorage si no se necesita versionarlos: evita replicar todas las plantillas al entrar.

Los archivos de los kits aún no se han descargado a este repositorio: la red del entorno no resuelve assetdelivery.roblox.com. La descarga desde Roblox durante Play y los permisos de sus dependencias requieren la comprobación del usuario. Conservar atribución y permisos de las mallas/texturas; no re-subir como propios los assets de otros creadores.
