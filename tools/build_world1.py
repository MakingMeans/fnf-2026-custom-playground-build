"""Genera el mundo 1 (`world1`) segun el boceto del usuario: el grafo y el arte del mapa.

Uso:  python tools/build_world1.py [vista_previa.png] [--dry-run] [--force]
Necesita Pillow y numpy. Con --dry-run solo hace la vista previa. Si world1.json se ha guardado desde el
editor (o tocado a mano), no lo sobrescribe salvo con --force (se perderian esos cambios).

Escribe:
  assets/shared/overworlds/world1.json        el mundo (nodos, caminos y el terreno como tiles)
  assets/shared/images/overworld/world1/      tiles.* (el terreno troceado en 8x8), props.* (los
                                              decorados enteros: columnas, rocas, matorrales...),
                                              ladder.* (la escalera del acantilado) y fish.* (los peces
                                              que saltan, del mundo 1 de Mario's Madness)
  assets/shared/images/overworld/backgrounds/world1_sea.*   el mar, en fotogramas de 32x32
  assets/shared/images/overworld/level_dot.*  los niveles amarillo y rojo, con su ciclo de color
  assets/shared/sounds/overworld/*, music/overworld/world1   los sonidos y la musica del mapa de MM
y lo copia a las builds que existan (export/*/...).

Diseno: el de la isla del mundo 1 de Mario's Madness (assets/images/warpzone/1/bg1.png de su mod), que el
usuario eligio entre cuatro variantes el 14/11/2026: la isla es una caja con el borde festoneado
(bultitos redondos) y un frente de acantilado liso; la meseta del castillo es otro bloque, elevado
encima; columnas con ojos asoman por detras de los bordes; rocas en cuna, matorrales, piedrecitas y
matas de hierba sueltos; rocas blancas en el mar y peces saltando. Las columnas, rocas, matorrales,
piedras, matas y rocas del mar se recortan de ese mismo mapa del mod; el terreno se dibuja por codigo
con su paleta (la de SMW) y se trocea en tiles de 8x8 (atlas world1/tiles); lo transparente es mar
(el fondo animado backgrounds/world1_sea). El mundo cabe en una pantalla y la camara no se mueve; los
niveles van unidos por carreteras beis (caminos con `road`), que en el agua son puntitos (alli BF
nada: `move: 'swim'`); a la meseta se sube por una escalera (`move: 'climb'`).

Boceto (de abajo arriba):
  - Isla: Inicio (punto de aparicion, no es nivel) con una tuberia encima; a la derecha yararara
    (primer nivel) y Bad Day; encima de Bad Day, Chaos, el cruce de 3 caminos.
  - La meseta, detras: desde Chaos se trepa por la escalera a Last Course, y de ahi al castillo (World
    of Chaos); tras el castillo, la estrella al mundo 2.
  - Desde Chaos, a la izquierda y nadando hacia el norte: Endless, en un islote (su salida secreta: las
    7 esmeraldas); desde alli se sigue nadando hacia el norte, fuera de la pantalla, a otro mundo.
  - La tuberia (se abre al derrotar el castillo) lleva al mundo de las estrellas (star_world); la estrella
    y la salida del norte no llevan a ningun sitio hasta que haya otros mundos.
"""
import json
import math
import os
import shutil
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'shared', 'overworlds', 'world1.json')
IMAGES = os.path.join(ROOT, 'assets', 'shared', 'images')
OWN_DIR = os.path.join(IMAGES, 'overworld', 'world1')
SHEET = os.path.join(ROOT, 'art', 'overworld_source', 'smw_overworld_tiles.png')
MM_WARPZONE = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets/images/warpzone/1'
MM_FISH = MM_WARPZONE + '/bg2'
MM_ISLAND = MM_WARPZONE + '/bg1.png'
WEEK = 'world1'

T = 8
W, H = 416, 224  # cabe en la pantalla del juego (427x240 a zoom 3): la camara se queda quieta

# ------------------------------------------------------------------------------------------ grafo
# Como en SMW: los niveles son amarillos y el que tiene salida secreta, rojo (no cambian al superarlos), y
# brillan cambiando un poco de color (overworld/level_dot, ver level_dot_frames)
LEVEL_LOOK = {'image': 'overworld/level_dot', 'anim': 'yellow', 'animDone': '', 'fps': 6}
SECRET_LOOK = {'image': 'overworld/level_dot', 'anim': 'red', 'animDone': '', 'fps': 6}
CASTLE_LOOK = {'image': 'overworld/castle', 'anim': 'idle', 'animDone': 'dead', 'fps': 0}  # derrumbado al superarlo
DOT_LOOK = {'image': 'overworld/dot', 'anim': 'idle', 'animDone': '', 'fps': 6}
PIPE_LOOK = {'image': 'overworld/pipe', 'anim': 'idle', 'animDone': '', 'fps': 0}
STAR_LOOK = {'image': 'overworld/star', 'anim': 'idle', 'animDone': '', 'fps': 8}
HIDDEN_LOOK = {'image': '', 'anim': '', 'animDone': '', 'fps': 0}  # una salida fuera de la pantalla no se ve

