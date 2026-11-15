"""Genera el mundo 1 (`world1`) segun el boceto del usuario: el grafo y el arte del mapa.

Uso:  python tools/build_world1.py [vista_previa.png] [--dry-run]
Necesita Pillow.

Escribe:
  assets/shared/overworlds/world1.json            el mundo (nodos, caminos y el arte como tiles pintados)
  assets/shared/images/overworld/world1/tiles.*   los tiles que la hoja de SMW no trae (puente, escalones,
                                                  esquinas), en un atlas de 8x8 como og_mario
y los copia a las builds que existan (export/*/...), para verlo sin recompilar. Con --dry-run solo hace
la vista previa. Si se edita el mundo en el editor, NO volver a ejecutar este script: sobrescribiria
esos cambios.

El mapa se dibuja en un lienzo de 768x496 (3x2 fondos de mar: el tamaño que le calcula el juego) con
celdas de art/overworld_source/smw_overworld_tiles.png y dibujos propios, y se trocea en tiles de 8x8:
los que ya existen en og_mario/overworld_tiles se pintan con ese atlas y el resto va al atlas propio.
Lo transparente es mar (el fondo animado smw_sea).

Boceto (de abajo arriba):
  - Isla baja que llega al borde derecho: Inicio (punto de aparicion, no es nivel) con una tuberia
    encima; a la derecha yararara (primer nivel) y Bad Day en la esquina; de ahi sube a Chaos, el
    cruce de 3 caminos.
  - Detras, la meseta (llega al borde derecho y se mete en el mar por el norte): desde Chaos se sube
    por unos escalones del acantilado a Last Course, y de ahi al castillo (World of Chaos); el camino
    sigue hacia el este, fuera del mapa.
  - Desde Chaos, a la izquierda y por el puente hacia el norte: Endless (encima del puente), que abre
    la salida secreta de Chaos (las 7 esmeraldas); el puente sigue hacia el norte, fuera del mapa.
  - La tuberia y los caminos del norte y del este no llevan a ningun sitio hasta que haya otros
    mundos: acaban en un punto de paso.
"""
import json
import os
import shutil
import sys
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'shared', 'overworlds', 'world1.json')
IMAGES = os.path.join(ROOT, 'assets', 'shared', 'images')
SHEET = os.path.join(ROOT, 'art', 'overworld_source', 'smw_overworld_tiles.png')
SMW_KEY = 'overworld/og_mario/overworld_tiles'
OWN_KEY = 'overworld/world1/tiles'
WEEK = 'world1'

T = 8
COLS, ROWS = 96, 62  # 768 x 496

# ------------------------------------------------------------------------------------------ grafo
LEVEL_LOOK = {'image': 'overworld/og_mario/level_tiles', 'anim': 'tile0002', 'animDone': 'tile0003', 'fps': 0}
CASTLE_LOOK = {'image': 'overworld/castle', 'anim': 'idle', 'animDone': 'dead', 'fps': 0}  # derrumbado al superarlo
DOT_LOOK = {'image': 'overworld/dot', 'anim': 'idle', 'animDone': '', 'fps': 6}
PIPE_LOOK = {'image': 'overworld/pipe', 'anim': 'idle', 'animDone': '', 'fps': 0}

# Posiciones (centro del nodo, en pixeles del mapa): las del boceto escaladas a 768 de ancho
X_PIPE = 112      # columna de Inicio y la tuberia
X_BRIDGE = 288    # el puente y el camino de Endless
X_STAIRS = 480    # Bad Day, Chaos, los escalones y Last Course
Y_BOTTOM = 352    # fila de abajo: Inicio, yararara y Bad Day
Y_CROSS = 248     # Chaos (el cruce)
Y_PLATEAU = 96    # fila de la meseta: Last Course, castillo y salida al este


