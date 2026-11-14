# Canciones portadas de otros mods

Las canciones del mundo 1 vienen de mods hechos con otros motores. Se traen **dentro del juego**
(carpetas `assets/`, nunca `mods/`) y se compilan con todo lo demás.

## Cómo se trae una canción

Cada canción tiene su script de importación en `tools/ports/<canción>.py`. Copia los archivos del mod
original con nombres propios de la canción y ajusta las referencias en el chart y los scripts. Se
puede volver a ejecutar cuando se quiera (por ejemplo, si el mod original se actualiza):

```
python tools/ports/yararara.py [carpeta del mod]
```

Reglas que siguen todas:

| Qué | Dónde | Por qué |
|---|---|---|
| Chart | `assets/base_game/shared/data/<canción>/<canción>-hard.json` | El juego solo tiene la dificultad Hard |
| Scripts de la canción **y sus eventos propios** | `assets/base_game/shared/data/<canción>/*.lua` | En `custom_events/` serían globales: dos canciones con un evento del mismo nombre ("Flash", "Set Cam Zoom"...) se pisarían |
| Personajes | `assets/base_game/shared/characters/<canción>-*.json` + `images/characters/<canción>/` | Nombres únicos: nada de "1", "BF-GF"... |
| Escenario | `assets/base_game/shared/stages/<escenario>.json` (+ `.lua`) e `images/<canción>/` | |
| Audio | `assets/base_game/songs/<canción>/` (`Inst.ogg`, `Voices-Player.ogg`, `Voices-Opponent.ogg`) | |
| Sonidos, shaders, vídeos | `sounds/<canción>/`, `shaders/<canción>-*.frag`, `assets/videos/<canción>/` | Nombres únicos |
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
