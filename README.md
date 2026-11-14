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
