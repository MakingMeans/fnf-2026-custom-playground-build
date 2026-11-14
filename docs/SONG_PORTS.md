# Canciones portadas de otros mods

Las canciones del mundo 1 vienen de mods hechos con otros motores. Se traen **dentro del juego**
(carpetas `assets/`, nunca `mods/`) y se compilan con todo lo demás.

## Cómo se trae una canción

Cada canción (o cada mod, si comparten piezas) tiene su script de importación en `tools/ports/`.
Copia los archivos del mod original con nombres propios de la canción y ajusta las referencias en el
chart y los scripts. Se puede volver a ejecutar cuando se quiera (por ejemplo, si el mod original se
actualiza):

```
python tools/ports/yararara.py [carpeta del mod]
python tools/ports/mario_madness.py [carpeta assets del mod]   (Last Course y Bad Day)
```

Si el mod tenía la lógica de la canción en su código (no en scripts), se reescribe en Haxe como una
clase de escenario en `source/states/stages/` registrada en el `switch (curStage)` de `PlayState`.

Reglas que siguen todas:

| Qué | Dónde | Por qué |
|---|---|---|
| Chart | `assets/base_game/shared/data/<canción>/<canción>-hard.json` | El juego solo tiene la dificultad Hard |
| Scripts de la canción **y sus eventos propios** | `assets/base_game/shared/data/<canción>/*.lua` | En `custom_events/` serían globales: dos canciones con un evento del mismo nombre ("Flash", "Set Cam Zoom"...) se pisarían |
| Personajes | `assets/base_game/shared/characters/<canción>-*.json` + `images/characters/<canción>/` | Nombres únicos: nada de "1", "BF-GF"... |
| Escenario | `assets/base_game/shared/stages/<escenario>.json` (+ `.lua`) e `images/<canción>/` | |
| Audio | `assets/base_game/songs/<canción>/` (`Inst.ogg`, `Voices-Player.ogg`, `Voices-Opponent.ogg`) | |
| Sonidos, música, shaders, vídeos | `sounds/<canción>/`, `music/<canción>/`, `shaders/<canción>-*.frag`, `assets/videos/<canción>/` | Nombres únicos |
| Piezas comunes de un mod | `images/<mod>/`, `music/<mod>/` (p. ej. `mario_madness/`) | Las comparten varias canciones del mismo mod |
| Fuentes | `assets/fonts/` | Son globales: nombres que no choquen |
| Semana | `assets/base_game/shared/weeks/world1.json` | Una semana por mundo; sale en Freeplay, no en el modo historia |
| Listas | `weekList.txt`, `stageList.txt`, `characterList.txt` (en `assets/shared/`) | Las añade el script |

## Probar una canción

- **`play-song.bat <canción>`** (o `tests\test-<canción>.bat`): abre el juego directamente en la
  canción, con tus opciones. Al acabar vas a Freeplay.
- **Prueba automática** (build debug): `powershell -File tools/run_songtest.ps1 -Song <canción>
  -WinShots "3,27,45"`. Juega la canción entera en botplay, sin teclas simuladas, y captura la
  ventana real en esos segundos de canción. Al final muestra el resultado (fallos, vida, rendimiento)
  y los errores que hayan dado los scripts. Por debajo usa
  `FNF2026Playground.exe -song <canción> -test [-shots ...] [-winshots ...] [-noshaders]`.
  - `-shots`: el juego guarda sus propias capturas en `song_shots/`. Ese método no dibuja vídeos
    ni cámaras con filtro de shader (salen en negro) e ignora la transparencia de los sprites con
    shader (el chispazo de nota precargado sale arriba a la izquierda): para ver el escenario, añade
    `-noshaders`.
  - `-winshots`: captura la ventana real (PrintWindow), con vídeos y shaders. Necesita la pantalla
    encendida.
  - Game over: `-Die 40` deja la vida a 0 en el segundo 40 de canción, `-DeathShots "0.5,3,8"`
    captura la ventana en esos segundos desde que se abre el game over y `-DeathConfirm 10` pulsa
    "reintentar" a los 10 s (si ese game over ya lo deja).
  - `-Hit "Bad Poison"`: el bot también pulsa las notas de esos tipos (normalmente deja pasar las
    que no hay que tocar), para ver qué pasa al tocarlas.

## yararara (mundo 1, primer nivel)

Origen: `teto1/mods/YARARARA` (motor Qsych, basado en Psych 1.0.4). El chart y los scripts ya eran
de Psych 1.0, así que funcionan tal cual; solo cambian nombres y rutas.

- Personajes: `yararara-bf-gf` y `yararara-teto-miku` (el dúo estático del principio),
  `yararara-bf`, `yararara-bf2`, `yararara-teto`, `yararara-teto2` y `yararara-gf` (GF invisible,
  sirve de punto de cámara en el modo golpes).
- Escenario `yararara` (`stages/yararara.lua`): panel del principio, puente rojo desde el paso 224 y,
  en el "HITTING Mode", el escenario partido en dos carriles con zombis que llegan por los dos lados.
- Vídeos `yararara/1` (entrada, a pantalla completa), `yararara/2` y `yararara/3` (bajo las flechas).
- Shader `yararara-chrom` (aberración cromática en la cámara del juego).

