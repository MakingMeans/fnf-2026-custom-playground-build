# Créditos: qué se ha tomado de dónde

Lista de todo lo que esta build usa de otros mods y juegos, para tenerla a mano al montar unos
créditos. **Cada vez que se porte una canción o se tome algo nuevo de otro mod, se añade aquí**
(canción, mod, personas y qué piezas se usan).

Cómo leerla: lo que va sin marca está escrito en los créditos o archivos del propio mod (se indica
dónde). Lo marcado *(deducido)* no lo dice ningún archivo: es una suposición razonable y hay que
confirmarla antes de ponerla en unos créditos públicos.

Rutas de origen: la carpeta de mods es `C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/` (de
aquí en adelante, `Q/`).

## Resumen por canción

| Canción | Mod de origen | Música | Chart | Más créditos de la canción |
|---|---|---|---|---|
| YARARARA | Paquete *Qsych Engine* (mod YARARARA) | ABM feat. 重音テト (Kasane Teto) | no consta | Evento "Cinematics (With HUD)" de RamenDominoes |
| Last Course | *Friday Night Funkin': Mario's Madness* V2 | FriedFrick ft. Sandi | Cape | Turmoil de ScrubbDubb; sprites de NateTDOM; fondo de VanillaScotch; código de Dewott |
| Bad Day | *Friday Night Funkin': Mario's Madness* V2 | RedTV53 | Senshi_Z | Basada en la serie "Super Bad Mario" de Pastek; sprites de GP y EllisBros; fondo de VanillaScotch; código de Dewott y NateTDOM |
| Chaos | *Vs Sonic.EXE* (restauración del Unofficial Dev Team) | MeDicenKay | no consta | Super Sonic (Fleetway Comics) de SEGA |
| Endless (US) | *Vs Sonic.EXE* (restauración del Unofficial Dev Team) | Tomis13YT y KivFLP | no consta | Majin Sonic de SEGA; evento "Tweening Camera" de Raimbowcore12 |
| World of Chaos | *ClubP Literature* / "FNF Posting Literature" (Team Quetzal) | no consta por canción (*deducido*: Cion_Kion) | no consta (*deducido*: JonaW y/o VisoX) | Shader "Adjust Color" de Rozebud |

## Base del juego

- **Friday Night Funkin'**: The Funkin' Crew (ninjamuffin99, PhantomArcade, kawaisprite, evilsk8r).
- **Psych Engine**: ShadowMario y sus colaboradores (este proyecto es un fork de su código, ver
  `docs/PSYCH_ENGINE_README.md`).
- Librerías: HaxeFlixel, OpenFL, Lime, hxcpp, flxanimate, hxvlc, linc_luajit, hscript-iris y las
  demás de `Project.xml`, cada una con sus autores.

## YARARARA: paquete *Qsych Engine* (`Q/teto1`)

- **Qué es**: un ejecutable "Qsych Engine" (Psych 1.0.4 modificado) con 16 mods; YARARARA es uno
  (`teto1/modsList.txt`). La carpeta `mods/YARARARA/` no trae créditos propios.
- **Música**: "ABM feat. 重音テト" (`assets/shared/data/languages/en_us/text/songMeta.json`). Quién la
  arregló para FNF no consta.