def node(node_id, x, y, name, kind='level', song='', look=None, unlocked=False, unlocks=None, secret=None, secret_mode='fc'):
    data = {
        'id': node_id, 'x': x, 'y': y, 'type': kind,
        'image': '', 'anim': '', 'animDone': '', 'fps': 0,
        'name': name, 'song': song, 'week': WEEK if kind == 'level' else '', 'difficulty': '', 'world': '',
        'unlocked': unlocked, 'unlocks': unlocks or [],
        'needLevels': 0, 'secretUnlocks': secret or [], 'secretMode': secret_mode, 'secretMisses': 0, 'secretAccuracy': 95,
    }
    data.update(look or (LEVEL_LOOK if kind == 'level' else DOT_LOOK))
    return data


def path(a, b, points=None):
    return {'a': a, 'b': b, 'points': points or [], 'dots': 'overworld/dot', 'dotAnim': 'idle', 'dotSpacing': 16,
            'unlockedBy': '', 'secret': False}


def graph():
    nodes = [
        node('inicio', X_PIPE, Y_BOTTOM, 'Inicio', kind='empty', unlocked=True),
        node('tuberia', X_PIPE, 264, 'Tuberia (sin destino)', kind='empty', look=PIPE_LOOK, unlocked=True),
        node('yararara', 248, Y_BOTTOM, 'YARARARA', song='yararara', unlocked=True, unlocks=['bad-day']),
        node('bad-day', X_STAIRS, Y_BOTTOM, 'Bad Day', song='bad-day', unlocks=['chaos']),
        # salida normal: los escalones a la meseta; salida secreta (7 esmeraldas, la decide la cancion): el puente
        node('chaos', X_STAIRS, Y_CROSS, 'Chaos', song='chaos', unlocks=['last-course'], secret=['endless'], secret_mode='song'),
        node('last-course', X_STAIRS, Y_PLATEAU, 'Last Course', song='last-course', unlocks=['castillo']),
        node('castillo', 608, Y_PLATEAU, 'World of Chaos', song='world-of-chaos', look=CASTLE_LOOK, unlocks=['camino-este']),
        node('endless', X_BRIDGE, 88, 'Endless', song='endless-us', unlocks=['camino-norte']),
        node('camino-norte', X_BRIDGE, 32, 'Hacia el norte', kind='empty'),
        node('camino-este', 736, Y_PLATEAU, 'Hacia el este', kind='empty'),
    ]
    paths = [
        path('inicio', 'tuberia'),
        path('inicio', 'yararara'),
        path('yararara', 'bad-day'),
        path('bad-day', 'chaos'),
        path('chaos', 'last-course'),  # por los escalones
        path('last-course', 'castillo'),
        path('castillo', 'camino-este'),
        path('chaos', 'endless', [[X_BRIDGE, Y_CROSS]]),  # a la izquierda y luego al norte por el puente
        path('endless', 'camino-norte'),
    ]
    return nodes, paths


# ------------------------------------------------------------------------------------------ lienzo
sheet = Image.open(SHEET).convert('RGBA')
PEACH = sheet.getpixel((8, 0))  # color de los separadores y de las celdas vacias de la hoja
canvas = Image.new('RGBA', (COLS * T, ROWS * T), (0, 0, 0, 0))

BLACK = (13, 12, 13, 255)
BROWN = (216, 152, 96, 255)
BEIGE = (248, 232, 176, 255)
ROCK_LIT = (240, 184, 128, 255)    # el canto iluminado de cada grieta
ROCK_SHADE = (184, 120, 72, 255)   # sombra bajo la hierba y fondo de la escalera
WATER_SHADOW = (0, 0, 0, 80)

GRASS = (10, 7)
SIDE = (2, 12)  # borde izquierdo liso: linea negra vertical


def cell(c, r):
    tile = sheet.crop((c * 9, r * 9, c * 9 + T, r * 9 + T))
    data = [(0, 0, 0, 0) if p[:3] == PEACH[:3] else p for p in tile.getdata()]
    tile.putdata(data)
    return tile


def put(col, row, c, r):
    if 0 <= col < COLS and 0 <= row < ROWS:
        canvas.paste(cell(c, r), (col * T, row * T))


def stamp(col, row, c0, r0, w, h):
    """Copia un bloque de la hoja; las celdas vacias (color de fondo de la hoja) se saltan."""
    for dy in range(h):
        for dx in range(w):
            if PEACH in sheet.crop(((c0 + dx) * 9, (r0 + dy) * 9, (c0 + dx) * 9 + T, (r0 + dy) * 9 + T)).getdata():
                continue
            put(col + dx, row + dy, c0 + dx, r0 + dy)


