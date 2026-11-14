# AGENTS.md

Instrucciones obligatorias para cualquier agente de IA (Claude Code, Codex, Cursor, Gemini, etc.) que trabaje en este repositorio. Léelas completas antes de tocar código. Si algo de aquí choca con tu comportamiento por defecto, **gana este archivo**.

---

## 0. Antes de empezar (obligatorio, en este orden)

1. **Lee `CONTEXT.md`** (raíz del repo). Es el documento de contexto del juego *Selva / Supervivencia*: visión, reglas confirmadas por el equipo, decisiones abiertas y referencias de mapa.
   - Las secciones "Reglas confirmadas" son requisitos. Todo lo marcado como *propuesta*, *recomendación* o *decisión abierta* **no está aprobado**: no lo implementes como definitivo sin confirmación del usuario.
2. **Localiza el baúl de Obsidian `LihFolk Vault V1`** (ver sección 1). Sin él no se desarrolla.
3. Comprueba en qué rama estás (`git branch --show-current`) y sigue el flujo de la sección 3.

---

## 1. Baúl de Obsidian: fuente de conocimiento obligatoria

El equipo usa el baúl **LihFolk Vault V1** (~950 notas sobre Roblox: Studio, Luau, networking, datos, UI, mundo, rendimiento, anti-exploit, MCP y agentes, Git/Rojo, recetario de Luau…). **Es obligatorio consultarlo antes de diseñar o escribir cualquier sistema.**

### Cómo encontrarlo

No está dentro del repo (cada desarrollador lo tiene en su máquina). Búscalo:

```bash
# macOS / Linux
find ~ -maxdepth 4 -type d -name "LihFolk Vault V1" 2>/dev/null
# Windows (PowerShell)
Get-ChildItem $HOME -Directory -Recurse -Depth 4 -Filter "LihFolk Vault V1" -ErrorAction SilentlyContinue
```

Ubicación habitual en la máquina del líder: `~/LihFolkVault/LihFolk Vault V1/`. Si solo existe el `.zip` (`LihFolk Vault V1 Lite.zip`, normalmente en Descargas), descomprímelo **fuera** de `~/Documents/Roblox` y del repo.

**Si no lo encuentras: detente y pídele al usuario la ruta.** No continúes "de memoria".

### Cómo usarlo

- Antes de cada tarea, busca por tema y lee las notas relevantes:
  ```bash
  grep -ril "<tema>" "<ruta del baúl>" | head
  ```
  Cada carpeta tiene una nota `... Start Here.md`; empieza por ahí.
- Carpetas clave: `01 Studio and Workflow` (Rojo, Git, Team Create), `02 Luau Scripting`, `03 Architecture and Networking`, `04 Data and Persistence`, `09 Gameplay Systems`, `16 MCP and Agents`, `22 Anti-Exploit and Security`, `29 Luau Cookbook`, `34 Procedural Generation`, `50 Team Collaboration and Project Management`.
- Sigue los patrones, reglas y checklists del baúl. Si te apartas de uno, explícalo en la descripción del PR.
- En la descripción de cada PR incluye una sección **"Notas del baúl consultadas"** con los nombres de las notas usadas.
- El baúl es **solo lectura**: no lo modifiques ni lo subas al repo.

---

## 2. Arquitectura del proyecto (Rojo)