- **Scripts de terceros**: evento "Cinematics (With HUD)" de RamenDominoes ("Please credit if using
  this"), con explicación de sakar (`mods/YARARARA/data/custom_events/`).
- **Equipo Qsych** (`assets/shared/data/languages/en_us/text/credits.txt`; no dice quién hizo qué en
  esta canción):

| Persona | Rol |
|---|---|
| Cwy (吴宇QwQ) | Director |
| Baka | Programador principal |
| Icon-BF | Programación |
| XJ-Akers, woofwolf (瑭狼), Molly (Molly-茉莉), tianyin (耍廢の天音) | Dibujo |
| You ming (Yuyou冥) | Animación |
| Star Fison (StrandedCARP死鱼), Lys_Chestnut (赖氨酸栗子), Qi-Mao-Qi (七猫猫老七) | Música |
| qqqeb | Programación para móvil |
| NLDwD (北屿DwD) | Refactorización del motor |

- **Qué usamos**: chart, audio, los 3 vídeos, el shader `chrom.frag`, personajes y escenario, sus
  scripts y eventos (`tools/ports/yararara.py`).

## Last Course y Bad Day: *Friday Night Funkin': Mario's Madness* V2 (`Q/mamami`)

- **Qué es**: *Friday Night Funkin': Mario's Madness*, versión 2.0.1. El código fuente es
  https://github.com/Dewott2501/Mario-Madness.
- **Last Course** (`assets/data/songData/last-course/desc.txt` y la tabla `autor` de su
  `PlayState.hx`):
  - Música: FriedFrick ft. Sandi.
  - Turmoil: ScrubbDubb (también "Turmoil provided by ScrubbDubb" en `specialThanks.txt`).
  - Sprites: NateTDOM. Fondo: VanillaScotch. Chart: Cape. Código: Dewott.
  - Voces de Turmoil y del BF Goomba: RedTV53 (`creditsTexts/dev27.txt`).
- **Bad Day** (`songData/bad-day/desc.txt` y `PlayState.hx`):
  - Música: RedTV53.
  - Basada en la serie "Super Bad Mario" de Pastek ("Super Bad Mario provided by Pastek").
  - Sprites: GP y EllisBros. Fondo: VanillaScotch. Chart: Senshi_Z. Código: Dewott y NateTDOM.
  - Shader de ondas (`RippleShader`): de https://www.shadertoy.com/view/XtsSzN.
  - Voces del game over: no consta (*deducido*: RedTV53).
- **Equipo principal** (`assets/data/creditsTexts/dev*.txt`):

| Persona | Rol |
|---|---|
| Marco Antonio | Director, artista |
| DewottDev | Programador principal |
| Kenny L | Música |
| Faro | Artista, arte conceptual |
| Scrubb | Artista, dueño de Turmoil |
| EllisBros | Artista, editor del tráiler |
| NateTDOM | Artista, animador, charter, programación |
| GP | Jefe de pixel art, diseño |
| VanillaScotch | Fondos y su animación |
| lunarcleint | Programación |
| atpx8 | Programación, casi todos los shaders |
| Cape | Charter, programación |
| Sandi | Música, arte conceptual |
| FriedFrick | Música |
| RedTV53 | Música, voces |
| Senshi_Z | Charter |
| Ironik | Música de los menús |

- **Qué usamos de las canciones**: charts (convertidos), audio, personajes, escenarios, HUD,
  flechas, chispazos, game over, fuentes `mariones.ttf` y `mario2.ttf` (del repo del mod) y la lógica
  de su `PlayState.hx` reescrita en Haxe (`tools/ports/mario_madness.py`, `MarioStage`, `TurmoilSweep`,
  `SuperBad`).
- **Qué usamos de su mapa (overworld)**:
  - El diseño del mundo 1 se basa en la isla del mundo 1 de Mario's Madness
    (`assets/images/warpzone/1/bg1.png`). Columnas, rocas, matorrales y rocas del mar están
    recortados de ella; los peces son su `warpzone/1/bg2`.
  - Sprites de BF en el mapa, punto de los caminos, castillo, estrella, tubería, humo y anillo
    (`assets/images/warpzone/`).
  - La música del mapa del mundo 1 (`music/warpzone/1.ogg`).
  - Los sonidos del mapa: `wz_move`, `smw_boom`, `gotolevel`, `wrong`, `cancelMenu`,
    `enter_the_pipe` y `smw_feather_get`.
  - Los sonidos del Freeplay: `scrollMenu` y `FREEPLAY_START`.
  - El código de su mapa (`WarpState.hx`) solo se estudió; el nuestro es propio.
- **Autoría del mapa**: ningún texto la atribuye.
  - Pixel art: *deducido*, GP. Hizo "most of the pixel art in the mod", y una animación del BF del
    mapa se llama "gp was here".
  - Código: *deducido*, DewottDev.
  - Autor de la música del mapa: no consta.
  - Los sonidos `smw_*` son efectos de Super Mario World (Nintendo).

## Chaos y Endless (US): *Vs Sonic.EXE* (`Q/sanic`)

- **Qué es**: restauración de *Vs Sonic.EXE* por el "Unofficial Dev Team". El mod original lo creó
  RightBurstUltra. Los créditos están en `assets/exe/extras/credits/credits.json` y en el
  `credits.txt` que va dentro del ejecutable.
- **Líderes**:
  - Treno_Arts: director principal.
  - MeDicenKay y Kiv.FLP: directores.
  - DuduGD20: jefe de programación.
  - MeDicenKay: jefe de música.
  - PolloRostizado: jefe de charts.
- **Chaos** (`contents/FLEETWAY/data/chaos/credits.json`, dentro del exe):
  - Música: MeDicenKay.
  - Super Sonic (Fleetway Comics): SEGA y Fleetway Comics.
  - Voz de Fleetway: en el equipo original la puso Jacaris. Si esta versión reutiliza esa voz, no
    consta.
- **Endless (US)** (`contents/MAJIN/data/endless-us/credits.json`):
  - Música: Tomis13YT (Tomis Turbando) y KivFLP.
  - Majin Sonic: SEGA (su ficha dice "Masoto Nishimura", *deducido*: Masato Nishimura, el artista
    de Sonic CD).
  - Evento "Tweening Camera": Raimbowcore12.
  - Voz de Majin: en el equipo original la puso MarStarBro. Si esta versión la usa, no consta.
- **Resto del equipo**:
  - Programación: KrazyKazu, Raimbowcore12, Remagets, AssmanBruh, Wolfie, Snorby…
  - Arte: Hyperdream, CM_drawe, Tomasero, Sebas1554…
  - Pixel art: RoxasWhite_ (jefe).
  - Música: Tomis Turbando, DaRealT0bi, LifeyTheRay, Alex_Hamud…
- **Qué usamos**:
  - Charts, audio, personajes (atlas), escenarios, HUD, letras, splashes, skins de notas, sonidos y
    game over de las dos canciones.
  - La fuente `SonicCD.ttf` y su lógica, reescrita en Haxe (`tools/ports/sonic_exe.py`,
    `SonicStage`, `FleetwayStage`, `MajinStage`).
  - La pantalla de inicio de endless y, montada a partir de sus pantallas de inicio, la de chaos.

## World of Chaos: *ClubP Literature* (`Q/clubpe`)

- **Qué es**: *ClubP Literature* 0.5 de MateoDark (`data/config/modpack.ini`), con el logo "FNF
  Posting Literature", de Team Quetzal, en Codename Engine. Es una parodia de Club PE y Doki Doki
  Literature Club, con Monika y Saori.
- **Créditos del menú** (`data/states/Club_Credits.hx`; no dicen quién hizo qué en esta canción):

| Persona | Rol |
|---|---|
| Mateo_Udark | Director, artista |
| Cion_Kion | Música |
| JonaW | Charter |
| VisoX | Charter, creador de cromáticas |
| Kaonik | Actor de voz |
| SanFord | Programador |

- **Shader**: "Adjust Color" (`shaders/adjustColor.frag`), escrito por Rozebud
  (https://github.com/ThatRozebudDude) a partir del de Andrey-Postelzhuk.
- **Qué usamos**:
  - Chart (convertido), audio, 5 personajes, 3 fondos, los shaders `adjustColor` y `distortion`, el
    HUD, la pausa y el game over.
  - La fuente `doki.ttf` y su lógica, reescrita en Haxe (`tools/ports/world_of_chaos.py`,
    `ClubStage`).
  - Doki Doki Literature Club es de Team Salvato.

## Super Mario World (Nintendo)

- El concepto del mapa (overworld), los tiles de SMW (`art/overworld_source/`,
  `images/overworld/og_mario/`), el mar del mundo 1 y los niveles amarillos y rojos son de Super
  Mario World, de Nintendo.
- La hoja `smw_overworld_tiles.png` la recortó **Zanzio** ("Ripped by Zanzio. Credit would be
  nice", escrito en la propia hoja).
- Como referencia de diseño (no está en el juego) se usó el mapa completo de SMW de Rick N. Bruns
  (vgmaps.com / snesmaps.com).

## Pendiente de confirmar

- Charters de YARARARA, Chaos, Endless (US) y World of Chaos.
- Quién arregló YARARARA para FNF.
- Las voces del game over de Bad Day.
- Los autores del arte y de la música del mapa de Mario's Madness.
- Por canción en World of Chaos: música, chart, voces y arte.
