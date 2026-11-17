# Cómo da miedo la serpiente

La serpiente casi no se ve en la oscuridad. El miedo viene de lo que se oye, de lo que cambia
alrededor y de pequeños detalles que no encajan con un animal.

## Principios (investigación)

| Principio | Fuente | Cómo se aplica |
|---|---|---|
| El monstruo que imagina el jugador asusta más que el que se ve | Frictional Games (Amnesia), artículos de diseño de terror | La cabeza va enterrada; la cinemática solo enseña la tierra abriéndose y el lomo |
| Se oye antes de verse | Subnautica (los leviatanes se anuncian con retumbos graves desde lejos); baúl: Genre Playbook - Horror and Story | Infrasonido (retumbo muy grave con ecualizador), temblor, siseos |
| El silencio antes del susto | Desarrolladores de Alan Wake 2; baúl: "Silence is a tool" | Huyen los pájaros y la selva se calla antes del temblor |
| Mostrar las consecuencias, no el cuerpo entero | Guías de diseño de criaturas gigantes | Zanja, cráteres, árboles que revientan |
| Pocos sustos, bien espaciados | Postmortem de Amnesia ("less is more") | Primera aparición con cinemática; luego pasa cada 150–260 s |
| La luz es el control del ritmo | Baúl: Genre Playbook - Horror and Story | La linterna falla cuando está cerca |

## Valle inquietante

Una serpiente da miedo, pero lo que incomoda es que haga cosas que una serpiente no haría:

- **Mira como una persona.** Cuando asoma los ojos gira la cabeza hacia quien la mira y lo sigue.
- **Se mueve mal.** Cada 23 s avanza unos 2 s a 5 fotogramas por segundo, como una animación que
  falla.
- **Suena casi humana.** Muy cerca, bajo el siseo, hay susurros.
- **Parpadea.** Los ojos se apagan un instante cada pocos segundos.

## Valores

Todo está en `Config.Serpiente.Miedo`, `Config.Serpiente.Sonidos` y `Config.Serpiente.Filtro`.
Con "reducir movimiento" activado en Roblox, el temblor de cámara baja al 20 %.

## Fuentes

- https://www.gamedeveloper.com/design/the-enduring-horror-of-monster-encounters-in-saturnalia
- https://medium.com/stories-from-alphr-com/from-silent-hill-to-alien-isolation-what-makes-a-horror-game-scary-4d4cf4d731ab
- https://creatorsoundspro.com/the-essential-sound-design-checklist-for-horror-game-developers
- https://deepwavegame.github.io/news/subnautica-horror-unknown-depth
- https://www.summerengine.com/templates/horror/creature-horror/creature-horror.md
- https://www.usgamer.net/articles/monster-of-the-week-water-lurker-kaernk-amnesia-the-dark-descent-frictional-games-interview
- https://frictionalgames.com/?p=954
