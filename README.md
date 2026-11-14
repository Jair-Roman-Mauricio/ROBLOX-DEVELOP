# ROBLOX-DEVELOP

Código del juego sincronizado con Roblox Studio mediante [Rojo](https://rojo.space).

- **Git es la fuente de verdad del código** (`src/`).
- **Studio es la fuente de verdad del mundo** (Workspace, mapas, modelos, terreno, Lighting). Rojo no los toca (`$ignoreUnknownInstances`).

## Estructura

| Carpeta | Destino en Studio |
|---|---|
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared` | `ReplicatedStorage.Shared` |

Convención de archivos (Rojo por defecto): `x.server.luau` = Script, `x.client.luau` = LocalScript, `x.luau` = ModuleScript, `init.*.luau` convierte la carpeta en ese script.

## Uso

1. Instala las herramientas con [Rokit](https://github.com/rojo-rbx/rokit): `rokit install` (versiones fijadas en `rokit.toml`).
2. `rojo serve`
3. En Studio: Plugins → Rojo → **Connect**.

Formato y lint: `stylua src` y `selene src`.

## Demos

### Selva de terror — `src/server/SelvaTerror.server.luau`

Mapa generado por código para un juego de terror: selva nocturna de 512×512 studs con colinas y pantanos, ~260 árboles (vivos y secos, con raíces y lianas), maleza, troncos caídos, niebla densa, cámara en primera persona con linterna, y pares de ojos rojos que te miran, parpadean y reaparecen acechándote si te acercas.

**Está apagada por defecto** porque borra el terreno y el Baseplate del place. Para probarla:

1. Abre un place nuevo (o una copia) y conéctalo con Rojo.
2. Selecciona **Workspace** → Properties → Attributes → **+** → atributo booleano `DemoSelva` = `true`.
3. Dale **Play**.

Los ajustes (tamaño, cantidad de árboles, ojos, primera persona, semilla, IDs de sonido) están en la tabla `CONFIG` al inicio del script.
