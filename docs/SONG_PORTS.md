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
python tools/ports/sonic_exe.py [carpeta sanic]                (chaos y endless-us; necesita Pillow)
python tools/ports/world_of_chaos.py [carpeta clubpe]          (World of Chaos; necesita Pillow)
```

Si el mod tenía la lógica de la canción en su código (no en scripts), se reescribe en Haxe como una
clase de escenario en `source/states/stages/` registrada en el `switch (curStage)` de `PlayState`.

## Al empezar: rótulo de la canción (sin cuenta atrás)

Ninguna canción tiene ya la cuenta atrás "3, 2, 1, go": ni se ve ni suena. Se conserva su tiempo (los
5 pulsos de entrada y los avisos `onCountdownTick` a escenarios y scripts) y en su lugar sale un
**rótulo con el nombre de la canción** (`source/objects/SongCard.hx`), con el estilo de cada una en
`data/<canción>/songcard.json`: `title`, `subtitle`, `style` (`banner`: franja desde la izquierda;
`circle`: círculo dibujado desde la derecha y título desde la izquierda; `panel`: tarjeta redondeada
que baja desde arriba; `slide`: las pantallas de inicio de Vs Sonic.exe con imágenes a pantalla
completa, `circleImage` por la derecha y `textImage` por la izquierda, con `background` opcional),
`font`, `color`, `accent`, `textColor`, `subtitleColor`, `titleSize`, `delay`, `hold` y `at` (segundo
de canción en que sale). Sin ese archivo sale la franja por defecto con el nombre de la canción. Va en
una cámara propia creada al aparecer, por encima de todo, también de un vídeo que ya esté sonando.
Un escenario también puede crear el rótulo por su cuenta (`new objects.SongCard(...)`) en otro
momento: así lo hace chaos.

| Canción | Rótulo |
|---|---|
| yararara | franja roja de Kasane Teto, en el segundo 1 (sobre el vídeo de entrada) |
| chaos | pantalla de inicio como la de endless pero en amarillo (`slide`, fondo negro), antes de la intro y solo la primera vez: la crea `FleetwayStage`, y la intro de la estatua empieza al fundirse. Las imágenes (`chaos/StartScreen/`) las hace `tools/ports/sonic_exe.py`: el círculo de endless con el tono girado al oro y CHAOS ACT 1 con letras de otras pantallas del mod (C y S de CYCLES, H y A de HAZE, O de TOO SLOW) en el sitio del título de HEDGE |
| world-of-chaos | tarjeta rosa de Doki Doki con `doki.ttf` |
| tutorial (y los niveles de prueba) | franja oscura con raya rosa |
| last-course, bad-day, endless-us | ninguno: ya traen el suyo (evento "Show Song" y pantalla de inicio); sus escenarios ponen `PlayState.songCard = false` |

Reglas que siguen todas:

| Qué | Dónde | Por qué |
|---|---|---|
| Créditos | `docs/CREDITS.md` | Canción, mod, personas y piezas que se usan, para unos créditos |
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

## Menú de pausa propio

Si el mod de una canción traía su pausa, el escenario la pone con `PlayState.pauseMenuFactory`
(`play.pauseMenuFactory = function() return new MiPausa();`); si no, sale la de Psych. Las tres comparten
con la de Psych lo que hacen sus opciones: `PauseSubState.restartSong()`, `openOptions()` y `exitToMenu()`
(al mapa si se vino de él). Lo que ve el jugador va en inglés.

| Pausa | Canciones | Origen |
|---|---|---|
| `substates/WoCPauseSubState.hx` | World of Chaos (`ClubStage`) | `data/scripts/Pausemenu.hx` del mod |
| `substates/MarioPauseSubState.hx` | Last Course, Bad Day (`MarioStage`) | `source/PauseSubState.hx` del repo de Mario's Madness: panel con estática de TV (`shaders/TVStaticShader.hx`), botones de Mario, modo, canción, autor, créditos y descripción (`data/<canción>/desc.txt`), música breakfast 1-3. Sin "Options", como el mod; "Botplay" (su botón *Call Luigi*) solo fuera del mapa. Piezas: `mario_madness.py --pause` |
| `substates/SonicPauseSubState.hx` | chaos, endless-us (`SonicStage`) | Va compilada en el exe del mod: rehecha con sus imágenes (pixel art x3, panel en sierra por la derecha, PAUSE, CONTINUE/RESTART/OPTIONS/EXIT, raya bajo la elegida y el Sonic en miniatura de la canción). Piezas: `sonic_exe.py --pause` |

yararara no tiene pausa propia (su mod no traía ninguna). Capturas: `run_songtest.ps1 -Song <canción> -Pause 30`.

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
  - `-WallShots "1.5,2,3"`: captura la ventana en esos segundos de reloj desde que arranca el juego,
    para lo que pasa antes de que empiece la canción (como la intro de chaos).
  - Game over: `-Die 40` deja la vida a 0 en el segundo 40 de canción (`-Die:'-0.5'`, en plena
    cuenta atrás), `-DeathShots "0.5,3,8"`
    captura la ventana en esos segundos desde que se abre el game over y `-DeathConfirm 10` pulsa
    "reintentar" a los 10 s (si ese game over ya lo deja).
  - `-Hit "Bad Poison"`: el bot también pulsa las notas de esos tipos (normalmente deja pasar las
    que no hay que tocar), para ver qué pasa al tocarlas.
  - `-Skip "emerald"`: el bot deja pasar las notas de esos tipos (p. ej. chaos sin esmeraldas).
  - `-Pause 30`: abre el menu de pausa en el segundo 30, captura la ventana y acaba.
  - Las capturas de ventana salen vacías si la ventana del juego está minimizada.

## yararara (mundo 1, primer nivel)

Origen: `teto1/mods/YARARARA` (motor Qsych, basado en Psych 1.0.4). El chart y los scripts ya eran
de Psych 1.0, así que funcionan tal cual; solo cambian nombres y rutas.

- Personajes: `yararara-bf-gf` y `yararara-teto-miku` (el dúo estático del principio),
  `yararara-bf`, `yararara-bf2`, `yararara-teto`, `yararara-teto2` y `yararara-gf` (GF invisible,
  sirve de punto de cámara en el modo golpes).
- Escenario `yararara` (`stages/yararara.lua`): panel del principio, puente rojo desde el paso 224 y,
  en el "HITTING Mode", el escenario partido en dos carriles con zombis que llegan por los dos lados.
- Vídeos `yararara/1` (entrada, a pantalla completa), `yararara/2` y `yararara/3` (bajo las flechas).
  El de entrada (11,54 s) tiene que acabar cuando Teto empieza a cantar (11,52 s). En el mod lo lanzaba un
  evento en el segundo 0, pero abrir un vídeo 1080p tarda unos 2 s y se veía con Teto ya cantando.
  `intro-sync.hx` (script propio que escribe `yararara.py`, que además quita ese evento del chart) lo abre
  antes de la canción, tapado de negro y sin cuenta atrás, y arranca la canción cuando el vídeo ya avanza:
  acaba unos 0,4 s antes de que cante Teto.
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

Las dos usan las flechas, chispazos y calificaciones de Mario's Madness
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
- **Propio (no es del mod):** cuando el Mario pixel rompe la barra de vida (disparador 14, a los 62,4 s),
  de ella salta una llave (la dorada de la tienda de Gaster de Friday Night Dustin') que cae al pie del
  jarrón de la cómoda, detrás de los personajes. Con un clic encima se recoge (susurro de Gaster) y, si
  se acaba la canción, se gana `world1_key`, que abre el camino a la tienda de Gaster del
  mundo 1 (`SuperBad.spawnKey` / `updateKey`, `OverworldState.songKeys`, que `PlayState.endSong` guarda).
  Al recogerla suena `gaster_shop/key_get`. Una vez ganada (la llave no se gasta) ya no
  vuelve a salir.

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

## chaos y endless-us (Vs Sonic.exe)

Origen: carpeta `sanic` (`Vs Sonic.exe`, un Psych 1.0.4 modificado y compilado). Charts, personajes,
escenarios y scripts van **dentro del exe** como recursos de Haxe; `tools/ports/sonic_exe.py` los
saca de ahí (con el manifiesto `manifest/default.json`) y pasa las imágenes `.webp` a `.png`,
devolviendo el margen a las que el mod había recortado (`image_trims.json`). La fuente `SonicCD.ttf`
se copia de `sanic/assets/fonts/`.

**Personajes de atlas de Animate** (Fleetway, el BF de chaos, Majin y el BF muerto de endless): el
mod los dibuja con flixel-animate, que coloca cada animación respecto al recuadro de todo el timeline
de su símbolo (y escala desde el centro del recuadro del timeline principal); nuestro flxanimate los
dibuja en las coordenadas del símbolo y escala desde (0, 0). Por eso `sonic_exe.py` calcula ese
recuadro como flixel-animate (`AnimateBounds`: todos los fotogramas, sin capas ocultas ni máscaras y
con el margen de los filtros) y guarda en el JSON `offset del mod + esquina del recuadro × escala −
centro principal × (1 − escala)`. Sin eso los personajes salían desplazados y cada animación en un
sitio distinto. Además, `Character` pide el símbolo con su nombre exacto (flxanimate buscaba por
prefijo: la intro de Fleetway, símbolo `1`, podía coger `1idle`). La estatua de Sonic de la intro de
chaos es otro atlas: `FleetwayStage` le suma al offset la esquina del recuadro de `intro` × escala.


Lo que hacía el motor del mod, y sus scripts globales, está en Haxe:

| Archivo | Qué hace |
|---|---|
| `source/states/stages/SonicStage.hx` | Lo común: cámara por puntos (`data/<canción>/cameraSettings.json`: punto de cada lado, punto medio con el evento `cameracenter` y cuánto se asoma hacia cada flecha), eventos `Tween Camera Zoom`, `Tweening Camera`, `Set Character Offset` y `Change Health Damage`, y el daño por nota del rival (HealthStuff.lua). |
| `source/states/stages/objects/SonicHUD.hx` | La barra de vida del mod (customHealthBar.lua): marco de la canción, iconos que botan, "Score \| Misses" y, con botplay, "SUNKY IS PLAYING" en arcoíris. Medidas de `data/<canción>/healthProps.json`. |
| `source/states/stages/objects/SonicLyrics.hx` | Las letras karaoke (evento `Normal Lyrics`): frases de `data/<canción>/lyrics.json` en el idioma del juego. |
| `source/states/stages/objects/SonicSplashes.hx` | Sus splashes (noteSplashGlobal.lua): chispazo corto en cada "sick" y fundas en las notas largas (también las del rival). Sustituyen a los de Psych. |
| `source/states/stages/FleetwayStage.hx` | chaos (escenario `fleetw`) y su game over (`ChaosGameOver`). |
| `source/states/stages/MajinStage.hx` | endless-us (escenario `majin`), su pantalla de inicio y su game over (`MajinGameOver`). |

**chaos** (`chaos-bf` contra `chaos-fleetway`):
- Intro: Sonic clásico pensativo en la fuente, se asusta y cae dentro; la cámara mira al punto medio
  de `cameraSettings.json` (la fuente). Se repite cada vez que se empieza o se reintenta.
- Una ventanita con Fleetway (pasos 464-529 y 1600) y letras en pantalla. La ventanita es una cámara
  "por defecto" más, como en el mod: dentro se ve el escenario, no un fondo negro. Cerrada no se dibuja.
- 7 notas "emerald" opcionales: cada una vuela hacia BF y se enciende abajo, junto a la barra. Con las
  7, BF se vuelve Super y Fleetway cambia sus frases. **Es la salida secreta del nivel en el mapa**
  (modo de salida secreta "canción": `OverworldState.songSecret`).
- Láser ("Eat this!"): se esquiva con la tecla de esquivar en el último segundo; si pilla, BF muere.
- Game over: BF hecho ceniza y Fleetway dice una de sus 12 frases, con subtítulo; la música baja
  mientras habla. Reintentar: destello rojo.

**endless-us** (`endless-us-bf` contra `endless-us-majin`):
- Pantalla de inicio "ENDLESS ACT ∞" la primera vez; al reintentar no hay ni cuenta atrás.
- Sus shaders de cámara (aberración, brillo, blanco y negro, color) con los eventos `bloomFlash`,
  `chromFlash`, `bwFlash` y `colorFlash`; el resto (cuenta "3, 2, 1, Go" a mitad de canción, cambio
  de skin de notas, giros de flechas, modchart suave) sigue en sus Lua, que solo usan funciones de Psych.
- Game over: BF esqueleto rodeado de majins y una cuenta atrás de 10 s. Si llega a 0 sin reintentar,
  BF se convierte en Majin (destello azul, zoom y dos sonidos) y se vuelve al mapa.

Diferencias con el mod, todas a propósito:
- chaos sin las 7 esmeraldas se puede pasar (el mod mataba a BF en el láser después del pulso 252 y
  en el paso 1999) y Fleetway hace lo mismo que con ellas: sus frases con sus animaciones, letras y
  zoom, y el fundido a negro final. Solo se salta su "What?" (pasos 1034-1039: audio, animación y
  letra), que reacciona al Super BF. El mod, sin ellas, cambiaba "again" por "2again", callaba su voz
  en las demás frases (y como nada le devolvía el volumen, se quedaba muda hasta el final) y subía el
  daño por nota. Lo de BF sí depende de las esmeraldas: transformarse y sus animaciones de Super.
  Conseguirlas o no decide la salida del nivel.
- La intro de chaos se ve en cada intento (el mod solo la primera vez).
- En el mod, el game over de endless acababa cerrando la ventana del juego: ahora vuelve al mapa (o a
  Freeplay). Su Majin final sale centrado en pantalla (en el mod su sitio dependía de por dónde iba
  la cámara).
- La frase del game over de chaos suena una vez (el mod la cargaba en bucle).
- Las fundas de las notas largas reinician su tiempo al empezar otra nota larga (por un índice mal
  puesto en el script del mod, podían desaparecer al momento).
- No hay rótulo "BOTPLAY" de Psych en estas dos: el del mod es la puntuación en arcoíris.

## World of Chaos (ClubP Literature, Codename Engine)

Origen: carpeta `clubpe` (mod de Codename Engine). Es el castillo del mundo 1. `tools/ports/world_of_chaos.py`:

- **Chart**: Codename no tiene secciones; pasa a psych_v1 con secciones de 4 pulsos (el cambio a 154 BPM
  va al empezar la sección 26, 39 ms antes que en el mod). Las notas de Monika (rival) y Saori
  (jugadora) mantienen sus tiempos. Los 147 eventos de Codename (los del chart y los de `events.json`)
  se guardan como `WoC <nombre>` con sus parámetros en JSON; `Change Character` pasa al de Psych.
- **Personajes** (`woc-monica-faker`, `woc-monica`, `woc-big-monica`, `woc-saori`, `woc-saori-chibi`):
  del XML de Codename al JSON de Psych con sus cuentas: el x/y del XML es la posición (negado en la
  jugadora), los offsets de cada animación se multiplican por la escala, a la jugadora se le
  intercambian singLEFT y singRIGHT (y sus fallos, no las `-alt`: así lo hacía el Codename del mod;
  intercambiadas, las poses especiales de Saori salían al revés) y se compensa la doble inversión con
  la que Codename la dibuja.
  En `camera_position` va el punto de cámara de Codename (centro del primer fotograma, ±100/150, camx
  y camy del XML y del escenario), que usa el escenario.

Lógica en Haxe:

| Archivo | Qué hace |
|---|---|
| `source/states/stages/ClubStage.hx` | Escenario `club`: fondo en tres fases (pasos 446 y 1786), gotas, panel negro del principio y el final, cámara de Codename (sigue a quien diga `Camera Movement`, se asoma 15 px hacia la flecha y `Camera Position` la fija), zoom y "bops" cada N pulsos, balanceo de la cámara, barras de cine, flash y fundido, velocidad de las notas, animaciones `-alt` y `Play Animation` (LOCK: las notas no la cortan), shaders de color y distorsión, flechas de Saori a la izquierda y más pequeñas (las de Monika no se ven), flechas flotando desde el paso 1500, y la animación quieta mientras dura una nota larga (animFix.hx). |
| `source/states/stages/objects/DokiHUD.hx` | La barra "Doki" con los colores de cada personaje, los iconos sobre ella y los textos Score / Misses / Accuracy de Codename con la fuente `doki.ttf`. Sin barra de tiempo (Codename no tiene). |
| `source/substates/WoCPauseSubState.hx` | Su menú de pausa (seguir, reiniciar, opciones, controles y salir), con su música. Se pone con `PlayState.pauseMenuFactory`. |
| `WoCGameOver` (en `ClubStage.hx`) | Su game over: sin personaje muerto, Saori cayendo en bucle aparece en 9 s con su música; reintentar: sonido "reset" y destello rojo. |

Cuenta atrás y calificaciones del mod con `"stageUI": "woc"` (`images/wocUI/`); las calificaciones
salen en el mundo, como en Codename (nodo `ratings` del escenario).

Diferencias con el mod, todas a propósito:
- Al acabar, la canción vuelve al mapa (o a Freeplay) como las demás; el mod iba al menú principal.
- "Salir" de la pausa y BACK en el game over también vuelven al mapa.
- En downscroll Codename volteaba toda la cámara del HUD; aquí solo se mueven la barra, los iconos y
  los textos arriba.

