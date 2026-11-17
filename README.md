# ROBLOX-DEVELOP

Código del juego sincronizado con Roblox Studio mediante [Rojo](https://rojo.space).

- **Git es la fuente de verdad del código** (`src/`).
- **Studio es la fuente de verdad del mundo** (Workspace, mapas, modelos, terreno, Lighting). Rojo no los toca (`$ignoreUnknownInstances`).

## Estructura

| Carpeta | Destino en Studio |
|---|---|
| `src/server` | `ServerScriptService.Server` |
| `src/first` | `ReplicatedFirst.Carga` (pantalla de carga temprana) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared` | `ReplicatedStorage.Shared` |

Convención de archivos (Rojo por defecto): `x.server.luau` = Script, `x.client.luau` = LocalScript, `x.luau` = ModuleScript, `init.*.luau` convierte la carpeta en ese script.

## Uso

1. Instala las herramientas con [Rokit](https://github.com/rojo-rbx/rokit): `rokit install` (versiones fijadas en `rokit.toml`).
2. `rojo serve`
3. En Studio: Plugins → Rojo → **Connect**.

Formato y lint: `stylua src` y `selene src`.

## Probar el juego sin configurar nada

El repo no guarda archivos `.rbxl` (se generan desde el código). Para tener un place jugable:

```bash
rojo build prueba.project.json -o SelvaPrueba.rbxl
```

Abre `SelvaPrueba.rbxl` en Roblox Studio y pulsa **Play**. Ya trae `SelvaProcedural = true`, `Lighting.Technology = Future` y los modelos de `assets/`. Es un place local de prueba: no lo subas al repo ni lo publiques encima del place del equipo.

Si no tienes Rojo: `rokit install` (o `brew install rojo` en macOS).

## Agentes de IA

Cualquier agente que trabaje en este repo debe seguir [`AGENTS.md`](AGENTS.md): leer [`CONTEXT.md`](CONTEXT.md), consultar el baúl de Obsidian *LihFolk Vault V1* y trabajar en ramas que salen de `dev` y vuelven a `dev` por PR.

## Selva procedural y lobby

Apagado por defecto (escribe terreno en tiempo de juego). Para jugarlo: **Workspace → Attributes → `SelvaProcedural` (booleano) = true**, y **Lighting → Technology = Future**. Luego **Play**.

- `src/server/Lobby/`: base de expediciones con 4 helipuertos. Cada uno es un vuelo para hasta 4 jugadores; despega solo tras la cuenta atrás.
- `src/server/Mundo/`: generación por semilla (`Disposicion` → `Terreno` → validación → `Zonas` + `Dispersion`). Cada partida genera una selva distinta con las zonas A–F de `CONTEXT.md`.
- `src/server/Modelos/`: árboles, chozas, malocas, puentes, helicóptero, etc. construidos con partes.
- `src/client/`: iluminación por zona, partículas, efectos animados e interfaz.

## Plataforma marítima, carga inicial y vegetación de Creator Store

El lobby es una plataforma de acero en alta mar, a 6.000 studs del centro de la selva. Conserva los cuatro vuelos y la cuenta atrás. La carga temprana vive en `src/first`; espera el lobby, precarga únicamente sus recursos y espera la primera generación de selva antes de revelar el juego. La preparación de renderizado no garantiza que el motor haya compilado todos los shaders.

La linterna alcanza 120 studs, con haz de 58° y brillo 6. La selva conserva su iluminación casi negra y las luces de los lugares.

Al generar la selva, `CatalogoVegetacion` intenta cargar los tres paquetes autorizados, con un límite conjunto de 15 segundos. Extrae únicamente geometría y elementos visuales, conserva materiales/texturas y descarta scripts, luces y demás comportamiento externo. Clona las plantillas desde ServerStorage, sin reducir la cantidad de plantas.

Si Roblox impide cargar un paquete comunitario, insertarlo una vez desde Toolbox en un **place personal**, desactivar sus scripts y mover el kit a `ServerStorage.VegetacionStore`. No es necesario cambiar permisos de carga de terceros. Los modelos preparados localmente se leen al inicio del siguiente Play. `TipoVegetacion` permite indicar explícitamente `arbol`, `palmera`, `seco`, `helecho`, `arbusto` u `hojaGrande` si un modelo tiene un nombre ambiguo. El atributo va en cada modelo completo, no en la carpeta del paquete.

En Output, `[VegetacionStore]` informa las variantes disponibles por tipo; `Workspace.VariantesCreatorStore` contiene el total. Si no hay plantillas disponibles para una especie, se conserva su versión anterior para no dejar zonas vacías. Una plantilla local con nombre de árbol debe incluir juntas sus hojas y tronco.

Ver `docs/PLATAFORMA-CREATOR-STORE.md` para fuentes, pruebas y límites.
