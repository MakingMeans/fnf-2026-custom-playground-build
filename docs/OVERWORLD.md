# Overworld (mapa estilo Super Mario World)

Es el modo historia: título → menú principal → **Story Mode** abre un mapa por el que BF camina
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
| Jugar el mapa de pruebas `test_graph` | **`tests\test-world.bat`** |
| Abrir `test_graph` en el editor | **`tests\test-editor.bat`** |
| Recompilar y abrir | `run.bat` |

Los dos `run-*` aceptan el nombre del mundo. Desde una consola en la raíz del repo:

```
run-editor.bat test_subworld     abre el editor con ese mundo cargado
run-world.bat test_subworld      entra a jugar ese mapa directamente
```

Para probar una transición sin recorrer el mapa, llama al ejecutable con `-from`: entra en el
mundo como si BF llegara desde otro por una salida.

```
export\debug\windows\bin\FNF2026Playground.exe -overworld test_world2 -from test_graph
```

Por dentro pasan `-overworld-editor` / `-overworld` al ejecutable, que los lee en `Main.hx`.
También puedes llegar al editor desde dentro del juego: en el mapa pulsa **BACK** (ESC) → menú
principal → **7** → *Overworld Editor*.

Los `.bat` usan la build de `export\debug\`; si no existe, la de `export\release\`. Si no hay
ninguna, ejecuta `run.bat` una vez para compilar.

El mundo que abre **Story Mode** (y con el que arranca el editor si no le pasas otro) es el que
dice `OverworldData.DEFAULT_WORLD`; ahora mismo es **`world1`**. Recién abierto el juego, BF sale del
nodo inicial de ese mundo; si sales del mapa con ESC y vuelves a Story Mode, sigues en el mismo
mapa y nodo. Si borras o renombras su `.json`, Story Mode lleva al menú de semanas de siempre.

## 2. Controles del editor

| Tecla / ratón | Qué hace |
|---|---|
| **V** | Modo SELECCIONAR: clic para elegir y arrastrar nodos o decorados. **SHIFT+clic** suma o quita del grupo; **arrastrar en el vacío** dibuja un rectángulo que selecciona lo de dentro (con SHIFT, lo añade) |
| **N** | Modo NODO: clic en el mapa crea un nodo nuevo |
| **B** | Modo DECORADO: clic coloca el sprite elegido en la pestaña *Decorado* |
| **C** | Modo CAMINO: clic en un nodo y luego en otro para unirlos. Si no están alineados, el camino sale **en L** (con SHIFT en el segundo clic, primero en vertical) |
| **T** | Modo PINTAR TILES: pinta con el tile elegido en la paleta (arrastra para pintar seguido) |
| **L** | Modo ENLAZAR: clic en el nodo que desbloquea y luego en cada nodo (o camino) que abre; SHIFT+clic = con su salida secreta (ver abajo). L otra vez vuelve a SELECCIONAR |
| **CTRL+clic** en el mapa (modo T) | **Cuentagotas**: el tile pintado de debajo pasa a ser el del pincel, con su tileset (la paleta cambia sola) y su capa (por delante o por detrás de BF) |
| **P** | Mostrar / ocultar la paleta de tiles |
| **F2** / **SHIFT+F2** | Bloquear / ocultar la capa **GRAFO** (nodos, caminos, puntos de curva y flechas) |
| **F3** / **SHIFT+F3** | Bloquear / ocultar la capa **TILES** (los tiles sueltos pintados con la paleta: el terreno) |
| **F4** / **SHIFT+F4** | Bloquear / ocultar la capa **DECORADOS** (decorados con su imagen y piezas) |
| **CTRL+G** / **CTRL+SHIFT+G** | Unir lo elegido en una **pieza** / separarla (ver abajo) |
| **ALT+clic** | Elige un solo trozo de una pieza (con ALT, el clic derecho borra solo ese trozo) |
| Clic derecho | Borra lo que haya bajo el ratón (en modo L solo cancela; sobre un punto de curva, borra ese punto) |
| Arrastrar un punto de curva | Lo mueve (modos V y C) |
| **E** | Ir al siguiente aviso: selecciona su nodo y centra la cámara en él |
| SUPR | Borra la selección actual (o el grupo entero, en un solo paso de deshacer) |
| **Barra Mover / Copiar / Borrar** | Sale encima de lo elegido (en modo V): *Mover* lo engancha al ratón, *Copiar* lo copia y pasa a pegar, *Borrar* lo borra. Con 2 o más decorados elegidos añade *Unir pieza*, y con una pieza elegida, *Separar* |
| **CTRL+C** / **CTRL+X** / **CTRL+V** | Copiar / cortar / pegar lo elegido o el grupo (tiles, decorados y nodos con los caminos entre ellos). Al pegar, la copia sigue al ratón ajustada a la rejilla y **cada clic deja una**; ESC o clic derecho terminan. Lo copiado se puede pegar en otro mundo |
| **M** | Mover lo elegido con el ratón: sigue al cursor; clic lo suelta, ESC o clic derecho lo devuelven a su sitio. Mueve de verdad (los nodos conservan su ID y su progreso) |
| **CTRL+flechas** | Mover lo elegido una casilla de la rejilla (con SHIFT, un píxel). Varios toques seguidos se deshacen de una vez |
| **CTRL+D** | Duplica la selección o el grupo un poco más abajo a la derecha. Los nodos copiados llevan IDs nuevos, y los caminos y desbloqueos entre ellos apuntan a las copias |
| ALT (mantener) | Coloca sin ajustar a la rejilla |
| Rueda del ratón | Zoom |
| Botón central / flechas | Mover la cámara |
| **G** | Mostrar / ocultar la rejilla |
| **U** | Mostrar / ocultar las flechas de desbloqueo: rosas (lo que abre al completarlo), amarillas (lo que abre su salida secreta) y naranjas (de un nodo a la mitad del camino que abre) |
| **CTRL+Z** / **CTRL+Y** | Deshacer / rehacer (también CTRL+SHIFT+Z, y hay botones en la pestaña *Mundo*). Funcionan aunque estés escribiendo en un campo |
| **CTRL+S** | Guardar |
| **CTRL+T** | Probar el mundo (BACK dentro del mapa te devuelve al editor) |
| **CTRL+SHIFT+T** | Probar **desde el nodo elegido**, aunque con tu partida todavía esté cerrado (también el botón *Probar desde aquí* de la pestaña Nodo y *Probar desde el nodo* de la pestaña Mundo) |
| **F1** | Ayuda en pantalla |
| **ESC** | Soltar el grupo; si no hay, salir del modo actual (vuelve a SELECCIONAR). En SELECCIONAR, volver al menú de editores; con cambios sin guardar avisa y hay que pulsarlo otra vez |

**Capas** (pestaña *Capas*, o F2 / F3 / F4): el mapa tiene tres capas.
- **GRAFO**: nodos, caminos, puntos de curva y flechas.
- **TILES**: los tiles sueltos pintados con la paleta (el terreno).
- **DECORADOS**: los decorados con su propia imagen (columnas, rocas, castillos...) y las piezas,
  aunque estén hechas de tiles.

Una capa **bloqueada** no se toca con el ratón: no se elige, ni se arrastra, ni se crea, ni se borra
nada de ella (tampoco con el rectángulo ni con el clic derecho; SUPR y CTRL+D avisan). Si hay algo de
una capa bloqueada encima, el clic coge lo que haya debajo. Una capa **oculta** no se ve y tampoco se
toca. Usos típicos:
- pintar sin mover ni borrar un nodo o un camino sin querer: bloquea el **GRAFO**;
- mover decorados sin arrancar la hierba: bloquea los **TILES**. Además, así el rectángulo de
  selección se puede empezar encima del terreno (normalmente solo empieza en un sitio vacío);
- mover nodos sin llevarse nada del dibujo: bloquea **TILES** y **DECORADOS**.

Al ocultar el GRAFO sigue viéndose el rectángulo de lo que se ve en el juego. Las capas no se
guardan con el mundo y arriba se indica si alguna está bloqueada u oculta.

**Piezas**: varios decorados o tiles que van juntos, como una montaña pintada con tiles de SMW.
Elige sus trozos (SHIFT+clic o un rectángulo) y pulsa **CTRL+G** (o *Unir pieza* en la barra, o
*Unir en pieza* en la pestaña Deco). Desde entonces:
- un clic en cualquier trozo elige la pieza **entera**; arrastrarla, *Mover*, *Copiar*, *Borrar*,
  CTRL+flechas y CTRL+D la tratan como una sola cosa;
- el rectángulo que toca parte de una pieza la coge entera (con ALT, solo lo de dentro);
- el clic derecho fuera del modo T la borra entera (la goma del modo T borra solo el tile);
- **ALT+clic** elige un solo trozo, para retocarlo o sacarlo;
- repintar uno de sus tiles en el modo T lo deja dentro de la pieza;
- al copiarla o pegarla, la copia es otra pieza (moverla no arrastra a la original).

**CTRL+SHIFT+G** (o *Separar*) la deshace: sus trozos vuelven a ir sueltos. Una pieza se guarda en el
JSON con el campo `piece` de cada decorado (`"piece": "pieza1"`); el juego no lo usa.

El **rectángulo blanco discontinuo** ("LO QUE SE VE EN EL JUEGO") marca hasta dónde puede llegar
la cámara del juego con el zoom del mundo. Lo que quede fuera no se ve nunca: ahí van las salidas
que se van de la pantalla. Las **flechas rosas discontinuas** van de cada nodo a los que
desbloquea, un poco apartadas del camino para no taparlo.

En modo CAMINO, con un camino ya seleccionado, cada clic en una zona vacía **añade un punto de
curva**: así se dibujan caminos en L o en zigzag como los de SMW. Los puntitos del camino se
generan solos entre nodo y nodo según la separación configurada (16 px por defecto).

Los **puntos de curva** se pueden **arrastrar** (en modo V o C) y **borrar uno a uno** con clic
derecho. Al mover un nodo, el punto de curva pegado a él lo sigue si estaba alineado en vertical u
horizontal, así una L sigue siendo una L.

**Deshacer** (CTRL+Z) cubre todo lo que cambia el mundo, también lo que se escribe o se elige en
las pestañas: un renombrado o una lista de desbloqueos se deshace de una vez, no letra a letra, y
varios clics seguidos en un mismo contador cuentan como un paso. Con un campo de texto activo,
CTRL+Z / CTRL+Y salen del campo y deshacen en el mundo. Al deshacer se mantiene seleccionado lo que
tenías elegido. Además:

- Deshacer el **borrado de un nodo** le devuelve su progreso de la partida (y el de su salida secreta).
- Con miles de tiles pintados, deshacer un trazo solo quita y pone esos tiles: ya no rehace el mapa entero.
- Si deshaces **Crear submundo** y guardas, el submundo que ya no usa nadie se borra (solo si nadie
  lo ha tocado desde que se creó). Si vuelves a pulsar *Crear submundo*, se reutiliza su nombre.

**Grupos**: SHIFT+clic o un rectángulo en modo V. Arrastrar cualquier cosa del grupo mueve todo
(también las curvas de los caminos que van de un nodo del grupo a otro), **SUPR** lo borra y
**CTRL+D** lo duplica. Las cajas azules marcan el grupo; la amarilla es el elegido, el que
muestran las pestañas. **ESC** suelta el grupo.

**Cambiar de mundo** (cargar otro, *Mundo nuevo* o *Ir al destino*) empieza un historial nuevo. Si
hay cambios sin guardar, la primera vez solo avisa: repite la acción para descartarlos. *Mundo
nuevo* le pone un nombre de archivo libre (`mundo_nuevo`, `mundo_nuevo2`...). Y **guardar con el
nombre de otro mundo que ya existe** avisa la primera vez: hay que guardar otra vez para
sobrescribirlo (antes lo machacaba sin decir nada, en la build y en el repo).

### Unir mundos desde el editor

En la pestaña **Nodo**, junto a *Borrar nodo*, salen dos botones según el nodo elegido:

| Nodo | Botón | Qué hace |
|---|---|---|
| `world` sin *Mundo destino* | **Crear submundo** | Crea el archivo `<este mundo>_<id del nodo>` con los ajustes de este mundo, un primer nivel con el aspecto de tus niveles y su **salida invisible fuera de la pantalla** ya unida a él. Lo pone de destino del nodo. |
| `exit` o `warp` con destino, sin pareja allí | **Crear pareja** | En el otro mundo, junto a su nodo inicial, pone la salida de vuelta (invisible, fuera de pantalla, abierta) o la tubería de vuelta (con el mismo sprite, bloqueada: se abre por su pareja), unida con un camino. |
| `world`, `exit` o `warp` con destino (o una salida sin destino dentro de un submundo) | **Ir al destino** | Abre ese mundo en el editor y selecciona el nodo por el que se vuelve aquí. Desde ahí, *Ir al destino* te devuelve. |

*Crear submundo* y *Crear pareja* **guardan también este mundo**: el otro necesita verlo en disco
(una salida sin destino busca a su mapa de fuera; un warp, a su pareja). Las etiquetas de estos
nodos muestran a dónde llevan (`sub` / `> test_subworld`).

### Aspecto de un nodo: la paleta de aspectos (A)

La forma fácil: elige el nodo (V) y pulsa **A** (o el botón *Elegir aspecto (A)* de la pestaña Nodo, o
*(aspectos de nodo)* en el desplegable de tilesets). La paleta de la izquierda enseña los aspectos con su
nombre; **un clic** en uno se lo pone al nodo con su animación, su aspecto al superarlo y sus FPS (CTRL+Z
lo deshace) y los nodos nuevos salen con él. Esa paleta no pinta. Hay: niveles grandes y medianos
(amarillo, rojo), el blanco, niveles en tierra, el punto de Mario's Madness, casa de Yoshi, casa fantasma,
casa, castillos (el de MM, el de SMW, fortaleza, castillo de jefe y el de Bowser), los 4 interruptores
(pulsados al superarlos), estrellas, tuberías (verde, gris, SMW), puerta azul, el vacío de Game Boy, el
candado e *Invisible*. La lista está en `NODE_LOOKS` (OverworldEditorState); los de SMW los recorta
`tools/build_node_sprites.py` de `og_mario/level_tiles` y `level_blocks`, cada uno en su atlas de
`overworld/nodes/`.

**Sobre cuáles se pone BF de pie** (se centran bajo él y suben 3 px): tuberías, castillos, fortalezas,
casas, interruptores, estrellas y puertas (lo dice el nombre de la imagen).

### Aspecto de un nodo desde un tile cualquiera de la paleta

Con un nodo elegido, **CTRL+clic en un tile de la paleta** se lo pone como aspecto, y
**CTRL+SHIFT+clic** como aspecto al completarlo (tiene que ser del mismo tileset). Es la forma de
usar un tile concreto, como el círculo amarillo de `level_tiles` y su versión roja: el desplegable
de *Animación* solo ofrece prefijos. Los nodos nuevos salen con el último tile elegido. Un clic
normal en la paleta sigue siendo elegir tile para pintar.

### Modo ENLAZAR (L): desbloqueos con el ratón

1. Pulsa **L**. Se muestran las flechas rosas aunque las tuvieras ocultas.
2. Clic en el nodo que desbloquea (tiene que ser un `level` o un `world`: los demás nunca se
   completan).
3. Clic en cada nodo que debe abrir al completarlo. Cada clic **alterna** el enlace: si ya lo
   desbloqueaba, se quita.
4. Clic en el mismo nodo, en el vacío o clic derecho para terminar con ese nodo (sigues en el
   modo, listo para enlazar desde otro).
5. Para salir del modo: **L** otra vez, **V** o **ESC**.

Enlazar **bloquea al destino** (si empezaba abierto, el desbloqueo no haría nada), y quitar su
último enlace lo vuelve a dejar abierto (salvo que se abra por otra vía: un warp con pareja o un
nodo de "N superados"). El nodo inicial no se puede enlazar como destino: tiene que empezar
abierto. Es lo mismo que escribir los IDs en *Desbloquea al completarlo*, pero sin erratas.

- **SHIFT+clic** en un nodo: lo abre la **salida secreta** del nodo de origen (tiene que ser un nivel).
- **Clic en un camino**: ese camino **solo se abre al completar** el nodo de origen (un atajo entre
  dos nodos que ya estaban abiertos). Con **SHIFT**, con su salida secreta. Otro clic igual lo quita.

### Reglas de apertura avanzadas

Además de *Desbloqueado al empezar* y *Desbloquea al completarlo*, hay tres reglas más:

| Regla | Dónde se pone | Qué hace |
|---|---|---|
| **N superados** | Pestaña Nodo, contador *N superados* | El nodo también se abre en cuanto tienes N nodos superados **en este mundo** (niveles y castillos). Al intentar ir hacia él antes de tiempo, el mapa dice cuántos llevas. |
| **Camino con condición propia** | Pestaña Camino (*Solo se abre al completar*), o modo L + clic en el camino | El camino no aparece hasta completar ese nodo, aunque sus dos extremos ya estén abiertos. Sirve para atajos. En el editor se ve **discontinuo** (naranja; amarillo si es de salida secreta). |
| **Salida secreta** | Pestaña Nodo: *Salida secreta* (`fallos`, `precision` o `cancion`), el contador de al lado (*Max fallos / % min*) y *Su salida secreta desbloquea*; o modo L + SHIFT+clic | Al superar el nivel cumpliendo la condición que tú pones (como mucho N fallos, o al menos ese % de precisión), además se abre lo de su salida secreta. Con `cancion` la condición la pone la propia canción (chaos: reunir las 7 esmeraldas; su escenario pone `OverworldState.songSecret`). Puede sacarse repitiendo el nivel. En *practice* o *botplay* no cuenta. |

En el juego, un nivel con salida secreta muestra `?` junto a su nombre hasta que la sacas, y
después **SECRETO** en amarillo; al volver de la canción sale "¡Salida secreta!", y a la derecha
de la barra se lee `Secretos: X/Y` del mundo. En el editor, su etiqueta lleva un `*` y la de un
nodo de N superados, `(N sup.)`.

### Avisos sobre el mapa

Los nodos con algún aviso de *Comprobar mundo* se ven con un **contorno rojo**, y arriba se lee
cuántos avisos hay. Se recalculan solos un momento después de cada cambio. **E** salta al
siguiente: selecciona su nodo, centra la cámara y muestra el aviso abajo.

## 3. Tutorial: tu primer mundo desde cero

Vamos a montar un mundo llamado `mundo1` con tres niveles y un castillo final.

### Paso 0 — el fondo

Elige uno de los que ya hay (`overworld/test_world/bg1`, `overworld/selector/world`) o mete el tuyo:

1. Guarda tu `mimapa.png` en `assets/shared/images/overworld/`.
   Si es un spritesheet animado, deja al lado su `mimapa.xml` de Sparrow.
2. Ejecuta **`sync-overworld-art.bat`** para copiarlo a la build ya compilada. Así aparece en los
   desplegables del editor sin tener que recompilar. (Si prefieres recompilar, `run.bat` también lo copia.)

El fondo se dibuja en 0,0 sin escalar: lo que manda el tamaño del mapa es el png. Un fondo tipo SNES
son 256x224 px; con zoom 3 llena bien la pantalla. Con **Repetir el fondo (mosaico)** el mapa mide lo
que ocupan los nodos y los decorados (cada decorado con su tamaño real), redondeado a fondos
enteros: un mapa de tiles pintado hasta el borde de 3x2 fondos de mar mide justo eso.

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
   el agua llega hasta donde llegue el mundo por grande que sea. En el juego se repite sin fin,
   así que también llena los lados de la pantalla cuando el mapa es más pequeño que ella.
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
   - **Desbloquea al completarlo**: `n1`. Más cómodo: pulsa **L**, clic en `n0` y clic en `n1`
     (ver *Modo ENLAZAR* arriba).
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
y la separación entre ellos, y además:

- **Carretera**: el camino se dibuja como los de Mario's Madness y SMW, y **se pone solo según lo que
  tiene debajo** (el color de los tiles sueltos del terreno, `OverworldTerrain`):
  - sobre suelo (hierba, arena...): franja beis de 8 px, recortada a la hierba (no se sale por el
    borde), con una plataforma redonda en cada nodo;
  - sobre un acantilado (el marrón "color piel" de los riscos): una **escalera**, y BF trepa;
  - sobre el agua o el aire: puntitos blancos si el camino es *nadando*, y un **puente** si es
    *andando*.
  Al abrirse crece trozo a trozo. En el editor se ve igual que en el juego. Un mapa sin tiles sueltos
  (solo decorados con su imagen) hace como antes: franja donde hay algo pintado y puntitos donde no.
- **BF lo recorre**: *andando* (anda, y trepa solo donde hay escalera); *nadando* (nada en el agua y
  anda en tierra; parado en un nodo en el agua, flota); o *trepando siempre* (trepa en todo el camino,
  para caminos de puntitos).
- **Dibujo de la carretera**: *de SMW* (lo de arriba) o *arcoíris* (la Star Road de Mario's Madness:
  franjas roja, amarilla, verde y cian con su sombra, por encima de todo).

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

Pintar encima de otro **tile pintado** lo sustituye; un decorado puesto a mano (un castillo con
**B**) no se borra por pintar en su casilla. Pintar, borrar y mover decorados no rehace el resto
del mapa, así que va fluido aunque tengas miles de tiles.

Marca **Pintar por delante de BF** para los tiles que deban taparlo (copas de árbol, puentes...).

**Decorados enteros** (la biblioteca): en el desplegable *Tileset* también salen los atlas de la carpeta
`overworld/props/` (y `overworld/world1/props`). Con uno de ellos la paleta muestra **objetos completos**
(colinas, árboles, rocas, columnas, castillos...): elige uno y cada clic en el mapa (modo T) lo pone
entero, centrado en el ratón y ajustado a la rejilla; mientras, se ve en semitransparente donde caería.
Van a la capa DECORADOS: luego un clic (V) los elige enteros para moverlos, copiarlos o borrarlos. El
cuentagotas (CTRL+clic) también coge un decorado entero y cambia a su paleta. Los atlas los genera
`tools/build_props.py` a partir de la hoja de SMW (sus 6 paletas) y de los mapas de Mario's Madness.

Cada tile pintado es un decorado normal: en modo **V** puedes seleccionarlo y cambiarle escala,
alpha o capa.

Tilesets que vienen preparados en `overworld/og_mario/`:

| Tileset | Tamaño | Para qué |
|---|---|---|
| `og_mario/overworld_tiles` | 8x8 (2188) | Terreno al detalle: hierba, agua, bordes, caminos |
| `og_mario/overworld_blocks` | 16x16 (768) | Los mismos trozos en bloques, se pinta 4 veces más rápido |
| `og_mario/level_tiles` | 16x16 (88) | Círculos de nivel, estrellas, tuberías, números |
| `og_mario/level_blocks` | 32x32 (36) | Castillos, fortalezas y casas fantasma enteros |

Sirven igual para los **nodos**: con el nodo elegido, CTRL+clic en el tile de la paleta
(CTRL+SHIFT+clic para su aspecto al completarlo). Ver *Aspecto de un nodo desde la paleta*.

### Paso 4 — decorar a mano

1. Pestaña **Decorado** → elige un **Sprite** (por ejemplo `overworld/test_world/path` con la
   animación `path 1`, o `overworld/pipe`, `overworld/star`, `overworld/ring`).
2. Pulsa **B** y haz clic para ir colocándolos. Cada clic pone una copia.
3. Con uno seleccionado (modo **V**) puedes cambiarle escala, alpha, flip y si va **delante** de los
   nodos y de BF o detrás (casilla *Delante de BF* de la pestaña Deco; al pintar tiles, *Pintar por
   delante de BF* de la pestaña Tiles). **Manteniendo F** se ve en azul todo lo que va delante de BF;
   lo demás va detrás.

Los overlays a pantalla completa (`overworld/overworld_overlay`, `selector/hub_path`) van colocados
en 0,0 y con **Delante** marcado.

### Nodos bloqueados y cómo no liarse

Un nodo **bloqueado se ve igual en el mapa**, como en Super Mario World: lo que aparece al
desbloquearlo es el **camino** de puntitos. Lo que no puedes es caminar hasta él.

Un nodo queda bloqueado si tiene *Desbloqueado al empezar* sin marcar **y** ningún otro nodo lo
lista en *Desbloquea al completarlo*. Si te pasa, BF se queda quieto porque no tiene a dónde ir.
Dos botones en la pestaña **Mundo** para esto:

- **Comprobar mundo**: hace **dos simulaciones** y lista lo que falla.
  - **Este mundo**: BF sale de cada sitio por el que puede aparecer en él (el nodo inicial, las
    salidas por las que se llega de lado y las tuberías con pareja), completa todo lo que alcanza
    y aplica los desbloqueos hasta que no se abre nada más. Un castillo solo cuenta como superado
    si **todo lo de dentro** se puede superar.
  - **La partida entera**: lo mismo, pero empezando en el mundo por defecto y pasando de un
    mundo a otro como en el juego (castillos, salidas, tuberías). Encuentra los bloqueos **entre
    mundos**, que mirando cada mundo por separado parecen correctos. Por ejemplo, un mundo al que
    solo se llega por una tubería que abre ese mismo mundo.

  Lo que avisa:
  - nodos **inalcanzables** aunque completes todo lo demás, y nodos a los que **jugando desde el
    principio** no se llega nunca (lo que los abre está en otro mundo al que no se llega antes);
  - un mundo al que **no se llega** desde el mundo por defecto (normal mientras lo construyes:
    enlázalo con un castillo, una salida o un warp);
  - nodos sin caminos, bloqueados que nadie desbloquea, niveles sin canción, nodos `world` que
    apuntan a un mapa inexistente o a este mismo mapa;
  - `unlocks` con IDs que no existen (una errata deja ese nodo bloqueado para siempre);
  - desbloqueos puestos en nodos `empty`: un punto de paso **nunca se completa**, así que no
    desbloquea nada. Los desbloqueos van en un `level` o en un `world`;
  - castillos (`world`) que no se pueden superar: su mundo no tiene nada que superar, o tiene
    algo inalcanzable dentro;
  - nodos de "N superados" que piden más de los que hay en el mundo, salidas secretas puestas en
    algo que no es un nivel o hacia IDs que no existen, y caminos que abre un nodo que no existe o
    que nunca se completa;
  - submundos sin ningún nodo `exit` (BF no podría salir), y salidas sin destino en un mundo al
    que no lleva ningún castillo (no sabrían a dónde volver);
  - un mundo al que se entra desde castillos de **varios mapas** (al superarlo se completan todos);
  - una salida con destino que se puede pisar **antes** de que se abra su salida de vuelta (BF
    llegaría al nodo inicial del otro mundo);
  - warps sin pareja, dos warps emparejados que no se abren nunca, dos warps (o dos salidas con
    destino) hacia el mismo mundo, y un nodo `world` que hace bucle con su propio submundo;
  - IDs repetidos, caminos repetidos o hacia nodos que no existen, nodo inicial bloqueado o que
    es una salida.

  También salta solo al guardar. **Los avisos nunca impiden guardar**: si los hay, el mensaje
  dice *GUARDADO. Avisos para revisar* en naranja (el mundo ya está guardado). En pantalla caben
  4 avisos; la lista completa sale por consola. En la build debug, además, cada mundo que se carga
  escribe sus avisos en la consola.

  **Pendientes** (no son avisos): un warp o una salida hacia un mundo que **todavía no existe**
  (p. ej. la estrella del mundo 1 hacia `world2`). Es normal mientras ese mundo está por hacer, y
  en el juego dicen "este mundo todavía no existe". No llevan contorno rojo; salen aparte, como
  *Pendiente (no es un fallo)*, al guardar y al comprobar el mundo. Un warp **sin** mundo destino
  sí es un aviso.
- **Desbloquear todos**: deja todos los nodos accesibles de una pasada. La reparación rápida.

Al escribir en **Desbloquea al completarlo**, la barra de abajo avisa en rojo si algún ID no
existe. Al cambiar el **ID** de un nodo, el cambio solo se aplica si ese ID está libre: si
coincide con otro nodo (por ejemplo, al pasar por `n1` mientras escribes `n10`), sale un aviso
y el nodo conserva su ID anterior hasta que termines de escribir uno libre.

Recuerda que BF solo se mueve por **caminos**: dos nodos sin un camino que los una son dos islas.
Parado en un nodo, BF **mira a cámara y camina en el sitio** (la animación de andar hacia abajo
en bucle), como Mario en el mapa de SMW.

### Paso 5 — guardar y probar

- **CTRL+S** guarda (te dice abajo en verde las dos rutas donde ha escrito).
- **CTRL+T** lo prueba de verdad: BF aparece en el nodo inicial. BACK te devuelve al editor.
- Dentro del mapa, **R dos veces** reinicia el progreso para volver a probar los desbloqueos
  desde cero.

### Paso 6 — que sea el mapa principal

El juego entra al mundo que nombra `OverworldData.DEFAULT_WORLD` (ahora `world1`). Tienes
dos opciones:

- **Que tu mundo sea el principal**: ponle ese nombre de archivo y guárdalo, o cambia la constante
  en `source/backend/OverworldData.hx`.
- **Mantener un selector de mundos** (como el de SMW): deja el mundo principal como mapa selector y
  añádele un nodo de **Tipo `world`** con **Mundo destino** = `mundo1`. Al entrar en ese nodo saltas
  a tu mundo.

### Salidas y transiciones: nodos `exit`

**ESC no saca de un mapa**: abre el menú principal, y al volver a Story Mode vuelves al mismo mapa
y nodo. Para irse de un mapa hay que **llegar andando a un nodo de tipo `exit`**. Lo que pasa al
alcanzarlo depende de su **Mundo destino**:

- **Sin destino** (salida de submundo): vuelve al mapa de fuera, encima del nodo `world` por el
  que se entró.
- **Con destino** (transición): pasa a ese mundo **de lado**. Funciona en cualquier mapa, sea un
  submundo o no. Allí BF aparece en la salida que apunta **de vuelta** a este mundo y **entra
  andando** por su camino hasta el primer nodo. Si el otro mundo no tiene salida de vuelta, BF
  aparece en su nodo inicial (*Comprobar mundo* lo avisa).

  Ejemplo: en `mundo1`, una salida con destino `mundo2` en el borde derecho; en `mundo2`, otra
  con destino `mundo1` en el borde izquierdo. Andando por el borde se pasa de uno a otro, como
  si fueran un solo mapa.

Hay dos maneras de colocar una salida (valen para los dos casos):

- **Camino que se va de la pantalla** (la de por defecto): al cambiar un nodo a `exit`, se queda
  **sin sprite**, invisible en el juego (en el editor se ve como un cuadro magenta). Colócalo
  **fuera de lo que se ve** del mapa y únelo con un camino: BF se va andando por los puntitos
  hasta perderse de vista. Las salidas no cuentan para el tamaño del mapa, así que la cámara no
  las sigue.
- **Salida visible**: ponle un sprite (por ejemplo `overworld/pipe`) y colócala dentro del mapa,
  como un tubo.

Una salida puede empezar bloqueada y abrirse al superar un nivel, como cualquier nodo.
*Comprobar mundo* avisa si un submundo no tiene ninguna salida (BF se quedaría encerrado).

Un nodo `world` **cuenta como superado cuando está superado todo lo de su mundo**: sus niveles y,
si tiene, sus propios nodos `world` (las salidas no cuentan). Así funciona como el castillo de
una zona de SMW: le pones en *Desbloquea al completarlo* lo que debe abrirse en el mapa de fuera,
y al salir del submundo tras superar su último nivel, ese camino aparece con la misma animación
de puntitos. Lo que el castillo desbloquea **cuenta ya en cuanto el submundo está superado**,
aunque salgas de él por un warp en vez de volver andando (así la tubería del mundo central se abre
igual); la animación del camino sale la próxima vez que pises el mapa de fuera.

**Para volver de un submundo usa siempre una salida `exit`.** Un nodo `world` dentro del submundo
que apunte al mapa de fuera te lleva de vuelta a él (no te mete "otra vez dentro"), pero
*Comprobar mundo* lo avisa: el mapa de fuera parecería hijo de su propio submundo.

### Puertas con llave y tiendas: nodos `door` y `shop`

- **`door`**: un paso cerrado. Se le pone en **Llave** la llave que lo abre (p. ej.
  `world1_key`) y en *Desbloquea al completarlo* lo que hay detrás. Mientras no se tenga la llave, BF
  llega hasta ella pero no pasa (ENTER: "hace falta una llave"). La llave se gana en una canción (la de
  Bad Day la esconde en la cómoda) y se guarda en un inventario de toda la partida
  (`OverworldData.giveKey`, `FlxG.save.data.overworldKeys`). Al volver al mapa con ella, la puerta se
  "completa" sola: se ve abierta (`animDone`) y lo que abre se revela como al superar un nivel. No
  cuenta en *Superados* ni para dar un mundo por superado. Aspecto por defecto: `overworld/key_door`
  (`closed` / `open`). Si la imagen tiene además fotogramas `unlock0000`..., la puerta recién abierta
  sale cerrada y los reproduce una vez (con el primer "boom" del revelado, o tras el iris si no hay
  nada que revelar) antes de quedarse en `animDone`. (El mundo 1 ya no tiene puerta: ver abajo.)
- **Cualquier otro nodo con Llave** (campo **Llave** de la pestaña Nodo): sigue cerrado, y sus caminos
  ocultos, hasta tener la llave, diga lo que diga *Desbloqueado al empezar* o quien lo desbloquee
  (`OverworldData.isKeyed`). Al volver al mapa con ella se apunta en la partida como `"mundo::nodo#key"`
  (`OverworldState.syncKeyNodes`, una sola vez) y sus caminos se revelan como al superar un nivel. Su
  sprite solo pasa a `animDone` cuando, además de la llave, ya se ve algún camino hasta él (si el mundo
  está reiniciado y aún no se llega, sigue con su aspecto cerrado); ese momento hace la animación `unlock`
  (si la imagen la tiene) justo cuando el camino que se revela llega al nodo. La simulación y los avisos
  dan por hecho que la llave se consigue.
- **`shop`**: una tienda, con ENTER. Se le pone en **Tienda** cuál abre: lo que dice Gaster está
  en `data/gaster_shop/<tienda>.json` (`first` la primera vez, `return` las siguientes). La tienda es
  la de Gaster de Friday Night Dustin' (`states/GasterShopState.hx`); al salir se vuelve al mismo
  nodo. Aspecto por defecto: `overworld/gb_void` (abajo).

**La tienda de Gaster del mundo 1** (plan del usuario, 16/11/2026): no hay puerta. La tienda (`tienda`) es un
nodo con la llave `world1_key` (la de Bad Day): sin ella es un nodo normal pero blanco y su camino desde
Bad Day (a la derecha, arriba y a la derecha, como lo dibujó el usuario) no se ve; con ella, al volver al
mapa crece el camino y, al llegar, el vacío del nivel corrupto de Game Boy de Mario's Madness sustituye al
nodo blanco. Imagen `overworld/gb_void` (`warpzone/4/gbaura` + `gb_level`, la
monta `build_world1.py`): `closed` = el nodo blanco; `unlock` = el vacío parpadea 1 s detrás del nodo (como
el FlxFlicker de su WarpState) y luego, ya sin él, la estática se junta en un punto; `open` = el vacío con
el punto, sobre el que se pone BF.

**R dos veces en el mapa** borra el progreso de ese mundo y sus submundos, y además quita las llaves
que abren algo en ellos (la de Bad Day vuelve a salir en la canción) y olvida las visitas a sus tiendas
(Gaster vuelve a saludar como la primera vez). La EXP no se toca.

### EXP: la moneda de las tiendas

Superar un nivel (`level`) **por primera vez** desde el mapa da `OverworldData.XP_PER_LEVEL` (500) de
EXP. Sale la pantalla de EXP ganada de Friday Night Dustin' (`PlayState.showExpGain`: todo a negro,
"+ 500 EXP" contando con su sonido `levelup`, 2,6 s) y luego se vuelve al mapa. Repetir un nivel ya
superado no da EXP ni enseña la pantalla. La EXP se guarda al momento en la partida
(`FlxG.save.data.overworldXP`, `getXP`/`addXP`) y los niveles que ya la dieron, en
`FlxG.save.data.overworldXPGiven` (`"mundo::nodo"`): reiniciar un mundo con R no la vuelve a dar. La
tienda de Gaster enseña la que se tiene (cuadro "EXP:" encima del de diálogo); será lo que cuesten sus
cosas. Prueba de la pantalla sin sumar EXP: `run_songtest.ps1 -Song <canción> -Exp 20`.

### Regla: tuberías grises

La tubería que abre el castillo de un mundo es **gris** (`overworld/pipegray`, la de Mario's Madness
sin su versión con glitch); su pareja del otro mundo también. Se coloca igual que la verde (mismo
tamaño y mismo centrado). *Comprobar mundo* avisa si un castillo abre una tubería que no es gris.

Pruebas (debug): `-gaster-shop <tienda>` abre la tienda directamente (sin apuntar la visita; con
`-forget` borra la marca de "ya visitada"), y `-test-key <llave>` junto a `-overworld` da esa llave
solo durante esa ejecución, sin guardarla.

### Warps (tuberías y estrellas): nodos `warp`

Un `warp` lleva a otro mundo **con ENTER**, como las tuberías de Mario: por donde se entra se
sale. Ponle **Mundo destino** y, en ese mundo, otro `warp` con destino de vuelta a este: son
**pareja**. BF aparece **encima de la pareja**, no andando desde el borde. Desde ahí, ENTER le
devuelve por el mismo sitio.

Cómo viaja BF depende del **sprite** del warp (visuales sacados del mapa de Mario's Madness):

| Sprite | Al entrar | Al llegar |
|---|---|---|
| Una estrella (`overworld/star`, o cualquier imagen con "star" en el nombre) | Gira con el sonido de la pluma de SMW (`sounds/overworld/smw_feather_get`), sale volando hacia arriba y la pantalla se funde a negro a saltos | La pantalla se aclara a saltos y BF baja girando hasta posarse en la estrella |
| Cualquier otro (tubería...) | Da un saltito y se mete en la tubería; después se cierra el iris | Con el iris ya abierto, sale de la tubería de un salto |

La tubería suena con `assets/shared/sounds/overworld/pipe.ogg` (el `enter_the_pipe` de Mario's
Madness) al entrar y al salir; sin ese archivo, con el de entrar a un nivel.

No es un submundo: ESC sigue
abriendo el menú, y un warp es un salto "global" que olvida de qué castillos venías (si vuelves a
entrar a un submundo por un warp, su salida sabe sola a qué mapa de fuera llevar). Si el destino
no tiene pareja, BF aparece en su nodo inicial (*Comprobar mundo* lo avisa).

**Un warp por mundo destino** (y una salida con destino por mundo): la pareja se busca por mundo,
así que una segunda tubería hacia el mismo mundo se emparejaría con la primera. *Comprobar mundo*
lo avisa, y también si dos warps emparejados se esperan el uno al otro y ninguno se abre nunca.

Diferencia con las salidas `exit`: la salida se activa **al pisarla** (pensada para caminos que
se van de la pantalla) y el warp **con ENTER** (una tubería, una estrella...).

Un warp se desbloquea como cualquier nodo (por ejemplo, que lo abra el castillo del mundo con el
modo ENLAZAR), **y además se abre solo cuando su pareja está abierta**. Así se monta un **mundo
central**:

1. En cada mundo, un `warp` con destino al mundo central, desbloqueado por su castillo.
2. En el mundo central, un `warp` por mundo, con destino a ese mundo, **bloqueado y sin que nadie
   lo desbloquee**: se abre solo en cuanto el castillo de ese mundo abre su pareja. El nodo
   inicial del mundo central puede ser uno de ellos. Lo más rápido: en el warp del paso 1, pon
   el destino y pulsa **Crear pareja**.

El mundo central solo se puede pisar llegando por una tubería: si lo abres directamente sin
ninguna tubería abierta, no hay dónde aparecer. En el juego, BF vuelve entonces al mapa de fuera
o al mundo por defecto (probando desde el editor, en cambio, sale el aviso de que no hay ningún
nodo desbloqueado). No lo pongas como mundo por defecto.

Resultado: desde el mundo central solo se puede viajar a los mundos con el castillo derrumbado,
y se aparece encima de su tubería.

---

## Mundo de pruebas: `test_graph`

Un mundo pequeño para comprobar que el grafo funciona. Fue el mundo por defecto hasta que llegó
el mundo 1. Atajos en la carpeta `tests\`:
`test-world.bat` para jugarlo y `test-editor.bat` para abrirlo en el editor.

```
[T1]───[T2]───[T3]
         │      └──┐       camino en L (con un punto de curva)
      (cruce)      │       cruce = nodo "empty" (punto de paso)
         │       [T5]
       [T4]        │       T4: callejón sin salida, hay que volver
                [castillo]──(meta)     castillo = nodo "world" → test_subworld
