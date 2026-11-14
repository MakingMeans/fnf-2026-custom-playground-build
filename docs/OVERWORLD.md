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

El mundo que abre el título (y con el que arranca el editor si no le pasas otro) es el que dice
`OverworldData.DEFAULT_WORLD`; ahora mismo es **`test_graph`**. Si borras o renombras su `.json`,
el título vuelve a llevar directamente al menú clásico de siempre.

## 2. Controles del editor

| Tecla / ratón | Qué hace |
|---|---|
| **V** | Modo SELECCIONAR: clic para elegir y arrastrar nodos o decorados. **SHIFT+clic** suma o quita del grupo; **arrastrar en el vacío** dibuja un rectángulo que selecciona lo de dentro (con SHIFT, lo añade) |
| **N** | Modo NODO: clic en el mapa crea un nodo nuevo |
| **B** | Modo DECORADO: clic coloca el sprite elegido en la pestaña *Decorado* |
| **C** | Modo CAMINO: clic en un nodo y luego en otro para unirlos. Si no están alineados, el camino sale **en L** (con SHIFT en el segundo clic, primero en vertical) |
| **T** | Modo PINTAR TILES: pinta con el tile elegido en la paleta (arrastra para pintar seguido) |
| **L** | Modo ENLAZAR: clic en el nodo que desbloquea y luego en cada nodo (o camino) que abre; SHIFT+clic = con su salida secreta (ver abajo). L otra vez vuelve a SELECCIONAR |
| **P** | Mostrar / ocultar la paleta de tiles |
| Clic derecho | Borra lo que haya bajo el ratón (en modo L solo cancela; sobre un punto de curva, borra ese punto) |
| Arrastrar un punto de curva | Lo mueve (modos V y C) |
| **E** | Ir al siguiente aviso: selecciona su nodo y centra la cámara en él |
| SUPR | Borra la selección actual (o el grupo entero, en un solo paso de deshacer) |
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

### Aspecto de un nodo desde la paleta

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
| **Salida secreta** | Pestaña Nodo: *Salida secreta* (`fallos` o `precision`), el contador de al lado (*Max fallos / % min*) y *Su salida secreta desbloquea*; o modo L + SHIFT+clic | Al superar el nivel cumpliendo la condición que tú pones (como mucho N fallos, o al menos ese % de precisión), además se abre lo de su salida secreta. Puede sacarse repitiendo el nivel. En *practice* o *botplay* no cuenta. |

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

Pintar encima de otro **tile pintado** lo sustituye; un decorado puesto a mano (un castillo con
**B**) no se borra por pintar en su casilla. Pintar, borrar y mover decorados no rehace el resto
del mapa, así que va fluido aunque tengas miles de tiles.

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

Sirven igual para los **nodos**: con el nodo elegido, CTRL+clic en el tile de la paleta
(CTRL+SHIFT+clic para su aspecto al completarlo). Ver *Aspecto de un nodo desde la paleta*.

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

  También salta solo al guardar. En pantalla caben 4 avisos; la lista completa sale por consola.
  En la build debug, además, cada mundo que se carga escribe sus avisos en la consola.
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

El juego entra al mundo que nombra `OverworldData.DEFAULT_WORLD` (ahora `test_graph`). Tienes
dos opciones:

- **Que tu mundo sea el principal**: ponle ese nombre de archivo y guárdalo, o cambia la constante
  en `source/backend/OverworldData.hx`.
- **Mantener un selector de mundos** (como el de SMW): deja el mundo principal como mapa selector y
  añádele un nodo de **Tipo `world`** con **Mundo destino** = `mundo1`. Al entrar en ese nodo saltas
  a tu mundo.

### Salidas y transiciones: nodos `exit`

**ESC no saca de un mapa**: abre el menú principal, y al salir del menú vuelves al mismo mapa y
nodo. Para irse de un mapa hay que **llegar andando a un nodo de tipo `exit`**. Lo que pasa al
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

### Warps (tuberías): nodos `warp`

Un `warp` lleva a otro mundo **con ENTER**, como las tuberías de Mario: por donde se entra se
sale. Ponle **Mundo destino** y, en ese mundo, otro `warp` con destino de vuelta a este: son
**pareja**. BF se mete con su animación de *warp* y aparece **encima de la pareja**, no andando
desde el borde. Desde ahí, ENTER le devuelve por el mismo sitio. No es un submundo: ESC sigue
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

