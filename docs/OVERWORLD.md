# Overworld (mapa estilo Super Mario World)

Sustituye al menú principal: al pulsar ENTER en el título entras a un mapa por el que BF camina
de nodo en nodo, igual que Mario en Super Mario World. Cada nodo puede ser un **nivel** (una
canción del juego) o una **entrada a otro mundo** (una semana / sub-mapa).

Los mundos se diseñan con el **Editor de Mundos** incluido en la build y se guardan como JSON en
`assets/shared/overworlds/`.

---

## 1. Cómo abrir el juego y el editor

| Quiero... | Doble clic en |
|---|---|
| Abrir el juego ya compilado | **`play.bat`** |
| Abrir directamente el editor de mundos | **`run-editor.bat`** |
| Abrir directamente un mapa para jugarlo | **`run-world.bat`** |
| Recompilar y abrir | `run.bat` |

Los dos `run-*` aceptan el nombre del mundo. Desde una consola en la raíz del repo:

```
run-editor.bat draft_world     abre el editor con ese mundo cargado
run-world.bat draft_world      entra a jugar ese mapa directamente
```

Por dentro pasan `-overworld-editor` / `-overworld` al ejecutable, que los lee en `Main.hx`.
También puedes llegar al editor desde dentro del juego: en el mapa pulsa **BACK** (ESC) → menú
principal → **7** → *Overworld Editor*.