```

| Nodo | Empieza | Al completarlo desbloquea |
|---|---|---|
| T1 | desbloqueado | T2 |
| T2 | bloqueado | T3, cruce y T4 (bifurcación) |
| T3 | bloqueado | T5 |
| T4 | bloqueado | nada |
| T5 | bloqueado | castillo |
| castillo | bloqueado | meta, la salida hacia `test_world2` y la tubería (cuando superas `test_subworld`) |

Desde la meta sale un camino hacia abajo que se va de la pantalla: es una salida con destino
`test_world2`. Ese mundo tiene dos niveles (Mundo 2 - 1 y 2 - 2) y su salida de vuelta está
fuera de la pantalla por arriba.

**Mundo central `test_hub`**: dos warps, una tubería hacia `test_graph` y una estrella hacia
`test_world2`. Sus parejas son la tubería bajo Tutorial 1 (la abre el castillo) y la estrella de
bajo Mundo 2 - 1 (la abre Mundo 2 - 2, el último nivel de ese mundo). Para probar llegadas sin
recorrer el mapa: `FNF2026Playground.exe -overworld test_hub -warp-from test_graph` (tubería) o
`-overworld test_world2 -warp-from test_hub` (estrella).

`test_subworld` son dos niveles en línea con dos salidas, una de cada tipo:

```
 ···(salida)···[Sub 1]───[Sub 2]───[tubo]
 fuera de la pantalla              salida visible