def draw(x0, y0, rows, colors, only_on=None):
    """Dibuja un patron de texto ('.' = nada). only_on: solo sobre pixeles transparentes o no."""
    px = canvas.load()
    for dy, line in enumerate(rows):
        for dx, ch in enumerate(line):
            x, y = x0 + dx, y0 + dy
            if ch == '.' or not (0 <= x < COLS * T and 0 <= y < ROWS * T):
                continue
            if only_on == 'water' and px[x, y][3] != 0:
                continue
            px[x, y] = colors[ch]


# ------------------------------------------------------------------------------------------ terreno
ISLAND_X, ISLAND_TOP, ISLAND_CLIFF = 4, 23, 49  # borde izquierdo, costa de arriba, fila del acantilado
PLATEAU_X, PLATEAU_TOP, WALL_TOP, WALL_FOOT = 54, 6, 17, 26  # borde izquierdo, costa, acantilado, pie


def island():
    """Isla baja estilo SMW que sigue mas alla del borde derecho: costa curva arriba a la izquierda,
    lado izquierdo recto y abajo un acantilado con espuma (las piezas de la isla piloto)."""
    for col in range(ISLAND_X, COLS):
        i = col - ISLAND_X
        put(col, ISLAND_TOP, *((2 + i, 17) if i < 3 else (11 + i % 2, 6)))
        for row in range(ISLAND_TOP + 1, ISLAND_CLIFF):
            put(col, row, *(SIDE if i == 0 else GRASS))
        put(col, ISLAND_CLIFF, *((2 + i, 19) if i < 3 else (11 + i % 2, 11)))
        put(col, ISLAND_CLIFF + 1, *((2 + i, 20) if i < 3 else (5 + i % 2, 20)))


def plateau():
    """La meseta: su parte de arriba se mete en el mar por el norte y su acantilado baja a la hierba de
    la isla. Sigue mas alla del borde derecho. El borde de hierba y el pie del acantilado son los de la
    meseta redonda de la hoja; la roca de en medio se dibuja aparte (wall_rock)."""
    for col in range(PLATEAU_X, COLS):
        i = col - PLATEAU_X
        pair = i % 2  # la hoja alterna dos tiles en el borde de hierba y en el pie: (11, .) y (12, .)
        put(col, PLATEAU_TOP, *((2 + i, 17) if i < 3 else (11 + i % 2, 6)))
        for row in range(PLATEAU_TOP + 1, WALL_TOP):
            put(col, row, *(SIDE if i == 0 else GRASS))
        put(col, WALL_TOP, 11 + pair, 11)
        for row in range(WALL_TOP + 1, WALL_FOOT):
            put(col, row, 11 + pair, 12)  # roca de la hoja con su linea negra a la izquierda (el borde)
        put(col, WALL_FOOT, 11 + pair, 14)
    # la esquina de arriba del acantilado da al mar: la linea negra del lado sigue hasta la roca
    px = canvas.load()
    for y in range(WALL_TOP * T, WALL_TOP * T + 7):
        px[PLATEAU_X * T, y] = BLACK
    wall_rock()