Los `.bat` usan la build de `export\debug\`; si no existe, la de `export\release\`. Si no hay
ninguna, ejecuta `run.bat` una vez para compilar.

El mundo que abre el título (y con el que arranca el editor si no le pasas otro) es el que dice
`OverworldData.DEFAULT_WORLD`; ahora mismo es **`draft_world`**. Si borras o renombras su `.json`,
el título vuelve a llevar directamente al menú clásico de siempre.

## 2. Controles del editor

| Tecla / ratón | Qué hace |
|---|---|
| **V** | Modo SELECCIONAR: clic para elegir y arrastrar nodos o decorados |
| **N** | Modo NODO: clic en el mapa crea un nodo nuevo |
| **B** | Modo DECORADO: clic coloca el sprite elegido en la pestaña *Decorado* |
| **C** | Modo CAMINO: clic en un nodo y luego en otro para unirlos |
| **T** | Modo PINTAR TILES: pinta con el tile elegido en la paleta (arrastra para pintar seguido) |
| **P** | Mostrar / ocultar la paleta de tiles |
| Clic derecho | Borra lo que haya bajo el ratón |
| SUPR | Borra la selección actual |
| ALT (mantener) | Coloca sin ajustar a la rejilla |
| Rueda del ratón | Zoom |
| Botón central / flechas | Mover la cámara |
| **G** | Mostrar / ocultar la rejilla |
| **CTRL+Z** / **CTRL+Y** | Deshacer / rehacer (también hay botones en la pestaña *Mundo*) |
| **CTRL+S** | Guardar |
| **CTRL+T** | Probar el mundo (BACK dentro del mapa te devuelve al editor) |
| **F1** | Ayuda en pantalla |
| **ESC** | Volver al menú de editores |

En modo CAMINO, con un camino ya seleccionado, cada clic en una zona vacía **añade un punto de
curva**: así se dibujan caminos en L o en zigzag como los de SMW. Los puntitos del camino se
generan solos entre nodo y nodo según la separación configurada (16 px por defecto).

## 3. Tutorial: tu primer mundo desde cero

Vamos a montar un mundo llamado `mundo1` con tres niveles y un castillo final.

### Paso 0 — el fondo

Elige uno de los que ya hay (`overworld/test_world/bg1`, `overworld/selector/world`) o mete el tuyo:

1. Guarda tu `mimapa.png` en `assets/shared/images/overworld/`.
   Si es un spritesheet animado, deja al lado su `mimapa.xml` de Sparrow.
2. Ejecuta **`sync-overworld-art.bat`** para copiarlo a la build ya compilada. Así aparece en los
   desplegables del editor sin tener que recompilar. (Si prefieres recompilar, `run.bat` también lo copia.)

El fondo se dibuja en 0,0 sin escalar: lo que manda el tamaño del mapa es el png. Un fondo tipo SNES
son 256x224 px; con zoom 3 llena bien la pantalla.

### Paso 1 — crear el mundo

1. Abre el editor (ver punto 1 de este documento).
2. Pestaña **Mundo** → botón **Mundo nuevo**. Te deja un mapa vacío con un nodo suelto.
   Los desplegables vienen filtrados por tipo: en *Fondo* solo salen fondos, en *Sprite del
   jugador* solo hojas con animaciones de andar, y en *Sprite* del nodo solo sprites de nodo y
   tilesets. Si necesitas saltarte el filtro, marca **Ver todos los sprites**.
3. **Archivo del mundo**: `mundo1` (sin `.json`, en minúsculas y sin espacios).
4. **Nombre visible**: `Mundo 1`.
5. **Fondo**: un mundo nuevo ya viene con el **mar** (`overworld/backgrounds/sea`, animado).
   Si pones otro y es animado, elige también su **Animación del fondo** y los FPS.
   **Repetir el fondo (mosaico)** lo repite hasta cubrir todo el mapa: con el mar puesto,
   el agua llega hasta donde llegue el mundo por grande que sea.
6. **Zoom**: 3 (súbelo a 4 si tu arte es más pequeño). **Rejilla**: 16.
7. **Musica**: `freakyMenu` u otro nombre de `assets/shared/music/`.

### Paso 2 — colocar los niveles

1. Pulsa **N** (modo nodo) y haz clic donde quieras cada nivel. Cada clic crea un nodo, ajustado a
   la rejilla. Coloca cuatro.
2. Pulsa **V** (modo seleccionar) y haz clic en el primero. Se abre la pestaña **Nodo**:
   - **ID**: `n0` (es el nombre interno; sirve para enlazar desbloqueos).
   - **Tipo**: `level`.
   - **Sprite**: `overworld/big` (el círculo de nivel). **Animación**: `idle`. **FPS**: 6.
   - **Cancion**: la lista trae **todas las canciones de la build** (cualquier carpeta de `data/`
     que tenga un chart). Un nodo nuevo ya viene con el tutorial puesto.
   - **Semana**: **filtra la lista de canciones**. Sin semana salen todas las de la build; al elegir
     una, solo salen las que esa semana declara en su JSON (y si la canción que tenías no es de esa
     semana, se cambia sola a la primera). También marca la carpeta del mod. No toca la dificultad.
   - **Nombre visible**: lo que se lee abajo en el mapa.
   - **Desbloqueado al empezar** viene marcado por defecto. Desmárcalo solo si quieres que
     ese nivel haya que ganárselo.
   - **Desbloquea al completarlo**: `n1`.
3. Repite con `n1` (desbloquea `n2`), `n2` (desbloquea `n3`) y `n3`, que será el castillo:
   sprite `overworld/castle`, **Animación** `idle`, **Anim. completado** `dead`, FPS 0.
4. Vuelve a la pestaña **Mundo** y pon **Nodo inicial**: `n0`.

Arrastrar un nodo con el ratón (en modo V) lo mueve; también puedes teclear X/Y a mano.

### Paso 3 — unir con caminos

1. Pulsa **C** (modo camino).
2. Clic en `n0` y luego en `n1`: se crea el camino y aparecen los puntitos amarillos automáticamente.
3. Para un camino en L (subir y luego girar): con ese camino seleccionado, haz clic en el vacío en
   la esquina por donde quieres que doble. Cada clic añade un punto de curva.
4. Repite para `n1`-`n2` y `n2`-`n3`.

En la pestaña **Camino** puedes cambiar el sprite de los puntitos (`overworld/dot`, `overworld/dotgb`)
y la separación entre ellos.

### Paso 4a — pintar el mapa con tiles

Esta es la forma cómoda de dibujar el terreno, en vez de ir colocando sprites sueltos.

1. Pestaña **Tiles** → elige un **Tileset**. Al abrir el editor ya viene cargado
   `og_mario/overworld_tiles`, que es el del terreno.
2. La paleta aparece a la izquierda. Rueda del ratón sobre ella para pasar tiles (3 filas por
   muesca); **shift + rueda** baja de 15 en 15, que con 2000 tiles hace falta.
3. Clic en un tile para elegirlo (entra automáticamente en modo **T**). Abajo se lee qué tile es y
   en qué posición de la lista está.
4. Clic o **arrastra** por el mapa para pintar. El ajuste es al tamaño del tile, no a la rejilla
   del mundo.
5. Clic derecho borra el tile de debajo. Mientras pintas, el clic derecho **nunca borra un nodo**,
   solo tiles y decorados. **P** oculta la paleta cuando estorbe.

Marca **Pintar por delante de BF** para los tiles que deban taparlo (copas de árbol, puentes...).

Cada tile pintado es un decorado normal: en modo **V** puedes seleccionarlo y cambiarle escala,
alpha o capa.

Tilesets que vienen preparados en `overworld/og_mario/`:

| Tileset | Tamaño | Para qué |
|---|---|---|
| `og_mario/overworld_tiles` | 8x8 (2188) | Terreno al detalle: hierba, agua, bordes, caminos |
| `og_mario/overworld_blocks` | 16x16 (768) | Los mismos trozos en bloques, se pinta 4 veces más rápido |
| `og_mario/level_tiles` | 16x16 (88) | Círculos de nivel, estrellas, tuberías, números |
| `og_mario/level_blocks` | 32x32 (36) | Castillos, fortalezas y casas fantasma enteros |

Sirven igual para los **nodos**: en la pestaña *Nodo*, elige de **Sprite** uno de estos tilesets y
en **Animación** el nombre del tile concreto (`tile0007`, etc.).

### Paso 4 — decorar a mano

1. Pestaña **Decorado** → elige un **Sprite** (por ejemplo `overworld/test_world/path` con la
   animación `path 1`, o `overworld/pipe`, `overworld/star`, `overworld/ring`).
2. Pulsa **B** y haz clic para ir colocándolos. Cada clic pone una copia.
3. Con uno seleccionado (modo **V**) puedes cambiarle escala, alpha, flip y si va **delante** de los
   nodos y de BF o detrás.

Los overlays a pantalla completa (`overworld/overworld_overlay`, `selector/hub_path`) van colocados
en 0,0 y con **Delante** marcado.

### Nodos bloqueados y cómo no liarse

Un nodo **bloqueado se ve igual en el mapa**, como en Super Mario World: lo que aparece al
desbloquearlo es el **camino** de puntitos. Lo que no puedes es caminar hasta él.

Un nodo queda bloqueado si tiene *Desbloqueado al empezar* sin marcar **y** ningún otro nodo lo
lista en *Desbloquea al completarlo*. Si te pasa, BF se queda quieto porque no tiene a dónde ir.
Dos botones en la pestaña **Mundo** para esto:

- **Comprobar mundo**: **simula una partida entera** (sale del nodo inicial, completa todo lo que
  alcanza y aplica los desbloqueos hasta que no se abre nada más) y lista lo que falla:
  - nodos **inalcanzables** aunque completes todo lo demás;
  - nodos sin caminos, bloqueados que nadie desbloquea, niveles sin canción, nodos `world` que
    apuntan a un mapa inexistente;
  - `unlocks` con IDs que no existen (una errata deja ese nodo bloqueado para siempre);
  - desbloqueos puestos en nodos `empty` o `world`: esos nodos **nunca se completan**, así que
    no desbloquean nada. Los desbloqueos van siempre en un `level`;
  - IDs repetidos, caminos repetidos o hacia nodos que no existen, nodo inicial bloqueado.

  También salta solo al guardar. En pantalla caben 4 avisos; la lista completa sale por consola.
  En la build debug, además, cada mundo que se carga escribe sus avisos en la consola.
- **Desbloquear todos**: deja todos los nodos accesibles de una pasada. La reparación rápida.

Al escribir en **Desbloquea al completarlo**, la barra de abajo avisa en rojo si algún ID no
existe. Al cambiar el **ID** de un nodo, el cambio solo se aplica si ese ID está libre: si
coincide con otro nodo (por ejemplo, al pasar por `n1` mientras escribes `n10`), sale un aviso
y el nodo conserva su ID anterior hasta que termines de escribir uno libre.

Recuerda que BF solo se mueve por **caminos**: dos nodos sin un camino que los una son dos islas.
Y no tiene animación de estar parado: la hoja `overworld_bf` no trae ninguna, así que quieto se
queda en el primer fotograma de la dirección a la que mira, igual que Mario.

### Paso 5 — guardar y probar

- **CTRL+S** guarda (te dice abajo en verde las dos rutas donde ha escrito).
- **CTRL+T** lo prueba de verdad: BF aparece en el nodo inicial. BACK te devuelve al editor.
- Dentro del mapa, **R** reinicia el progreso para volver a probar los desbloqueos desde cero.

### Paso 6 — que sea el mapa principal

El juego entra al mundo que nombra `OverworldData.DEFAULT_WORLD` (ahora `draft_world`). Tienes
dos opciones:

- **Que tu mundo sea el principal**: ponle ese nombre de archivo y guárdalo, o cambia la constante
  en `source/backend/OverworldData.hx`.
- **Mantener un selector de mundos** (como el de SMW): deja el mundo principal como mapa selector y
  añádele un nodo de **Tipo `world`** con **Mundo destino** = `mundo1`. Al entrar en ese nodo saltas
  a tu mundo, y BACK te devuelve al selector.

---

## Mundo de pruebas: `test_graph`

Un mundo pequeño para comprobar que el grafo funciona, sin tocar el boceto `draft_world`.
Ábrelo con `run-world.bat test_graph` (o `run-editor.bat test_graph` para verlo en el editor).

```
[T1]───[T2]───[T3]
         │      └──┐       camino en L (con un punto de curva)
      (cruce)      │       cruce = nodo "empty" (punto de paso)
         │       [T5]
       [T4]                callejón sin salida: hay que volver