```

| Nodo | Empieza | Al completarlo desbloquea |
|---|---|---|
| Sub 1 | desbloqueado | Sub 2 |
| Sub 2 | bloqueado | tubo |
| salida | desbloqueada, sin sprite, en x = -112 | — (al llegar, vuelves al castillo) |
| tubo | bloqueado, sprite `overworld/pipe` | — (al llegar, vuelves al castillo) |

T4 no tiene *Anim. completado* a propósito: al superarlo se queda igual (como los niveles de
SMW), para poder ver los dos casos.

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
      "type": "level",                // level | world | empty | exit | warp
      "image": "overworld/big",
      "anim": "idle",
      "animDone": "",                 // animación cuando ya está superado
      "fps": 6,
      "name": "Tutorial",
      "song": "tutorial",
      "week": "tutorial",
      "difficulty": "",               // no se usa: esta build solo tiene Hard (ver Dificultad)
      "world": "",                    // solo para type "world"
      "unlocked": true,
      "unlocks": ["n1"],
      "needLevels": 0,                // >0: tambien se abre con N superados en este mundo
      "secretUnlocks": [],            // lo que abre su salida secreta (solo niveles)
      "secretMode": "fc",             // "fc" = pocos fallos | "accuracy" = precision minima | "song" = lo decide la cancion
      "secretMisses": 0,              // con "fc": fallos maximos permitidos
      "secretAccuracy": 95            // con "accuracy": % minimo
    }
  ],

  "sprites": [                        // decorados
    { "image": "overworld/selector/hub_path", "anim": "hub path stars", "fps": 8,
      "x": 0, "y": 0, "flipX": false, "flipY": false, "scale": 1, "alpha": 1, "front": false }
  ],

  "paths": [
    { "a": "n0", "b": "n1", "points": [[192, 160]],
      "dots": "overworld/dot", "dotAnim": "idle", "dotSpacing": 16,
      "unlockedBy": "",               // id del nodo que lo abre al completarse ("" = con sus nodos)
      "secret": false,                // true: lo abre la salida secreta de unlockedBy
      "road": false,                  // true: carretera de SMW en vez de puntitos (en el agua, puntitos blancos)
      "move": "walk",                 // como lo recorre BF: "walk" | "swim" | "climb"
      "style": "" }                   // dibujo de la carretera: "" (SMW) | "rainbow" (arcoiris)
  ]
}
```