def wall_rock():
    """La roca del acantilado: grietas verticales de largo y separacion irregulares que cuelgan del
    borde de hierba, y otras mas cortas que suben desde el pie (la de la hoja, a rayas iguales cada
    16 px, parecia una valla en un acantilado tan alto)."""
    px = canvas.load()
    x0, x1 = PLATEAU_X * T, COLS * T
    y0, y1 = (WALL_TOP + 1) * T, WALL_FOOT * T
    height = y1 - y0
    for y in range(y0, y1):
        for x in range(x0 + 1, x1):  # x0 conserva la linea negra del borde izquierdo
            px[x, y] = ROCK_SHADE if y == y0 else BROWN

    def crack(x, ya, yb):
        for y in range(ya, yb):
            px[x, y] = BLACK
            if x + 1 < x1:
                px[x + 1, y] = ROCK_LIT

    spacing = [14, 18, 12, 16, 20, 13, 17, 15, 19, 12, 16]
    lengths = [1.0, 0.7, 0.9, 0.55, 1.0, 0.8, 0.6, 0.95, 0.75, 1.0, 0.65]
    x, i = x0 + 6, 0
    while x < x1 - 2:
        length = int(height * lengths[i % len(lengths)])
        crack(x, y0, y0 + length)
        if length < height:
            px[x, y0 + length] = ROCK_SHADE  # punta redondeada
        if lengths[i % len(lengths)] < 0.8:
            mid = x + spacing[i % len(spacing)] // 2
            if mid < x1 - 1:
                crack(mid, y1 - int(height * (0.25 + 0.1 * (i % 3))), y1)
        x += spacing[i % len(spacing)]
        i += 1


def bridge(cx, y_top, y_bottom):
    """Puente de madera vertical de 32 px centrado en cx: tablones, barandillas con postes cada 16 px
    y sombra sobre el agua a la derecha."""
    x0 = cx - 16
    plank = {'K': BLACK, 'B': BROWN, 'b': BEIGE}
    for y in range(y_top, y_bottom):
        row = 'KBBK' + ''.join('B' if (y - y_top) % 4 == 3 else 'b' for _ in range(20)) + 'KBBK'
        draw(x0 + 2, y, [row], plank)
        draw(x0 + 30, y, ['ss'], {'s': WATER_SHADOW}, only_on='water')
    post = ['.KKKK.', 'KbbbbK', 'KBBBBK', 'KBBBBK', '.KKKK.']
    for y in list(range(y_bottom - 7, y_top - 5, -16)):
        draw(x0 + 1, y, post, plank)
        draw(x0 + 25, y, post, plank)


def stairs():
    """Escalera tallada en el acantilado, por donde sube el camino de Chaos a Last Course: peldaños de
    7 px (huella clara, contrahuella marron y raya negra) entre dos paredes negras."""
    px = canvas.load()
    top, bottom = WALL_TOP * T + 5, WALL_FOOT * T + 2  # de la linea del borde de hierba al pie
    left, right = X_STAIRS - 11, X_STAIRS + 10
    for y in range(top, bottom):
        px[left, y] = BLACK
        px[right, y] = BLACK
        for x in range(left + 1, right):
            k = (bottom - 1 - y) % 7
            px[x, y] = BLACK if k == 0 else (BROWN if k <= 4 else BEIGE)
        if px[left + 1, y] != BLACK:
            px[left + 1, y] = ROCK_SHADE  # la pared de la izquierda da sombra
    for x in range(left, right + 1):
        px[x, top] = BLACK


# ------------------------------------------------------------------------------------------ decorado
# (columna, fila, columna_hoja, fila_hoja, ancho, alto)
TREE_A, TREE_B = (3, 5), (5, 5)
HILL_EYES = (2, 10)
SMALL_HILLS = (25, 16)
ROCK_A, ROCK_B = (6, 8), (7, 5)
POND = (12, 7)
DECOR = [
    # isla, a la izquierda: la colina con ojos y arboles
    (6, 25) + HILL_EYES + (4, 4),
    (6, 37) + TREE_A + (2, 2), (8, 38) + TREE_B + (2, 2),
    # entre la tuberia y el puente
    (18, 26) + TREE_A + (2, 2), (20, 27) + TREE_B + (2, 2), (23, 26) + TREE_A + (2, 2),
    (19, 35) + SMALL_HILLS + (2, 2), (26, 34) + TREE_B + (2, 2),
    # entre el cruce y la fila de abajo
    (42, 35) + TREE_A + (2, 2), (44, 36) + TREE_B + (2, 2), (51, 35) + POND + (2, 2),
    # debajo de la meseta, a la derecha
    (66, 30) + TREE_A + (2, 2), (68, 31) + TREE_B + (2, 2), (78, 29) + HILL_EYES + (4, 4),
    (70, 39) + SMALL_HILLS + (2, 2), (86, 36) + TREE_A + (2, 2), (88, 37) + TREE_B + (2, 2),
    (90, 29) + TREE_A + (2, 2),
    # en la meseta
    (64, 8) + TREE_A + (2, 2), (66, 9) + TREE_B + (2, 2), (84, 8) + SMALL_HILLS + (2, 2),
    (68, 14) + TREE_B + (2, 2), (86, 14) + TREE_A + (2, 2),
    # rocas en el mar
    (9, 8) + ROCK_A + (2, 2), (22, 15) + ROCK_B + (2, 2), (46, 3) + ROCK_A + (2, 2),
    (7, 54) + ROCK_B + (2, 2), (38, 55) + ROCK_A + (2, 2), (78, 55) + ROCK_B + (2, 2),
]
# detalles sueltos de 8x8 sobre la hierba (matas, flores y piedrecitas de la meseta redonda)
BITS = [
    (11, 30, 9, 9), (28, 30, 14, 9), (16, 41, 11, 7), (38, 40, 13, 9), (55, 40, 14, 8), (64, 46, 9, 9),
    (75, 34, 12, 10), (93, 42, 14, 9), (24, 46, 13, 9), (46, 46, 11, 7), (84, 46, 9, 9), (64, 28, 12, 10),
    (73, 15, 13, 9), (90, 14, 11, 7), (57, 9, 9, 9), (79, 15, 14, 8),
]