# Posiciones (centro del nodo, en pixeles del mapa)
LOW = 168        # fila de abajo: Inicio, yararara y Bad Day (subida el 15/11/2026: estaba pegada al borde)
CROSS = 132      # Chaos, al pie de la meseta
TOP = 60         # fila de la meseta: Last Course, castillo y estrella
X_STAIRS = 216   # Bad Day, Chaos, la escalera y Last Course
X_NORTH = 120    # el camino a nado hacia el islote de Endless


def node(node_id, x, y, name, kind='level', song='', look=None, unlocked=False, unlocks=None, secret=None, secret_mode='fc', world=''):
    data = {
        'id': node_id, 'x': x, 'y': y, 'type': kind,
        'image': '', 'anim': '', 'animDone': '', 'fps': 0,
        'name': name, 'song': song, 'week': WEEK if kind == 'level' else '', 'difficulty': '', 'world': world,
        'unlocked': unlocked, 'unlocks': unlocks or [],
        'needLevels': 0, 'secretUnlocks': secret or [], 'secretMode': secret_mode, 'secretMisses': 0, 'secretAccuracy': 95,
    }
    data.update(look or (LEVEL_LOOK if kind == 'level' else DOT_LOOK))
    return data


def path(a, b, points=None, road=True, move='walk', dots='overworld/dot', spacing=16):
    return {'a': a, 'b': b, 'points': points or [], 'dots': dots, 'dotAnim': 'idle', 'dotSpacing': spacing,
            'unlockedBy': '', 'secret': False, 'road': road, 'move': move}


def graph():
    nodes = [
        node('inicio', 64, LOW, 'Inicio', kind='empty', unlocked=True),
        # la tuberia lleva al mundo de las estrellas (el de viajar rapido entre mundos) y solo se abre al
        # derrotar el castillo; hasta entonces se ve, pero sin camino (15/11/2026, a peticion del usuario)
        node('tuberia', 64, 136, 'Mundo de las estrellas', kind='warp', look=PIPE_LOOK, world='star_world'),
        node('yararara', 136, LOW, 'YARARARA', song='yararara', unlocked=True, unlocks=['bad-day']),
        node('bad-day', X_STAIRS, LOW, 'Bad Day', song='bad-day', unlocks=['chaos']),
        # salida normal: la escalera a la meseta; salida secreta (7 esmeraldas, la decide la cancion): a
        # nado al norte. Por tener salida secreta es rojo, como en SMW
        node('chaos', X_STAIRS, CROSS, 'Chaos', song='chaos', look=SECRET_LOOK, unlocks=['last-course'], secret=['endless'], secret_mode='song'),
        node('last-course', X_STAIRS, TOP, 'Last Course', song='last-course', unlocks=['castillo']),
        node('castillo', 296, TOP, 'World of Chaos', song='world-of-chaos', look=CASTLE_LOOK, unlocks=['estrella', 'tuberia']),
        # la estrella del final lleva al mundo 2 (cuando exista, con una estrella que apunte de vuelta aqui)
        node('estrella', 376, TOP, 'Hacia el mundo 2', kind='warp', look=STAR_LOOK, world='world2'),
        node('endless', X_NORTH, 42, 'Endless', song='endless-us', unlocks=['salida-norte']),
        # salida fuera de la pantalla, a nado hacia el norte: lleva a otro mundo que aun no existe (BF vuelve)
        node('salida-norte', X_NORTH, -24, 'Hacia el norte', kind='exit', look=HIDDEN_LOOK, world='world-secret'),
    ]
    paths = [
        path('inicio', 'tuberia'),
        path('inicio', 'yararara'),
        path('yararara', 'bad-day'),
        path('bad-day', 'chaos'),
        # a la meseta: carretera normal; donde cruza el acantilado se pone sola una escalera y BF trepa
        # (OverworldTerrain), y en la hierba de arriba y de abajo es franja beis
        path('chaos', 'last-course'),
        path('last-course', 'castillo'),
        path('castillo', 'estrella'),
        path('chaos', 'endless', [[X_NORTH, CROSS]], move='swim'),  # a la izquierda y luego a nado al norte
        path('endless', 'salida-norte', move='swim'),
    ]
    return nodes, paths