## 6. Cómo se juega el mapa

- Flechas / WASD: BF camina al nodo contiguo en esa dirección, siguiendo el camino.
- Un nodo bloqueado no deja pasar (suena el *wrong*). Se desbloquea cuando completas un nodo que
  lo lista en `unlocks`.
- **Sonidos y música** (los del mapa de Mario's Madness, en `sounds/overworld/`): `move` al llegar a
  un nodo, `unlock` al abrirse un camino, `enter` al entrar a un nivel o castillo (el `gotolevel` de
  su mapa antiguo; al entrar, además, la música del mapa se apaga en 0,7 s), `wrong` cuando
  no se puede, `back` al salir con ESC, `pipe` y `smw_feather_get` en tuberías y estrellas. El
  mundo 1 suena con la música del mundo 1 de Mario's Madness (`music/overworld/world1`). Al volver
  de una canción (al acabarla, desde la pausa o desde el game over) no suena la música del menú:
  el mapa pone directamente la suya.
- ACCEPT: entra al nivel (o al mundo). Al terminar la canción vuelves al mapa y el nodo queda
  marcado como completado. Si sales por pausa o game over, vuelves al mapa sin completarlo. En
  *practice* o *botplay* tampoco cuenta.
- **Caminos nuevos**: la primera vez que superas un nivel, los caminos que abre aparecen puntito
  a puntito desde ese nivel, como en SMW. Si abre varios (una bifurcación), crecen a la vez; si
  un camino continúa desde otro recién abierto, sale después. ACCEPT o BACK se saltan la
  animación. Repetir un nivel ya superado no la vuelve a mostrar. Al abrirse suena un "boom" y
  salen nubecitas de humo, y al acabar **BF va solo al nodo recién abierto** (como en Mario's
  Madness); si se abren varios, al de la salida normal antes que al de la secreta.
- **Niveles superados**: el nodo cambia a su *Anim. completado*; si no tiene ninguna, se queda
  igual (así va el mundo 1: como en SMW, los niveles son amarillos y los que tienen salida
  secreta, rojos, y no cambian al superarlos; lo superado se nota en los caminos abiertos). Abajo,
  el nombre lleva **SUPERADO** y a la derecha se lee `Superados: X/Y` del mundo actual.
- Los niveles del mundo 1 usan `overworld/level_dot` (animaciones `yellow` y `red`, 6 fps): brillan
  cambiando un poco de color, con el ciclo del punto de los niveles de Mario's Madness (el de la
  paleta de SMW). Lo genera `tools/build_world1.py` a partir de `og_mario/level_tiles`.