def decorate():
    for col, row, c, r, w, h in DECOR:
        stamp(col, row, c, r, w, h)
    for col, row, c, r in BITS:
        put(col, row, c, r)


def compose():
    island()
    plateau()
    decorate()
    stairs()
    bridge(X_BRIDGE, 0, ISLAND_TOP * T + 6)


# ------------------------------------------------------------------------------------------ salida
def normalized(tile):
    """Bytes RGBA con los pixeles transparentes a 0, para comparar tiles."""
    return bytes(b for p in tile.getdata() for b in ((0, 0, 0, 0) if p[3] == 0 else p))


def smw_lookup():
    base = os.path.join(IMAGES, *SMW_KEY.split('/'))
    img = Image.open(base + '.png').convert('RGBA')
    table = {}
    for sub in ET.parse(base + '.xml').getroot().iter('SubTexture'):
        x, y, w, h = (int(sub.get(k)) for k in ('x', 'y', 'width', 'height'))
        if w == T and h == T:
            table.setdefault(normalized(img.crop((x, y, x + T, y + T))), sub.get('name'))
    return table


def slice_tiles():
    """Trocea el lienzo: [(x, y, imagen, fotograma)] y los tiles propios {nombre: tile}."""
    smw = smw_lookup()
    own = {}
    names = {}
    sprites = []
    for row in range(ROWS):
        for col in range(COLS):
            tile = canvas.crop((col * T, row * T, col * T + T, row * T + T))
            if tile.getextrema()[3][1] == 0:
                continue  # mar
            key = normalized(tile)
            if key in smw:
                sprites.append((col * T, row * T, SMW_KEY, smw[key]))
                continue
            if key not in names:
                names[key] = 'w1_%04d' % len(names)
                own[names[key]] = tile
            sprites.append((col * T, row * T, OWN_KEY, names[key]))
    return sprites, own