# ------------------------------------------------------------------------------------------ paleta
BLACK = (13, 12, 13)
GRASS = (64, 208, 32)
GRASS_MID = (64, 168, 32)
GRASS_DARK = (64, 136, 32)
BROWN = (216, 152, 96)
BROWN_SHADE = (184, 120, 72)
FOAM = (240, 240, 240)
# las rayas del mar y de la espuma: blancas (el verde de SMW no le gustaba al usuario, 15/11/2026)
SMW_WAVE = (64, 208, 33)
WAVE = FOAM
WATER_COLORS = {(64, 136, 247), (64, 136, 248), (63, 136, 247)}
GRASS_COLORS = {(64, 208, 32), (64, 208, 33)}

sheet = Image.open(SHEET).convert('RGBA')  # de aqui sale el mar
canvas = np.zeros((H, W, 4), dtype=np.uint8)  # RGBA; alfa 0 = mar


def setpx(x, y, color):
    if 0 <= x < W and 0 <= y < H:
        canvas[y, x, :3] = color
        canvas[y, x, 3] = 255


# ------------------------------------------------------------------------------------------ formas
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5


def rounded_rect(x0, y0, x1, y1, r):
    """Distancia con signo a un rectangulo de esquinas redondas (negativa dentro)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(XX - cx) - hx, np.abs(YY - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def land(*sdfs, scallop=1.2, period=7.0):
    """Union de formas con el borde festoneado de los mapas de Mario's Madness (bultitos redondos)."""
    d = np.minimum.reduce(sdfs)
    bump = scallop * np.abs(np.sin(np.pi * (XX + YY) / period))
    return d - bump <= 0


# ------------------------------------------------------------------------------------------ terreno
def edge_distance(mask, limit=4):
    """Distancia (en pasos de 8 vecinos) de cada pixel de tierra al borde de su forma."""
    dist = np.where(mask, limit, 0).astype(np.int32)
    inside = mask.copy()
    for step in range(1, limit):
        # un pixel esta a `step` del borde si algun vecino esta fuera de lo que queda
        shrunk = inside.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                shrunk &= np.roll(np.roll(inside, dy, 0), dx, 1)
        dist[inside & ~shrunk] = step
        inside = shrunk
    return dist