- **Freeplay**: las canciones de los niveles de los mapas de la partida (los mundos a los que se
  llega desde `world1`) no salen en Freeplay hasta que su nivel está abierto en el mapa
  (`OverworldData.lockedSongs()`). Las que no son de ningún nivel (el tutorial, las de los mundos de
  prueba) salen siempre. Freeplay suena como el de Mario's Madness (`sounds/freeplay/scroll` al
  cambiar de canción) y al elegir una hace su salida (y la del Psych 0.7.2h del usuario): destello,
  `sounds/freeplay/start`, solo queda la elegida, zoom y fundido a negro en 3 s antes de cargarla.
- BACK (ESC): abre el menú principal (freeplay, opciones, mods, créditos, editores) en cualquier
  mapa, también dentro de un submundo. Story Mode te devuelve al mismo mapa y nodo.
- **Nodo `exit`**: al llegar andando a él, BF sale del submundo (sin *Mundo destino*) o pasa al
  mundo que tenga de destino, entrando andando por la salida de vuelta. Si ese mundo aún no
  existe (o la salida no lleva a ningún sitio), sale un aviso y BF vuelve andando al nodo de
  antes. Una estrella o tubería hacia un mundo que no existe avisa de que "todavía no existe".
- **Transiciones**: al entrar a un nivel, a un castillo, a una tubería o a otro mapa, la pantalla se
  cierra en un **círculo sobre BF** y el mapa siguiente se abre igual (también al volver de una
  canción), como en Super Mario World.