| Carpeta | Destino en Studio |
|---|---|
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared` | `ReplicatedStorage.Shared` |

- **Git es la fuente de verdad del código.** Todo script vive en `src/`. No edites scripts directamente en Studio: se perderán en la siguiente sincronización.
- **Studio es la fuente de verdad del mundo** (Workspace, mapas, modelos, terreno, Lighting). `Workspace` usa `$ignoreUnknownInstances: true`: no lo cambies ni mapees carpetas con `$path` sobre contenido construido a mano, porque Rojo **borraría** lo que no esté en disco.
- Convención de archivos: `x.server.luau` = Script, `x.client.luau` = LocalScript, `x.luau` = ModuleScript, `init.*.luau` convierte la carpeta en ese script.
- Todo código en Luau con `--!strict` cuando sea viable. El servidor es autoritativo: nunca confíes en datos del cliente (ver `22 Anti-Exploit and Security`).
- Herramientas fijadas en `rokit.toml`. Antes de abrir un PR: `stylua src` y `selene src` sin errores, y `rojo build -o build.rbxl` debe compilar (no subas el `.rbxl`).
- Código que borre o reemplace contenido del place (terreno, Baseplate, etc.) debe ir **apagado por defecto** detrás de un atributo o flag, como hace `SelvaTerror.server.luau` con `Workspace.DemoSelva`.

---

## 3. Flujo de Git (obligatorio)

### Ramas permanentes

| Rama | Propósito | Quién escribe |
|---|---|---|
| `main` | Versión estable / publicada. | Solo merges desde `dev` aprobados por el usuario. **Nunca** commits directos. |
| `dev` | Integración. Aquí se juntan todas las features. | Solo merges de PR desde ramas de trabajo. **Nunca** commits directos. |

### Ramas de trabajo

Cada feature, arreglo o experimento nuevo va en **su propia rama creada desde `dev` actualizada**, y vuelve a `dev` por Pull Request. **Ningún agente trabaja directamente en `main` ni en `dev`.**

```bash
git checkout dev
git pull origin dev
git checkout -b feature/<nombre-corto>
```

Prefijos de rama (minúsculas, guiones):

| Prefijo | Uso | Ejemplo |
|---|---|---|
| `feature/` | Sistema o funcionalidad nueva | `feature/radar-helicoptero` |
| `fix/` | Corrección de bug | `fix/linterna-no-apaga` |
| `demo/` | Prototipo o prueba de concepto | `demo/selva-terror` |
| `refactor/` | Reorganizar sin cambiar comportamiento | `refactor/modulo-inventario` |
| `docs/` | Documentación | `docs/agents-workflow` |
| `chore/` | Tooling, config, dependencias | `chore/actualizar-rojo` |

### Commits

- Pequeños y enfocados. Mensaje en español, en imperativo: `Agregar generador de grafo de zonas`.
- Cuerpo opcional explicando el *porqué*.
- Nunca subas `.rbxl`/`.rbxlx`, `sourcemap.json`, secretos, claves de Open Cloud ni cookies.

### Pull Requests

- **Base siempre `dev`.** (La única excepción es el PR de release `dev → main`, que solo abre el usuario o un agente con su permiso explícito.)
- Antes de abrir el PR: `git fetch && git rebase origin/dev` (o merge de `dev`), resuelve conflictos y vuelve a compilar.
- La descripción debe incluir:
  1. Qué cambia y por qué.
  2. **Notas del baúl consultadas.**
  3. Cómo probarlo en Studio (pasos, atributos o flags a activar).
  4. **Requiere en Studio:** cambios manuales en el mundo que el código necesite (instancias, nombres, atributos). Si renombras algo que el mundo usa, dilo aquí.
- No hagas merge de tu propio PR sin aprobación del usuario.
- Tras el merge, borra la rama de trabajo.

### Rojo y ramas

Una rama de Git **no** crea una rama del place de Roblox: lo que tengas checkout es lo que `rojo serve` empuja al place conectado.

- Para probar una rama, sincronízala en un **place personal de desarrollo** (copia del place compartido: *File → Save to Roblox As*), no en el place compartido del equipo.
- El place compartido de desarrollo sigue a `dev`.
- No cambies de rama con `rojo serve` conectado a un place compartido.
- `rojo serve` solo en `localhost`.

### Releases

`dev → main` cuando el usuario lo aprueba. Se etiqueta el commit publicado (`v0.1.0`, `v0.2.0`…) y la etiqueta se anota en las notas de publicación del place.

---

## 4. Trabajo con Studio vía MCP

- Si tienes el MCP de Roblox Studio (`list_roblox_studios`, `execute_luau`, etc.), úsalo para **verificar** (playtest, leer la salida, inspeccionar instancias), no como sustituto de escribir código en `src/`.
- Llama primero a `list_roblox_studios` y confirma que el place correcto está abierto; los ids cambian al reiniciar Studio.
- Cualquier edición del mundo vía MCP es real e inmediata para todo el que esté en el place: pide confirmación antes de borrar o reemplazar contenido.
- Más reglas: notas `16 MCP and Agents/Safety Rules for AI Agents in Studio.md` y `Multiple Agents in One Studio.md` del baúl.

---

## 5. Checklist antes de dar una tarea por terminada

- [ ] Leí `CONTEXT.md` y respeté las reglas confirmadas; no implementé como definitivas las decisiones abiertas.
- [ ] Consulté el baúl y anoté las notas usadas.
- [ ] Trabajé en una rama `prefijo/nombre` creada desde `dev`.
- [ ] `stylua`, `selene` y `rojo build` pasan.
- [ ] Probé en Studio (place personal) y describí cómo probarlo.
- [ ] PR abierto contra `dev` con la descripción completa.