Diferencias con el mod, todas a propósito:
- **Zombis**: el mod cargaba 15 texturas de 4096x4096 que eran solo 3 imágenes distintas; ahora son 3
  compartidas (de ~1 GB de textura a ~200 MB). Además, los huecos 3, 6, 7 y 8 pedían
  `zombies-N`, pero el archivo se llamaba `zombeis-N` (errata) y en el mod no cargaban: aquí salen.
- `chrom.lua` ya no da error con los shaders desactivados en las opciones.
- Se mantiene a propósito lo que hace el mod: el evento "Zoom Camera" siempre hace el zoom de golpe
  (su condición en Lua es siempre verdadera) y las barras de cine piden una imagen `empty` que no
  existe (aviso en consola, sin efecto).

## Last Course y Bad Day (Mario's Madness V2)

Origen: carpeta `mamami` (Mario's Madness V2, motor Psych 0.4.2 muy modificado). Casi toda la lógica
de sus canciones estaba escrita en su `PlayState.hx` (código fuente en
https://github.com/Dewott2501/Mario-Madness), así que aquí está reescrita en Haxe:

| Archivo | Qué hace |
|---|---|
| `source/states/stages/MarioStage.hx` | Lo común del mod: cámara con puntos fijos por lado y su zoom (más un empujón hacia cada flecha), la cámara `camEst` entre el juego y el HUD, el HUD (fuente `mario2`, tiempo en rojo o verde con botplay, marco `healthBarNEW`, bote de iconos), el rótulo con título y autor, y los eventos `Triggers Universal`, `Show Song`, `Set Cam Zoom`, `Set Cam Pos`, `Camera Zoom Chain` y `Ocultar HUD`. |
| `source/states/stages/TurmoilSweep.hx` | Last Course (escenario `turmoilsweep`). |
| `source/states/stages/SuperBad.hx` | Bad Day (escenario `superbad`). |
| `source/shaders/RippleShader.hx` | La distorsión del veneno de Bad Day (copia del mod). |
| `source/substates/GameOverCustom.hx` | Base para game over propios de un escenario (`GameOverSubstate.custom`). |

Las dos usan las flechas, chispazos, cuenta atrás y calificaciones de Mario's Madness
(`images/mario_madness/` y `"stageUI": "mario_madness"` → `images/mario_madnessUI/`), y 0.023 de vida
por acierto / 0.0475 por fallo, como el mod.

**Tecla de esquivar**: nueva acción `dodge` en Opciones > Controles (ESPACIO por defecto; en mando,
los gatillos L/R). La usan Last Course y la usará chaos.

**Last Course** (`last-course-bf` goomba contra `last-course-turmoil`):
- Sin cuenta atrás ni HUD al principio: fundido desde negro y el HUD aparece en el paso 128.
- 18 ataques de lengua (pasos 384, 448, 512, 576, 672, 768, 784, 800, 880, 960, 1024, 1152, 1312,
  1376, 1440, 1504, 1568 y 1764): tres avisos con sonido y, al tercer pulso, el golpe. Se esquiva con
  la tecla de esquivar (0,4 s de protección y 1 s de espera entre esquives); si pilla, quita 1.2 de
  vida. Con botplay esquiva solo.
- Cada nota de Turmoil quita 0.015 de vida mientras quede al menos 0.4.
- Game over propio: BF cae, se desvanece y reaparece en 7 s; hasta entonces no se puede reintentar.

**Bad Day** (`bad-day-bf` contra `bad-day-mario`, GF `bad-day-gf`):
- Mario entra de un salto con todo a oscuras; el HUD aparece en el paso 140.
- 32 caparazones que quitan 0.25 de vida (0.1 con botplay): no se pueden evitar, como en el mod.
- Setas venenosas que anuncian 64 notas "Bad Poison": no hay que tocarlas; tocarlas cuenta como
  fallo y sube una viñeta morada que distorsiona la pantalla (RippleShader; sin él si los shaders
  están desactivados o con calidad baja).
- Un Mario pixel salta a las flechas y las hunde de un pisotón cada una (pasos 560 a 572; con
  downscroll las sube); se quedan así el resto de la canción. Luego tira la barra de vida, que no
  vuelve hasta el "YAHOO" del paso 1312. Con downscroll la coreografía es otra, como en el mod.
- Game over propio: Mario azul pisotea a BF tres veces, dice una frase (6 posibles) y se va.

Diferencias con el mod, todas a propósito:
- Los desvanecimientos que el mod hacía restando alpha en cada fotograma se calculan por tiempo
  (a 60 FPS, como en el mod), para que no vayan más rápido a 144 FPS.
- La distorsión de Bad Day solo se activa mientras hay veneno (con veneno 0 no movía nada, pero
  costaba lo mismo).
- El rótulo no cambia el título de la ventana del juego.
- El icono de Mario cuando va perdiendo: el mod movía su offset de un lado a otro, pero como
  recolocaba los iconos en cada fotograma no se veía. Aquí tampoco (antes se veía y quedaba encima
  del de BF).
- El último lengüetazo de Last Course llega 0,4 s después de que acabe la música: si la canción ya
  terminó, no quita vida (BF podía morir de camino al mapa).
- Se mantiene a propósito: el evento "Camera Zoom Chain" ignora los valores de zoom que trae (el mod
  siempre usaba 0.015 / 0.03), y "Set Cam Pos" sin valores no hace nada.