```

| Nodo | Empieza | Al completarlo desbloquea |
|---|---|---|
| T1 | desbloqueado | T2 |
| T2 | bloqueado | T3, cruce y T4 (bifurcación) |
| T3 | bloqueado | T5 |
| T4, T5 | bloqueados | nada |

Usa las canciones `tutorial1` … `tutorial5` de la semana `test_levels` (oculta en el modo
historia, visible en Freeplay). Son copias del chart del tutorial que conservan
`"song": "Tutorial"` dentro, así que **reutilizan su audio** en vez de duplicarlo; por eso en
la pausa se lee "Tutorial".

En la build debug, la tecla **1** durante una canción la termina al instante y cuenta como
superada: es la forma rápida de probar los desbloqueos.

## Dificultad

Esta build maneja **una sola dificultad global: Hard**. No hay Easy ni Normal en ningún menú, y las
semanas ya no pueden declarar las suyas en el JSON. Cada canción carga su chart `-hard`; si no
tiene, se usa su chart base sin sufijo, así que ninguna canción se queda sin poder abrirse.

Se define en `source/backend/Difficulty.hx` (`defaultList`). Para volver a tener varias, basta con
añadirlas ahí.

## 4. Dónde se guarda

El botón **Guardar** escribe en dos sitios a la vez:

- `export/debug/windows/bin/assets/shared/overworlds/<mundo>.json` — la copia que usa el juego que
  está corriendo.
- `assets/shared/overworlds/<mundo>.json` — la copia del repo, la que se commitea.

Si por lo que sea solo escribe una, ejecuta `sync-overworlds.bat` en la raíz del repo para copiar
de la build al repo. También existe **Guardar como...** para elegir la ruta a mano.

## 5. Formato del JSON

```jsonc
{
  "displayName": "Mundo de pruebas",
  "bg": "overworld/test_world/bg1",   // clave de imagen bajo assets/shared/images/
  "bgAnim": "",                       // prefijo de animación si el fondo es un Sparrow
  "bgFps": 8,
  "music": "freakyMenu",
  "zoom": 3,                          // los assets son pixel art de ~16px, 3-4 va bien
  "gridSize": 16,
  "startNode": "n0",
  "player": "overworld/overworld_bf",
  "walkSpeed": 60,                    // píxeles por segundo

  "nodes": [
    {
      "id": "n0",                     // único dentro del mundo
      "x": 80, "y": 160,              // centro del nodo, en píxeles del mapa
      "type": "level",                // level | world | empty
      "image": "overworld/big",
      "anim": "idle",
      "animDone": "",                 // animación cuando ya está superado
      "fps": 6,
      "name": "Tutorial",
      "song": "tutorial",
      "week": "tutorial",
      "difficulty": "",               // vacío = Normal
      "world": "",                    // solo para type "world"
      "unlocked": true,
      "unlocks": ["n1"]
    }
  ],

  "sprites": [                        // decorados
    { "image": "overworld/selector/hub_path", "anim": "hub path stars", "fps": 8,
      "x": 0, "y": 0, "flipX": false, "flipY": false, "scale": 1, "alpha": 1, "front": false }
  ],

  "paths": [
    { "a": "n0", "b": "n1", "points": [[192, 160]],
      "dots": "overworld/dot", "dotAnim": "idle", "dotSpacing": 16 }
  ]
}
```

## 6. Cómo se juega el mapa

- Flechas / WASD: BF camina al nodo contiguo en esa dirección, siguiendo el camino.
- Un nodo bloqueado no deja pasar (suena el *cancel*). Se desbloquea cuando completas un nodo que
  lo lista en `unlocks`.
- ACCEPT: entra al nivel (o al mundo). Al terminar la canción vuelves al mapa y el nodo queda
  marcado como completado. Si sales por pausa o game over, vuelves al mapa sin completarlo.
- BACK: sube al mapa anterior; en el mapa raíz abre el menú clásico (freeplay, opciones, mods,
  créditos, editores).
- **R**: reinicia el progreso del mundo actual (útil mientras pruebas).

El progreso se guarda en el `FlxG.save` del juego, con la clave `overworldProgress`
(`"<mundo>::<nodo>"`).

## 7. Assets

Todo lo que haya en `assets/shared/images/overworld/` (y sus subcarpetas) aparece automáticamente
en los desplegables del editor: basta con soltar ahí un `.png` y, si está animado, su `.xml` de
Sparrow. Los prefijos de animación se leen del propio XML.

Los assets que ya vienen:

| Archivo | Para qué |
|---|---|
| `overworld_bf`, `dead_overworld_bf` | BF de mapa (walk up/down/left/right, swim, climb, level start) |
| `dot`, `dotgb` | Puntitos de camino |
| `big` | Círculo de nivel |
| `castle` | Castillo (`idle` / `dead`) |
| `pipe`, `pipegray` | Tuberías |
| `star` | Estrella |
| `ring` | Aro de warp (appear / idle / vanish) |
| `smoke_overworld` | Humo |
| `overworld_overlay` | Overlay animado a pantalla completa |
| `selector/world`, `selector/water_hub`, `selector/hub_path` | Mapa selector de mundos |
| `test_world/bg1`, `bg2`, `path` | Mapa de pruebas |

### Convertir una hoja de sprites en un tileset

Las hojas que se descargan de sitios tipo Spriters Resource vienen con un color de fondo y con
separadores de 1 px entre tiles: no valen tal cual. `tools/slice_tileset.py` las convierte en un
atlas limpio (PNG con transparencia + XML de Sparrow) que la paleta del editor lee directamente.

```bash
# hoja de 8x8 con separadores de 1px
python tools/slice_tileset.py "art/overworld_source/mi_hoja.png" mis_tiles ^
    --tile 8 --spacing 1 --out assets/shared/images/overworld/mis_tiles

# lo mismo pero pegando bloques de 2x2 (salen tiles de 16x16 sin costuras)
python tools/slice_tileset.py "art/overworld_source/mi_hoja.png" mis_bloques ^
    --tile 8 --block 2 --spacing 1 --out assets/shared/images/overworld/mis_bloques
```

Quita el fondo, descarta tiles vacíos, elimina duplicados y reempaqueta. Opciones útiles:
`--bg RRGGBB` (forzar el color de fondo), `--crop x,y,w,h`, `--exclude x,y,w,h` (para saltarse
el texto de créditos de la hoja), `--columns N`, `--ground` (guardar un tile de fondo opaco).
`python tools/slice_tileset.py` sin argumentos muestra la ayuda completa.

Las hojas originales van en `art/overworld_source/` (no se compilan al juego); los atlas generados
en `assets/shared/images/overworld/`.

> Los gráficos de *Super Mario World* son de Nintendo. Este repo guarda las hojas que añadas tú en
> `art/overworld_source/`; el sistema es agnóstico del asset, así que funciona igual con tiles
> propios.