Un mundo pequeño para comprobar que el grafo funciona. Es el **mundo por defecto**: es el que
abre el título, `play.bat` y `run-world.bat` sin nombre. Atajos en la carpeta `tests\`:
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

**Mundo central `test_hub`**: dos tuberías (`warp`), una hacia `test_graph` y otra hacia
`test_world2`. Sus parejas son la tubería bajo Tutorial 1 (la abre el castillo) y la de bajo
Mundo 2 - 1 (la abre Mundo 2 - 2, el último nivel de ese mundo). Para probar llegadas sin
recorrer el mapa: `FNF2026Playground.exe -overworld test_hub -warp-from test_graph`.

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

T4 no tiene *Anim. completado* a propósito: al superarlo sale el check verde en vez de cambiar
de color, para poder ver los dos tipos de marca.

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
      "secretMode": "fc",             // "fc" = pocos fallos | "accuracy" = precision minima
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
      "secret": false }               // true: lo abre la salida secreta de unlockedBy
  ]
}
```

## 6. Cómo se juega el mapa

- Flechas / WASD: BF camina al nodo contiguo en esa dirección, siguiendo el camino.
- Un nodo bloqueado no deja pasar (suena el *cancel*). Se desbloquea cuando completas un nodo que
  lo lista en `unlocks`.
- ACCEPT: entra al nivel (o al mundo). Al terminar la canción vuelves al mapa y el nodo queda
  marcado como completado. Si sales por pausa o game over, vuelves al mapa sin completarlo. En
  *practice* o *botplay* tampoco cuenta.
- **Caminos nuevos**: la primera vez que superas un nivel, los caminos que abre aparecen puntito
  a puntito desde ese nivel, como en SMW. Si abre varios (una bifurcación), crecen a la vez; si
  un camino continúa desde otro recién abierto, sale después. ACCEPT o BACK se saltan la
  animación. Repetir un nivel ya superado no la vuelve a mostrar.
- **Niveles superados**: el nodo cambia a su *Anim. completado*. Si no tiene ninguna, se le pone
  encima un **check verde**. Abajo, el nombre lleva **SUPERADO** y a la derecha se lee
  `Superados: X/Y` del mundo actual.
- BACK (ESC): abre el menú clásico (freeplay, opciones, mods, créditos, editores) en cualquier
  mapa, también dentro de un submundo. BACK en ese menú te devuelve al mismo mapa y nodo.
- **Nodo `exit`**: al llegar andando a él, BF sale del submundo (sin *Mundo destino*) o pasa al
  mundo que tenga de destino, entrando andando por la salida de vuelta.
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

El primer mundo real, según el boceto del usuario. Se abre con `tests\test-world1.bat`. De momento
es el grafo sobre el mar (el arte con tiles vendrá después) y lo genera `tools/build_world1.py`: si
se edita en el editor, no volver a ejecutar ese script.

| Nodo | Qué es |
|---|---|
| `inicio` | Punto de aparición (no es nivel), con la tubería encima (aún sin destino) |
| `yararara` | Primer nivel (abierto) |
| `bad-day` | Lo abre yararara |
| `chaos` | El cruce de 3 caminos. Al superarlo abre los escalones a la meseta; su **salida secreta** (las 7 esmeraldas) abre el puente al norte |
| `last-course` | En la meseta |
| `castillo` | World of Chaos |
| `endless` | Al norte, pasando el puente |
| `camino-norte`, `camino-este` | Final de los caminos que seguirán a otros mundos |

Las canciones se van añadiendo a medida que se portan (ver `docs/SONG_PORTS.md`); hasta entonces
el editor avisa de los niveles sin canción. El mundo 1 todavía no es el mundo por defecto.

## Pruebas automáticas (solo build debug)

Se lanzan desde `export/debug/windows/bin` (el juego busca `assets\` en su carpeta):

| Argumentos | Qué hace |
|---|---|
| `-overworld <mundo> -shot` | Abre ese mapa, a los 3 s guarda una captura en `world_shot.png` junto al exe y se cierra. |
| `-check-worlds` | Revisa todos los mundos de la build (también la partida entera), escribe el resultado en `check_worlds.txt` junto al exe y se cierra. |
| `-song <canción> -test` | Juega una canción entera en botplay con capturas; ver `docs/SONG_PORTS.md` y `tools/run_songtest.ps1`. |
| `-overworld-editor test_graph -selftest` | Prueba los botones de unir mundos, el aspecto desde la paleta, deshacer (con progreso, tiles y submundos), pintar, grupos, el rectángulo, los avisos nuevos y los de la partida entera. Escribe `SELFTEST OK/FAIL` por consola (49 comprobaciones) y borra sus mundos `zz_*`. |
| `-playtest` | Monta 5 mundos de demostración con las funciones del editor y los juega por código: una canción de verdad, castillo, tuberías, salida lateral, menú, R, un mapa sin nodos abiertos, probar desde un nodo cerrado, salidas secretas (sin fallos y por precisión), un nodo de N superados, un atajo con condición, la cámara del revelado, el iris y el otro sprite de jugador (106 comprobaciones). Deja `playtest_result.txt` y capturas en `playtest_shots\` (también del editor), borra sus mundos `zz_demo*` y se cierra. En cada captura comprueba que ningún sprite use una imagen ya liberada. |

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