- **Cámara**: si un camino que se acaba de abrir se sale de la pantalla, la cámara va a mirarlo
  mientras aparece y luego vuelve a BF.
- **R dos veces seguidas** (la primera pide confirmación): reinicia el progreso del mundo actual
  **y de sus submundos** (útil mientras pruebas). No toca los mapas de los que vienes. Ojo: lo que
  se abría desde esos submundos en otros mapas (por ejemplo la tubería del mundo central) vuelve a
  cerrarse.
- **Mapa sin ningún nodo abierto**: si BF va a parar a un mapa donde no hay ningún nodo abierto
  (por ejemplo, la posición guardada en el mundo central después de reiniciar el mundo que abría
  su tubería), vuelve solo al mapa de fuera o al mundo por defecto, para no quedarse atrapado.

El progreso se guarda en el `FlxG.save` del juego, con la clave `overworldProgress`
(`"<mundo>::<nodo>"`, y `"<mundo>::<nodo>#secret"` para las salidas secretas; por eso los IDs no
admiten `#`). Un nodo nuevo no hereda el progreso de uno borrado que tuviera su mismo ID,
y renombrar un nodo se lleva su progreso al ID nuevo.

## Isla piloto (`pilot_island`)

Un mundo de muestra **sin niveles**, compuesto por código con los tiles de SMW: isla con costa
curva y acantilado con espuma, una meseta alta, colinas, árboles, un claro de arena, un prado,
estanques, un islote y rocas en el mar, sobre un fondo de mar animado hecho con el tile de agua
(`overworld/backgrounds/smw_sea`). Se abre con `tests\test-pilot-island.bat`.

