# Modelos importados desde Studio (.rbxmx)

Se sincronizan a `ReplicatedStorage.Modelos`. Los scripts que generan los `.glb` están en
`art/blender`; los `.glb` listos para importar, en `art/export`.

| Modelo | Origen | Lo usa |
|---|---|---|
| `HelicopteroAMZ07` | `art/blender/build_helicoptero.py` | `Modelos/Helicoptero` si `Config.HELICOPTERO_MALLAS` |
| `RocaSelva` | `art/blender/optimizar_roca.py` (peñasco de Sketchfab reducido) | `Modelos/Vegetacion` (rocas y peñascos) |

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

## Qué hace el juego mientras tanto

`server/Modelos/Mallas` comprueba al arrancar si las mallas de cada modelo cargan para quien
ejecuta el juego. Si cargan, se usa el modelo; si no, avisa en Output y construye la versión
hecha con partes. Nadie ve objetos invisibles: quien no tiene permiso ve la versión de partes.
`Config.USAR_MALLAS = false` fuerza las partes para todos.

## Añadir un modelo

1. Generar el `.glb` (menos de 20.000 triángulos por malla, texturas de 1024 como máximo).
2. Importarlo en Studio con el importador 3D, con el grupo como *Creator* si existe.
3. Guardarlo como `.rbxmx` en esta carpeta (clic derecho → *Save to File*).
4. Usarlo desde el código con `Mallas.obtener("Nombre")` y dejar siempre una versión de partes.