def paint_layer(mask, cliff, below_land, seed=0, foam=True):
    """Una capa de tierra: hierba con su costa (contorno negro y bandas de verde) y, debajo de su borde
    sur, el acantilado: marron liso (sin grietas: las rayas negras sueltas quedaban raras), con el
    contorno negro en los lados y las aristas de las esquinas, como la isla de Mario's Madness. Acaba en
    una linea negra ondulada y, en el mar (lo que no es `below_land`), espuma."""
    rng = np.random.default_rng(seed)
    dist = edge_distance(mask)
    colors = {1: BLACK, 2: GRASS_DARK, 3: GRASS_MID}
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        setpx(x, y, colors.get(dist[y, x], GRASS))
    # textura de la hierba: motitas sueltas, como las de los tiles de SMW
    for y, x in zip(ys, xs):
        if dist[y, x] >= 5 and rng.random() < 0.010:
            setpx(x, y, GRASS_MID)

    rock = np.zeros_like(mask)
    bottom = mask & ~np.roll(mask, -1, 0)
    for y, x in zip(*np.nonzero(bottom)):
        length = cliff + int(round(0.9 * abs(math.sin(math.pi * x / 6.0))))  # pie ondulado
        for k in range(1, length + 1):
            yy = y + k
            if yy >= H or mask[yy, x]:
                break
            rock[yy, x] = True
    for y, x in zip(*np.nonzero(rock)):
        side = (x == 0 or not (rock[y, x - 1] or mask[y, x - 1])) or (x == W - 1 or not (rock[y, x + 1] or mask[y, x + 1]))
        setpx(x, y, BLACK if side else BROWN)
    # aristas de las esquinas: donde el borde de abajo deja de curvarse
    cols = [x for x in range(W) if rock[:, x].any()]
    runs, run = [], []
    for x in cols:
        if run and x != run[-1] + 1:
            runs.append(run)
            run = []
        run.append(x)
    if run:
        runs.append(run)
    for run in runs:
        if len(run) < 30:
            continue
        tops = {x: int(np.nonzero(rock[:, x])[0].min()) for x in run}
        flat = int(np.median(list(tops.values())))
        inner = [x for x in run if tops[x] >= flat - 1]
        for x in (inner[0], inner[-1]):
            for y in np.nonzero(rock[:, x])[0]:
                setpx(x, int(y), BLACK)
    # el pie: linea negra; en el mar, ademas la espuma (blanco y una onda verde)
    foot = rock & ~np.roll(rock, -1, 0)
    for y, x in zip(*np.nonzero(foot)):
        setpx(x, y + 1, BLACK)
        if foam and not below_land[min(H - 1, y + 2), x]:
            wave = (x // 3) % 2
            setpx(x, y + 2, FOAM)
            setpx(x, y + 3 + wave, WAVE)
            if wave:
                setpx(x, y + 3, FOAM)
    return mask | rock


# Formas (en pixeles del mapa): la isla en L (la parte de la meseta llega hasta arriba), el islote de
# Endless y la meseta, un bloque elevado encima de la isla
ISLAND = land(rounded_rect(24, 104, 406, 192, 10), rounded_rect(170, 26, 406, 192, 10))
ISLAND_CLIFF = 18  # el pie y la espuma quedan por encima del HUD del mapa
ISLET = land(rounded_rect(92, 28, 150, 58, 8))
PLATEAU = land(rounded_rect(184, 34, 398, 84, 10))
NOWHERE = np.zeros((H, W), dtype=bool)


# ------------------------------------------------------------------------------------------ decorado
def mm_piece(box, clear_grass=True):
    """Un trozo del mapa del mundo 1 de Mario's Madness; el agua (y la hierba) quedan transparentes."""
    arr = np.array(Image.open(MM_ISLAND).convert('RGBA').crop(box))
    for y in range(arr.shape[0]):
        for x in range(arr.shape[1]):
            color = tuple(int(v) for v in arr[y, x, :3])
            if color in WATER_COLORS or (clear_grass and color in GRASS_COLORS):
                arr[y, x, 3] = 0
    return arr


def whiten_waves(img):
    """Las rayas de las olas de SMW (verdes) en blanco."""
    arr = np.array(img.convert('RGBA'))
    wave = np.all(arr[..., :3] == SMW_WAVE, axis=2)
    arr[wave, :3] = WAVE
    return Image.fromarray(arr, 'RGBA')


# Los decorados (columnas, rocas, matorrales...) no se pintan en el terreno: van como sprites enteros
# encima de sus tiles (atlas world1/props). Asi en el editor cada uno se elige de un clic y se mueve,
# copia o borra entero, y debajo queda hierba limpia (15/11/2026, a peticion del usuario).
PROPS = []        # [(fotograma, x, y, flip)], en el orden en que se dibujan
PROP_FRAMES = {}  # fotograma -> trozo RGBA sin voltear (el sprite lleva flipX)


def put(name, piece, x, y, flip=False):
    """Pone el decorado `name` (el trozo `piece`) con su esquina en (x, y) del mapa."""
    PROP_FRAMES.setdefault(name, piece)
    PROPS.append((name, x, y, flip))


ROCK = mm_piece((64, 104, 83, 122))                         # roca en cuna, con su sombra
BUSH = mm_piece((66, 95, 77, 105))
PEBBLE = mm_piece((108, 96, 115, 103))
TUFT = mm_piece((109, 113, 113, 117))
SEA_ROCK = np.array(whiten_waves(Image.fromarray(mm_piece((37, 72, 56, 89), clear_grass=False), 'RGBA')))  # roca del mar, con su espuma
PILLAR = mm_piece((79, 59, 95, 97))  # columna con ojos: tapa (filas 0-20), cuerpo (21) y sombra (36-37)


def eyed_pillar(x, base, height, flip=False):
    """Columna con ojos del alto que haga falta (minimo 21 px): `base` es la fila de su pie y la sombra
    va debajo. Se alarga repitiendo una fila del cuerpo de la de Mario's Madness."""
    cap, body, shadow = PILLAR[0:21], PILLAR[21:22], PILLAR[36:38]
    n = max(0, height - 21)
    put('pillar%dpx' % (21 + n), np.concatenate([cap] + [body] * n + [shadow], axis=0), x, base - (21 + n) + 1, flip)


def decorate():
    # columnas con ojos asomando por detras de los bordes (como las de Mario's Madness). Tres las movio el
    # usuario en el editor (15/11/2026): se respetan sus sitios
    eyed_pillar(34, 116, 34)
    eyed_pillar(50, 116, 24)
    eyed_pillar(144, 115, 28, flip=True)
    eyed_pillar(376, 45, 30)
    eyed_pillar(224, 49, 26)
    eyed_pillar(96, 40, 20)  # en el islote, a la izquierda del camino de Endless
    # la zona de la derecha de la isla, que estaba vacia: un grupo de columnas bajas
    eyed_pillar(352, 150, 22)
    eyed_pillar(368, 156, 28, flip=True)
    # rocas en cuna, matorrales, piedrecitas y matas, lejos de caminos y nodos y enteros sobre la hierba
    # (a 4 px o mas del borde). Entre la fila de abajo y la de Chaos hay poco sitio: alli van bajitos
    for x, y, flip in [(84, 141, False), (152, 141, True), (250, 146, False), (330, 160, True),
                       (264, 40, True), (338, 66, False), (300, 126, False)]:
        put('rock', ROCK, x, y, flip)
    for x, y in [(36, 128), (98, 176), (176, 176), (290, 140), (392, 172), (360, 180),
                 (196, 112), (262, 72), (360, 42), (132, 34), (40, 150), (48, 156), (136, 112), (144, 112),
                 (330, 108), (342, 112), (388, 112), (200, 40), (330, 38), (250, 44),
                 (264, 128), (272, 168), (304, 160),
                 # la derecha: matorrales sueltos alrededor de las columnas y las rocas
                 (318, 178), (350, 166), (378, 176), (282, 154), (240, 176)]:
        put('bush', BUSH, x, y)
    for x, y in [(102, 150), (190, 154), (270, 112), (350, 112), (300, 40), (240, 72), (320, 146), (256, 184)]:
        put('pebble', PEBBLE, x, y)
    for x, y in [(70, 122), (106, 180), (240, 120), (320, 120), (390, 150), (280, 50), (360, 60), (110, 50),
                 (296, 176), (336, 132), (232, 160)]:
        put('tuft', TUFT, x, y)
    # rocas blancas en el mar: las 8 de los lados del paso a nado del islote las puso el usuario
    for x, y in [(24, 16), (220, 2), (336, 0), (4, 90),
                 (96, -8), (96, 8), (128, -8), (128, 8), (96, 72), (96, 88), (128, 72), (128, 88)]:
        put('sea_rock', SEA_ROCK, x, y)


# peces que saltan (bg2 del mundo 1 de Mario's Madness, en bucle: 12 fotogramas y una pausa). Miden
# 18x44: tienen que quedar dentro del mapa (W x H), o el juego lo agranda y la camara se mueve
FISH = [(48, 32), (152, 40), (4, 140)]  # los dos primeros, donde los dejo el usuario en el editor (15/11/2026)


def compose():
    island = paint_layer(ISLAND, ISLAND_CLIFF, NOWHERE, seed=1)
    islet = paint_layer(ISLET, 12, NOWHERE, seed=2)
    paint_layer(PLATEAU, 20, island | islet, seed=3, foam=False)
    decorate()


# ------------------------------------------------------------------------------------------ assets
BG_DIR = os.path.join(IMAGES, 'overworld', 'backgrounds')
SEA_KEY = 'overworld/backgrounds/world1_sea'


def write_atlas(name, frames, per_row=16, folder=OWN_DIR):
    """Atlas Sparrow (en world1/ por defecto): frames = [(nombre, imagen RGBA)], todos del mismo tamano."""
    fw, fh = frames[0][1].size
    rows = (len(frames) + per_row - 1) // per_row
    atlas = Image.new('RGBA', (min(len(frames), per_row) * fw, rows * fh), (0, 0, 0, 0))
    xml = ['<?xml version="1.0" encoding="utf-8"?>', '<TextureAtlas imagePath="%s.png">' % name]
    for i, (frame_name, img) in enumerate(frames):
        x, y = (i % per_row) * fw, (i // per_row) * fh
        atlas.paste(img, (x, y))
        xml.append('\t<SubTexture name="%s" x="%d" y="%d" width="%d" height="%d" frameX="0" frameY="0" frameWidth="%d" frameHeight="%d"/>'
                   % (frame_name, x, y, fw, fh, fw, fh))
    xml.append('</TextureAtlas>')
    os.makedirs(folder, exist_ok=True)
    atlas.save(os.path.join(folder, name + '.png'))
    with open(os.path.join(folder, name + '.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(xml) + '\n')


def write_packed_atlas(name, frames, width=256, folder=OWN_DIR):
    """Atlas Sparrow con fotogramas de distinto tamano, en filas con 1 px de separacion. frames =
    [(nombre, imagen RGBA)]; cada uno queda como "<nombre>0000" (el decorado lo pide por su nombre)."""
    x = y = row_h = 0
    places = []
    for frame_name, img in frames:
        if x and x + img.width > width:
            x, y, row_h = 0, y + row_h + 1, 0
        places.append((frame_name, img, x, y))
        x += img.width + 1
        row_h = max(row_h, img.height)
    atlas = Image.new('RGBA', (width, y + row_h), (0, 0, 0, 0))
    xml = ['<?xml version="1.0" encoding="utf-8"?>', '<TextureAtlas imagePath="%s.png">' % name]
    for frame_name, img, fx, fy in places:
        atlas.paste(img, (fx, fy))
        xml.append('\t<SubTexture name="%s0000" x="%d" y="%d" width="%d" height="%d"/>' % (frame_name, fx, fy, img.width, img.height))
    xml.append('</TextureAtlas>')
    os.makedirs(folder, exist_ok=True)
    atlas.save(os.path.join(folder, name + '.png'))
    with open(os.path.join(folder, name + '.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(xml) + '\n')


def prop_images():
    """Los fotogramas de los decorados, como imagenes RGBA."""
    return [(name, Image.fromarray(np.ascontiguousarray(piece), 'RGBA')) for name, piece in sorted(PROP_FRAMES.items())]


def ladder_frame():
    """Un peldano de la escalera (16x6): dos largueros marrones y el travesano claro, estilo SMW."""
    img = Image.new('RGBA', (16, 6), (0, 0, 0, 0))
    px = img.load()
    for y in range(6):
        for x in (1, 14):
            px[x, y] = BLACK + (255,)
        for x in (2, 13):
            px[x, y] = BROWN + (255,)
    for x in range(3, 13):
        px[x, 2] = BLACK + (255,)
        px[x, 3] = (248, 232, 176, 255)
        px[x, 4] = BROWN_SHADE + (255,)
    return img


def sea_frames():
    """El mar de SMW (la celda de agua de la hoja y sus fotogramas) en fotogramas de 32x32: con
    fotogramas pequenos el mapa puede medir cualquier multiplo de 32 (el juego lo redondea a ellos)."""
    frames = []
    for i, row in enumerate([0, 2, 4, 6]):
        tile = sheet.crop((0, row * 9, T, row * 9 + T)).convert('RGBA')
        tile = whiten_waves(tile)
        frame = Image.new('RGBA', (32, 32))
        for y in range(0, 32, T):
            for x in range(0, 32, T):
                frame.paste(tile, (x, y))
        frames.append(('idle%04d' % i, frame))
    return frames


def copy_fish():
    os.makedirs(OWN_DIR, exist_ok=True)
    shutil.copyfile(MM_FISH + '.png', os.path.join(OWN_DIR, 'fish.png'))
    shutil.copyfile(MM_FISH + '.xml', os.path.join(OWN_DIR, 'fish.xml'))


# Sonidos y musica del mapa de Mario's Madness (los usa OverworldState en todos los mundos)
MM_ASSETS = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets'
MM_AUDIO = [
    ('sounds/owCuts/wz_move.ogg', 'sounds/overworld/move.ogg'),          # BF llega a un nodo
    ('sounds/owCuts/smw_boom.ogg', 'sounds/overworld/unlock.ogg'),       # se abre un camino
    # entrar a un nivel o castillo: el de su mapa antiguo (WarpStateLegacy); el nuevo no pone ninguno
    # (owCuts/enter es el de una escena, no el de entrar)
    ('sounds/gotolevel.ogg', 'sounds/overworld/enter.ogg'),
    ('sounds/wrong.ogg', 'sounds/overworld/wrong.ogg'),                  # no se puede (cerrado, sin destino)
    ('sounds/cancelMenu.ogg', 'sounds/overworld/back.ogg'),              # salir del mapa
    # No se copian aqui (se ajustaron a mano el 15/11/2026 y esto los pisaria), los dos a unos -20 dB de media
    # como el resto de efectos del mapa, con el ffmpeg de Krita:
    # - sounds/overworld/pipe.ogg: el que puso el usuario (Opus), recortado a lo que suena, -9,5 dB, OGG Vorbis;
    # - sounds/overworld/smw_feather_get.ogg (estrella): el de owCuts del mod, +11 dB, en estereo.
    ('music/warpzone/1.ogg', 'music/overworld/world1.ogg'),              # musica del mundo 1
]


def copy_audio():
    for src, dst in MM_AUDIO:
        out = os.path.join(ROOT, 'assets', 'shared', *dst.split('/'))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copyfile(os.path.join(MM_ASSETS, *src.split('/')), out)


# ------------------------------------------------------------------------------------------ salida
def slice_tiles():
    """Trocea el lienzo en tiles de 8x8: [(x, y, fotograma)] y los tiles unicos {nombre: imagen}."""
    names, own, sprites = {}, {}, []
    for row in range(H // T):
        for col in range(W // T):
            tile = canvas[row * T:(row + 1) * T, col * T:(col + 1) * T]
            if not tile[:, :, 3].any():
                continue  # mar
            key = tile.tobytes()
            if key not in names:
                names[key] = 'w1_%04d' % len(names)
                own[names[key]] = Image.fromarray(tile.copy(), 'RGBA')
            sprites.append((col * T, row * T, names[key]))
    return sprites, own


# Ciclo de color de los niveles: el amarillo es el del punto de los niveles de Mario's Madness
# (warpzone/dot, 7 fotogramas a 6 fps: naranja, amarillo, amarillo claro y vuelta), el de la paleta de
# SMW; el rojo hace lo mismo con rojos. Se pinta sobre el relleno de los niveles de SMW
# (og_mario/level_tiles tile0002 y tile0003), que conservan su contorno negro.
LEVEL_CYCLES = {
    'yellow': ('tile0002', [(248, 208, 0), (248, 248, 72), (248, 248, 184), (248, 248, 184), (248, 248, 72),
                            (248, 208, 0), (248, 176, 0)]),
    'red': ('tile0003', [(232, 32, 0), (248, 72, 32), (248, 120, 88), (248, 120, 88), (248, 72, 32),
                         (232, 32, 0), (216, 0, 0)]),
}


def level_dot_frames():
    frames = []
    for anim, (tile, colors) in LEVEL_CYCLES.items():
        base = np.array(sparrow_frame('overworld/og_mario/level_tiles', tile))
        fill = base[..., 3].astype(bool) & (base[..., :3].sum(axis=2) > 120)  # todo menos el contorno negro
        for i, color in enumerate(colors):
            frame = base.copy()
            frame[fill, :3] = color
            frames.append(('%s%04d' % (anim, i), Image.fromarray(frame, 'RGBA')))
    return frames


def sparrow_frame(key, name):
    if key == 'overworld/level_dot':  # se genera aqui (la vista previa puede ir antes de escribirlo)
        return dict(level_dot_frames())[name + '0000']
    base = os.path.join(IMAGES, *key.split('/'))
    if not os.path.exists(base + '.xml'):
        base = os.path.join(OWN_DIR, key.split('/')[-1])
    img = Image.open(base + '.png').convert('RGBA')
    for sub in ET.parse(base + '.xml').getroot().iter('SubTexture'):
        if sub.get('name').startswith(name):
            x, y, w, h = (int(sub.get(k)) for k in ('x', 'y', 'width', 'height'))
            return img.crop((x, y, x + w, y + h))
    return None


def preview(nodes, paths, out):
    """Vista previa a escala 2 (sin animar): mar, terreno, carreteras, nodos, peces y BF en el inicio."""
    sea = sea_frames()[0][1]
    img = Image.new('RGBA', (W, H))
    for y in range(0, H, 32):
        for x in range(0, W, 32):
            img.paste(sea, (x, y))
    terrain = Image.fromarray(canvas, 'RGBA')
    img.alpha_composite(terrain)
    images = dict(prop_images())
    for name, x, y, flip in PROPS:  # los decorados, encima del terreno y debajo de las carreteras
        prop = images[name].transpose(Image.FLIP_LEFT_RIGHT) if flip else images[name]
        img.paste(prop, (x, y), prop)
    land = canvas[:, :, 3] > 0
    by_id = {n['id']: n for n in nodes}
    dot = sparrow_frame('overworld/dot', 'idle')
    rung = ladder_frame()
    for pth in paths:
        pts = [(by_id[pth['a']]['x'], by_id[pth['a']]['y'])] + [tuple(p) for p in pth['points']] + [(by_id[pth['b']]['x'], by_id[pth['b']]['y'])]
        samples = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            length = max(1, int(math.ceil(math.hypot(bx - ax, by - ay))))
            samples += [(ax + (bx - ax) * s / length, ay + (by - ay) * s / length) for s in range(length)]
        samples.append(pts[-1])
        if pth['road']:
            px = img.load()
            water = 0
            for i, (sx, sy) in enumerate(samples):
                on_land = 0 <= sy < H and 0 <= sx < W and land[int(sy), int(sx)]
                radius = 7 if (i == 0 or i == len(samples) - 1) and on_land else (4 if on_land else 1.2)
                if not on_land:
                    water += 1
                    if (water - 1) % 6:
                        continue
                color = (248, 232, 176, 255) if on_land else (240, 240, 240, 255)
                for yy in range(int(sy - radius) - 1, int(sy + radius) + 2):
                    for xx in range(int(sx - radius) - 1, int(sx + radius) + 2):
                        if 0 <= xx < W and 0 <= yy < H and (xx + 0.5 - sx) ** 2 + (yy + 0.5 - sy) ** 2 <= radius * radius:
                            px[xx, yy] = color
        else:
            sprite = rung if 'ladder' in pth['dots'] else dot
            step = pth['dotSpacing']
            total = len(samples) - 1
            for d in range(int(step), total, int(step)):
                sx, sy = samples[d]
                img.alpha_composite(sprite, (int(sx - sprite.width / 2), int(sy - sprite.height / 2)))
    for n in nodes:
        spr = sparrow_frame(n['image'], n['anim']) if n['image'] else None
        if spr is not None:
            img.alpha_composite(spr, (int(n['x'] - spr.width / 2), int(n['y'] - spr.height / 2)))
    fish = Image.open(MM_FISH + '.png').convert('RGBA').crop((36, 0, 54, 44))
    for x, y in FISH:
        img.alpha_composite(fish, (x, y))
    bf = sparrow_frame('overworld/overworld_bf', 'overworld bf walk down')
    start = by_id['inicio']
    img.alpha_composite(bf, (int(start['x'] - bf.width / 2), int(start['y'] - bf.height + 4)))
    img.resize((W * 3, H * 3), Image.NEAREST).save(out)
    print('vista previa -> ' + out)


def world_json(world):
    """JSON con nodos y caminos legibles y un decorado por linea."""
    keys = list(world)
    lines = ['{']
    for i, key in enumerate(keys):
        comma = ',' if i < len(keys) - 1 else ''
        value = world[key]
        if key == 'sprites':
            lines.append('\t"sprites": [')
            for j, spr in enumerate(value):
                end = ',' if j < len(value) - 1 else ''
                lines.append('\t\t' + json.dumps(spr, ensure_ascii=False, separators=(', ', ': ')) + end)
            lines.append('\t]' + comma)
        else:
            text = json.dumps(value, indent='\t', ensure_ascii=False).replace('\n', '\n\t')
            lines.append('\t%s: %s%s' % (json.dumps(key), text, comma))
    lines.append('}')
    return '\n'.join(lines) + '\n'


def edited_by_hand():
    """True si world1.json no es tal cual lo escribio este script (se guardo desde el editor del juego,
    que lo escribe con otro formato, o se toco a mano): entonces regenerarlo machacaria esos cambios."""
    if not os.path.exists(OUT):
        return False
    with open(OUT, encoding='utf-8') as f:
        text = f.read()
    try:
        return world_json(json.loads(text)) != text
    except ValueError:
        return True


def main(args):
    dry = '--dry-run' in args
    files = [a for a in args if not a.startswith('--')]
    if not dry and '--force' not in args and edited_by_hand():
        raise SystemExit('world1.json se ha editado (en el editor o a mano) desde que lo genero este script: '
                         'regenerarlo borraria esos cambios. Usa --dry-run para ver la vista previa, o --force '
                         'para sobrescribirlo de todas formas.')

    compose()
    nodes, paths = graph()
    tiles, own = slice_tiles()
    print('%d tiles (%d distintos)' % (len(tiles), len(own)))
    if files:
        preview(nodes, paths, files[0])
    if dry:
        return

    sprites = [{'image': 'overworld/world1/tiles', 'anim': name, 'fps': 0, 'x': x, 'y': y, 'flipX': False, 'flipY': False,
                'scale': 1, 'alpha': 1, 'front': False} for x, y, name in tiles]
    sprites += [{'image': 'overworld/world1/props', 'anim': name, 'fps': 0, 'x': x, 'y': y, 'flipX': flip, 'flipY': False,
                 'scale': 1, 'alpha': 1, 'front': False} for name, x, y, flip in PROPS]
    sprites += [{'image': 'overworld/world1/fish', 'anim': 'idle', 'fps': 8, 'x': x, 'y': y, 'flipX': i % 2 == 1, 'flipY': False,
                 'scale': 1, 'alpha': 1, 'front': False} for i, (x, y) in enumerate(FISH)]
    world = {
        'displayName': 'Mundo 1',
        'bg': SEA_KEY, 'bgAnim': 'idle', 'bgFps': 4, 'bgTile': True,
        'music': 'overworld/world1', 'zoom': 3, 'gridSize': 8, 'startNode': 'inicio',
        'player': 'overworld/overworld_bf', 'walkSpeed': 60,
        'nodes': nodes, 'sprites': sprites, 'paths': paths,
    }

    write_atlas('tiles', sorted(own.items()))
    write_packed_atlas('props', prop_images())
    write_atlas('ladder', [('idle0000', ladder_frame())])
    write_atlas('level_dot', level_dot_frames(), per_row=7, folder=os.path.join(IMAGES, 'overworld'))
    write_atlas('world1_sea', sea_frames(), per_row=2, folder=BG_DIR)
    copy_fish()
    copy_audio()
    text = world_json(world)
    json.loads(text)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('-> ' + OUT)
    print('-> ' + OWN_DIR)

    for kind in ('debug', 'release'):
        build = os.path.join(ROOT, 'export', kind, 'windows', 'bin', 'assets', 'shared')
        if os.path.isdir(build):
            shutil.copyfile(OUT, os.path.join(build, 'overworlds', 'world1.json'))
            build_own = os.path.join(build, 'images', 'overworld', 'world1')
            if os.path.isdir(build_own):
                shutil.rmtree(build_own)
            shutil.copytree(OWN_DIR, build_own)
            for ext in ('png', 'xml'):
                shutil.copyfile(os.path.join(BG_DIR, 'world1_sea.' + ext),
                                os.path.join(build, 'images', 'overworld', 'backgrounds', 'world1_sea.' + ext))
                shutil.copyfile(os.path.join(IMAGES, 'overworld', 'level_dot.' + ext),
                                os.path.join(build, 'images', 'overworld', 'level_dot.' + ext))
            print('-> ' + build)


if __name__ == '__main__':
    main(sys.argv[1:])
