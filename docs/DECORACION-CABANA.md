# Estado de la decoración de la cabaña

Fecha: 14 de noviembre de 2026  
Place local revisado: `SelvaPrueba.rbxl` en Roblox Studio.

## Qué se corrigió

Los modelos de `Workspace.DecoracionPabellon` estaban colocados alrededor de `(-108, -47, 44)`, mientras que el lobby y la cabaña de operaciones están alrededor de `Z = 1700`. Por eso no aparecían al jugar.

Se recolocaron los cinco modelos tomando como referencia la cabaña creada por `Lobby.construir`:

| Modelo en Explorer | Posición local respecto al pabellón `(X, Y, Z)` | Giro Y |
|---|---:|---:|
| `BuhoDisecado` | `(0, 4.1, 1.8)` | `0°` |
| `CentroOperaciones` | `(-7.3, 4.8, 5.7)` | `0°` |
| `CabezaAlce` | `(9.5, 4.8, 0.7)` | `90°` |
| `BotellasBebida` | `(-1.7, 4.45, 1.8)` | `0°` |
| `LapicesCuaderno` | `(1.8, 4.12, 1.8)` | `0°` |

Las piezas de estos modelos quedaron ancladas y sin colisión, toque ni consulta física porque son decoración.

## Estado visual y pendientes

- La prueba de Play en Studio confirmó que los modelos ahora aparecen dentro de la cabaña.
- El modelo llamado `BuhoDisecado` muestra una estación de operaciones con monitores. **Los nombres de Explorer no son fiables para identificar la geometría**; comprobar la forma de cada modelo antes de reubicarlo o renombrarlo.
- En la prueba, varias mallas importadas se veían pálidas/blancas. Hace falta revisar la asignación de materiales en una pasada posterior.
- La decoración oscura antigua de la pared continúa en la cabaña. No se retiró para evitar borrar una pieza cuya procedencia no quedó identificada.

## Dónde están los cambios

El mundo se editó en Roblox Studio y se guardó en `SelvaPrueba.rbxl`. Este archivo está excluido por `.gitignore`; el proyecto usa Studio como fuente de verdad para `Workspace` y Rojo no sincroniza esos objetos. Por tanto, **este documento sí viaja en Git, pero los cambios visuales del place no se transfieren con este commit**. Para compartirlos con el equipo hay que llevar esas modificaciones al place de desarrollo mediante Studio y guardar/publicar allí la versión correspondiente.

## Cómo revisar en Studio

1. Abrir la copia local `SelvaPrueba.rbxl`.
2. Iniciar Play y entrar a la cabaña de operaciones del lobby.
3. Confirmar que están el escritorio, las piezas decorativas y que el espacio de paso sigue libre.
4. Revisar materiales y decidir qué decoración antigua debe retirarse en una siguiente pasada.

## Notas del baúl consultadas

- `Git and Source Control for Roblox.md`
- `Team Collaboration Start Here.md`
- `Modeling in Blender for Roblox.md`
- `Command Bar and Studio Scripting.md`
- `Safety Rules for AI Agents in Studio.md`
