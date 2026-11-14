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