Lo genera `tools/build_pilot_island.py` (necesita Pillow): el mapa se describe con celdas de la hoja
original `art/overworld_source/smw_overworld_tiles.png` y funciones como `island()`, `cap()` y
`stamp()`, y el script busca cada celda en el atlas y escribe el JSON. Con un nombre de archivo
como argumento guarda además una vista previa. Tras regenerarlo hay que volver a compilar (o
copiar el JSON a `export/.../assets/shared/overworlds/`) para verlo en el juego.

## Mundo 1 (`world1`)

El primer mundo real, según el boceto del usuario. Se juega con `tests\test-world1.bat` y se edita
con `tests\edit-world1.bat`. Lo genera entero (grafo y arte) `tools/build_world1.py` (necesita
Pillow y numpy). Con un nombre de archivo como argumento guarda una vista previa del mapa completo, y
con `--dry-run` solo hace la vista previa.

**Dos formas de cambiarlo** (no mezclarlas sin querer):

1. **En el editor** (`tests\edit-world1.bat`): mover nodos (V), crear nodos (N), caminos (C),
   desbloqueos (L), decorados (B) y tiles (T, con la paleta de `overworld/world1/tiles` o la de
   SMW). En la pestaña *Nodo* van la canción, el nombre, el aspecto y lo que desbloquea; en
   *Camino*, la carretera y si BF anda, nada o trepa. Cada columna, roca o matorral es un decorado
   entero: elígelo con un clic y usa la barra *Mover / Copiar / Borrar* (bloquea los TILES con F3
   para no coger la hierba de debajo). **CTRL+S** guarda en la build (para probar sin compilar) y en
   el repo (`assets/shared/overworlds/world1.json`); **CTRL+T** lo prueba.
2. **Con el script** (`python tools/build_world1.py`): para cambiar la forma de la isla, de la meseta
   o del islote, o la decoración entera. Posiciones de los nodos en `graph()`, formas en `ISLAND`,
   `ISLET` y `PLATEAU`, y decoración en `decorate()`. Regenera todo el JSON.

En cuanto el mundo se guarda desde el editor, el script **ya no lo sobrescribe**: lo detecta porque el
editor escribe el JSON con otro formato, y se para avisando. Con `--force` lo regenera igualmente,
pero se pierde lo hecho en el editor.

Está diseñado como la isla del mundo 1 de Mario's Madness (`assets/images/warpzone/1/bg1.png` de su
mod; el usuario lo eligió el 14/11/2026 entre cuatro variantes: esa, una al estilo de Yoshi's Island,
otra con meseta escalonada y bosque, y la anterior). El mundo cabe en una pantalla (416x224) y la
cámara no se mueve; los niveles están a 40-90 px unos de otros:

- **Isla**: una caja con el borde festoneado y un frente de acantilado liso. Inicio con la tubería
  encima, yararara, Bad Day y Chaos en el cruce.
- **Meseta**: un bloque elevado encima de la isla. Desde Chaos se **trepa por una escalera**
  (aparece al abrirse el camino) hasta Last Course; sigue el castillo (World of Chaos, que se ve
  derrumbado al superarlo) y, al final, una **estrella** que llevará al mundo 2.
- **Islote de Endless**: desde Chaos se va a la izquierda y se **cruza a nado** hacia el norte; desde
  el islote se sigue nadando hacia el norte, fuera de la pantalla, hacia otro mundo.
- Carreteras beis (puntitos blancos en el agua), columnas con ojos asomando por detrás de los bordes,
  rocas en cuña, matorrales, piedrecitas, rocas blancas en el mar y peces saltando (su animación).
  Música: la del mundo 1 de Mario's Madness.

El terreno se dibuja por código con la paleta de SMW (la misma de Mario's Madness): cada capa (isla,
islote, meseta) es una forma con su costa festoneada, su acantilado liso (sin grietas) y la espuma
donde da al mar. Se trocea en tiles de 8x8 (`overworld/world1/tiles`, también en la paleta del
editor). Las columnas, rocas, matorrales, piedrecitas, matas y rocas del mar se recortan del propio
mapa de Mario's Madness (las columnas se alargan repitiendo una fila del cuerpo) y van **enteros**,
cada uno como un decorado del atlas `overworld/world1/props` (`bush`, `rock`, `pebble`, `tuft`,
`sea_rock`, `pillar<alto>px`), encima del terreno: en el editor un clic elige el matorral o la columna
entera, y al moverlo o borrarlo debajo queda hierba limpia. Con la capa TILES bloqueada (F3) se
pueden elegir y arrastrar sin tocar el terreno. El mar es `overworld/backgrounds/world1_sea`, en fotogramas de 32x32: el juego redondea el
tamaño del mapa a fotogramas enteros del fondo, y con fotogramas pequeños el mapa mide lo que el
dibujo. En el juego, los decorados quietos se juntan en una sola imagen al cargar el mapa
(`OverworldState.bakeStillSprites`); en el editor siguen sueltos para poder editarlos.