def write_own_atlas(own, out_dir):
    per_row = 16
    rows = max(1, (len(own) + per_row - 1) // per_row)
    atlas = Image.new('RGBA', (per_row * T, rows * T), (0, 0, 0, 0))
    xml = ['<?xml version="1.0" encoding="utf-8"?>', '<TextureAtlas imagePath="tiles.png">']
    for i, name in enumerate(sorted(own)):
        x, y = (i % per_row) * T, (i // per_row) * T
        atlas.paste(own[name], (x, y))
        xml.append('\t<SubTexture name="%s" x="%d" y="%d" width="%d" height="%d" frameX="0" frameY="0" frameWidth="%d" frameHeight="%d"/>'
                   % (name, x, y, T, T, T, T))
    xml.append('</TextureAtlas>')
    os.makedirs(out_dir, exist_ok=True)
    atlas.save(os.path.join(out_dir, 'tiles.png'))
    with open(os.path.join(out_dir, 'tiles.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(xml) + '\n')


def sparrow_frame(key, name):
    base = os.path.join(IMAGES, *key.split('/'))
    img = Image.open(base + '.png').convert('RGBA')
    for sub in ET.parse(base + '.xml').getroot().iter('SubTexture'):
        if sub.get('name').startswith(name):
            x, y, w, h = (int(sub.get(k)) for k in ('x', 'y', 'width', 'height'))
            return img.crop((x, y, x + w, y + h))
    return None


def preview(nodes, paths, out):
    """Vista previa a escala 2: mar, tiles, puntitos de los caminos, nodos y BF en el inicio."""
    sea = cell(0, 0)
    img = Image.new('RGBA', canvas.size)
    for y in range(0, canvas.height, T):
        for x in range(0, canvas.width, T):
            img.paste(sea, (x, y))
    img.alpha_composite(canvas)
    dot = sparrow_frame('overworld/dot', 'idle')
    by_id = {n['id']: n for n in nodes}
    for pth in paths:
        pts = [(by_id[pth['a']]['x'], by_id[pth['a']]['y'])] + [tuple(p) for p in pth['points']] + [(by_id[pth['b']]['x'], by_id[pth['b']]['y'])]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            length = max(abs(bx - ax), abs(by - ay))
            for d in range(16, int(length), 16):
                x, y = ax + (bx - ax) * d / length, ay + (by - ay) * d / length
                img.alpha_composite(dot, (int(x - dot.width / 2), int(y - dot.height / 2)))
    for n in nodes:
        spr = sparrow_frame(n['image'], n['anim'])
        if spr is not None:
            img.alpha_composite(spr, (int(n['x'] - spr.width / 2), int(n['y'] - spr.height / 2)))
    bf = sparrow_frame('overworld/overworld_bf', 'overworld bf walk down')
    start = by_id['inicio']
    img.alpha_composite(bf, (int(start['x'] - bf.width / 2), int(start['y'] - bf.height + 4)))
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(out)
    print('vista previa -> ' + out)


def world_json(world):
    """JSON con nodos y caminos legibles y un decorado por linea (son miles de tiles: indentados
    eran mas de 40.000 lineas)."""
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


def main(args):
    dry = '--dry-run' in args
    files = [a for a in args if not a.startswith('--')]

    compose()
    nodes, paths = graph()
    sprites, own = slice_tiles()
    print('%d tiles (%d propios)' % (len(sprites), len(own)))
    if files:
        preview(nodes, paths, files[0])
    if dry:
        return

    world = {
        'displayName': 'Mundo 1',
        'bg': 'overworld/backgrounds/smw_sea', 'bgAnim': 'idle', 'bgFps': 4, 'bgTile': True,
        'music': 'freakyMenu', 'zoom': 3, 'gridSize': 8, 'startNode': 'inicio',
        'player': 'overworld/overworld_bf', 'walkSpeed': 60,
        'nodes': nodes,
        'sprites': [{'image': image, 'anim': anim, 'fps': 0, 'x': x, 'y': y, 'flipX': False, 'flipY': False,
                     'scale': 1, 'alpha': 1, 'front': False} for x, y, image, anim in sprites],
        'paths': paths,
    }
    own_dir = os.path.join(IMAGES, 'overworld', 'world1')
    write_own_atlas(own, own_dir)
    text = world_json(world)
    json.loads(text)  # que siga siendo JSON valido
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('-> ' + OUT)
    print('-> ' + own_dir)

    for kind in ('debug', 'release'):
        build = os.path.join(ROOT, 'export', kind, 'windows', 'bin', 'assets', 'shared')
        if os.path.isdir(build):
            shutil.copyfile(OUT, os.path.join(build, 'overworlds', 'world1.json'))
            build_own = os.path.join(build, 'images', 'overworld', 'world1')
            os.makedirs(build_own, exist_ok=True)
            for name in ('tiles.png', 'tiles.xml'):
                shutil.copyfile(os.path.join(own_dir, name), os.path.join(build_own, name))
            print('-> ' + build)


if __name__ == '__main__':
    main(sys.argv[1:])