| Nodo | Qué es |
|---|---|
| `inicio` | Punto de aparición (no es nivel), con la tubería encima |
| `tuberia` | Tubería gris (warp, `overworld/pipegray`) al **mundo de las estrellas** (`star_world`, el de viajar rápido entre mundos). Se ve desde el principio, pero su camino solo se abre al derrotar el castillo |
| `yararara` | Primer nivel (abierto) |
| `bad-day` | Lo abre yararara. Al superarlo abre Chaos |
| `tienda` | La tienda de Gaster (`shop`, `gaster_w1`, llave `world1_key`), al final del camino en L que sale de Bad Day. La llave está escondida en Bad Day: cuando el Mario pixel rompe la barra de vida, salta una llave dorada que cae al pie del jarrón de la cómoda; un clic encima la recoge (suenan los susurros de Gaster) y, si se acaba la canción, se gana. Sin ella la tienda es un nodo blanco sin camino; con ella se revela el camino y el nodo se vuelve el vacío de Game Boy (`overworld/gb_void`). En el mundo 1 Gaster solo habla: avisa de que existen las llaves |
| `chaos` | El cruce de 3 caminos. Al superarlo abre la escalera a la meseta; su **salida secreta** (las 7 esmeraldas) abre el camino a nado al norte |
| `last-course` | En la meseta |
| `castillo` | World of Chaos. Al superarlo abre la estrella y la tubería |
| `estrella` | Al final, después del castillo: estrella (warp) al mundo 2, `world2` (aún no existe) |
| `endless` | En el islote del norte, a nado |
| `salida-norte` | Salida invisible fuera de la pantalla, a nado desde Endless: llevará a `world-secret` (aún no existe; BF vuelve) |

Las canciones se van añadiendo a medida que se portan (ver `docs/SONG_PORTS.md`); hasta entonces
el editor avisa de los niveles sin canción. Ya tienen todos la suya: `yararara`, `bad-day`, `chaos`,
`last-course`, `endless` (`endless-us`) y el castillo (`world-of-chaos`). La salida secreta de
`chaos` usa el modo `cancion`: la da reunir las 7 esmeraldas, no los fallos. Es el mundo por defecto
(el que abre Story Mode).

**Tuberías, castillos y estrellas** (las imágenes con `pipe`, `castle` o `star` en el nombre) no van
centradas en su nodo como las demás: BF se pone encima, así que su cuerpo (sin la sombra negra) se centra
bajo BF y suben 3 px (`OverworldState.placeNodeSprite`, igual en el editor). Así BF queda con los pies
en el medio de lo que se ve y, en una tubería, justo sobre el agujero. El sonido de la tubería
(`sounds/overworld/pipe.ogg`) lo puso el usuario: recortado a lo que suena y en OGG Vorbis (el juego
no reproduce Opus).

## Mundo de las estrellas (`star_world`)

El mundo para viajar rápido entre mundos, como la Star Road de Mario's Madness (su mundo 3). Lo genera
`tools/build_star_world.py` (igual que el mundo 1: no lo sobrescribe si se ha guardado desde el editor,
salvo con `--force`).

- Cielo de noche con estrellitas que titilan (`backgrounds/star_sky`, en mosaico), la luna y un suelo de
  nubes (tiles). En el centro, las columnas moradas con estrellas del mod, enteras (`star_world/props`).
- Encima de cada una de sus seis puntas hay una **estrella-warp**: `estrella-2` ... `estrella-7`, hacia
  `world2` ... `world7`. Cada una se abre cuando su mundo exista y tenga un warp que vuelva aquí (su
  pareja); hasta entonces es un *pendiente*, no un aviso, y su camino no se ve.
- La **tubería** de la izquierda es la pareja de la del mundo 1, que se abre al derrotar su castillo.
- Los caminos son **arcoíris** (`style: "rainbow"`): uno por las nubes, de la tubería a la derecha, con
  cruces invisibles (nodos `empty` sin imagen) bajo cada estrella, y de cada cruce sube uno a su estrella
  (la de arriba del todo se alcanza desde la del centro). Música: la de la Star Road del mod.

Los destinos y nombres de las estrellas se pueden cambiar en el editor (pestaña Nodo).

## Prototipos de mundos futuros

`tools/build_prototypes.py <carpeta>` dibuja bocetos de diseño (solo imágenes, a escala 3) de seis
ambientes, con el mismo método que el mundo 1 y los decorados de la biblioteca: **bosque** (mundo 2 de
Mario's Madness), **subterráneo** (mundo 6: rocas de cueva y tuberías), **fortaleza** (mundo 4),
**lava** (mundo 5), **nieve** (la paleta Star World de SMW) y **desierto** (paleta de SMW). Están en
`art/world_prototypes/`. Cuando se elija uno, se convierte en un mundo de verdad con su propio
generador.

Ojo: la carretera automática reconoce los acantilados por el marrón de la paleta verde de SMW. En una
paleta con los riscos de otro color (morados en la nieve, grises en la cueva) habrá que enseñarle
esos colores (`OverworldTerrain.classify`).

## Pruebas automáticas (solo build debug)

Se lanzan desde `export/debug/windows/bin` (el juego busca `assets\` en su carpeta):

| Argumentos | Qué hace |
|---|---|
| `-overworld <mundo> -shot` | Abre ese mapa, a los 3 s guarda una captura en `world_shot.png` junto al exe y se cierra. No guarda la posición de BF y no se pausa aunque la ventana arranque sin foco. Con `-shotat <s>` la captura es a esos segundos, y con `-walk <left/right/up/down>` BF echa a andar por código a los 0,5 s (para ver cómo nada o trepa). |
| `-check-worlds` | Revisa todos los mundos de la build (también la partida entera), escribe el resultado en `check_worlds.txt` junto al exe y se cierra. |
| `-song <canción> -test` | Juega una canción entera en botplay con capturas; ver `docs/SONG_PORTS.md` y `tools/run_songtest.ps1`. |
| `-overworld-editor test_graph -selftest` | Prueba los botones de unir mundos, el aspecto desde la paleta, deshacer (con progreso, tiles y submundos), pintar, grupos, el rectángulo, las capas, el cuentagotas, copiar / cortar / pegar / mover, las piezas, los avisos nuevos, los pendientes y los de la partida entera. Escribe `SELFTEST OK/FAIL` por consola (83 comprobaciones; al acabar deja elegida una pieza, con su barra de acciones, para poder capturar la ventana) y borra sus mundos `zz_*`. |
| `-playtest` | Monta 5 mundos de demostración con las funciones del editor y los juega por código: una canción de verdad, castillo, tuberías y una estrella (con capturas a mitad del viaje), salida lateral, menú, R, un mapa sin nodos abiertos, probar desde un nodo cerrado, salidas secretas (sin fallos, por precisión y el modo canción), un nodo de N superados, un atajo con condición, la cámara del revelado, el iris y el otro sprite de jugador (111 comprobaciones). Deja `playtest_result.txt` y capturas en `playtest_shots\` (también del editor), borra sus mundos `zz_demo*` y se cierra. En cada captura comprueba que ningún sprite use una imagen ya liberada. |

Ninguna toca la partida del usuario ni simula teclas. `tools/run_playtest.ps1` lanza la prueba
jugable y muestra su resultado.

**Dónde está BF también se guarda** (clave `overworldPosition`: mundo, nodo y la pila de
submundos): al abrir el juego otra vez, sigue en el mismo sitio, aunque sea dentro de un castillo.
Se recupera al entrar desde el título y con `run-world.bat` / `tests\test-world.bat` (el mundo por
defecto). Si abres a propósito otro mundo (`run-world.bat test_subworld`) o usas `-from`, se
empieza en ese mundo como siempre. Probando desde el editor (CTRL+T) no se guarda. La debug y la
release comparten partida.

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
