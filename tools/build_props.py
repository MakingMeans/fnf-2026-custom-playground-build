"""Biblioteca de decorados enteros ("props") para el editor del overworld.

Uso:  python tools/build_props.py [hoja_de_contactos.png]
Necesita Pillow, numpy y scipy. Solo lee las fuentes (la hoja de SMW del repo y el arte de los mapas de
Mario's Madness) y escribe un atlas Sparrow por tema en assets/shared/images/overworld/props/:
<tema>.png + <tema>.xml, con un fotograma "<nombre>0000" por objeto (recorte justo, fondo transparente,
tamano original). Con un argumento, guarda tambien una hoja de contactos (todo a x3 con su nombre).

Temas:
  smw_green, smw_forest, smw_snow, smw_desert, smw_cave   bloques de paleta de la hoja de SMW
  mm_forest, mm_star, mm_fortress, mm_castle, mm_pipes     mapas 2-6 de Mario's Madness
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'assets', 'shared', 'images', 'overworld', 'props')
SHEET = os.path.join(ROOT, 'art', 'overworld_source', 'smw_overworld_tiles.png')
MM = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets/images/warpzone'

ORANGE = (255, 178, 127)  # fondo de la hoja de SMW (y de sus lineas de rejilla)
ATLAS_W = 512


# ---------------------------------------------------------------- utilidades

def load_rgba(path):
    return np.array(Image.open(path).convert('RGBA'))


def color_mask(arr, colors, tol=2):
    """Pixeles de fondo: transparentes o de uno de esos colores (la hoja tiene variantes de 1 unidad,
    p. ej. (64, 136, 247) y (64, 136, 248))."""
    rgb = arr[..., :3].astype(int)
    mask = arr[..., 3] == 0
    for c in colors:
        mask |= (np.abs(rgb - np.array(c)).max(axis=2) <= tol)
    return mask


def flood_border(bg):
    """De la mascara de fondo, lo conectado (4 vecinos) con el borde de la imagen."""
    lab, n = ndimage.label(bg)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(edge))


def scan_border(bg, sides='ltr'):
    """Fondo visible en linea recta desde los lados pedidos (l, r, t, b): no se cuela por debajo de
    un objeto que se funde con el suelo (las colinas no tienen contorno abajo)."""
    h, w = bg.shape
    out = np.zeros_like(bg)
    if 'l' in sides:
        out |= np.cumprod(bg, axis=1).astype(bool)
    if 'r' in sides:
        out |= np.cumprod(bg[:, ::-1], axis=1)[:, ::-1].astype(bool)
    if 't' in sides:
        out |= np.cumprod(bg, axis=0).astype(bool)
    if 'b' in sides:
        out |= np.cumprod(bg[::-1], axis=0)[::-1].astype(bool)
    return out


def clear_background(arr, colors, mode='flood', sides='ltr'):
    """Deja transparente el fondo: 'flood' (lo unido al borde), 'scan' (visto desde los lados) o
    'all' (todo pixel de esos colores)."""
    arr = arr.copy()
    bg = color_mask(arr, colors)
    if mode == 'flood':
        gone = flood_border(bg)
    elif mode == 'scan':
        gone = scan_border(bg, sides)
    else:
        gone = bg
    arr[gone] = (0, 0, 0, 0)
    return arr


def despeckle(arr, min_size=0, largest=False):
    """Quita islas sueltas de pixeles (8 vecinos): las menores de min_size, o todo salvo la mayor."""
    opaque = arr[..., 3] > 0
    lab, n = ndimage.label(opaque, structure=np.ones((3, 3)))
    if n == 0:
        return arr
    sizes = ndimage.sum(opaque, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    if largest:
        keep[1 + int(np.argmax(sizes))] = True
    else:
        keep[1:] = sizes >= min_size
    arr = arr.copy()
    arr[~keep[lab]] = (0, 0, 0, 0)
    return arr


def prune(arr):
    """Quita rayas sueltas de 1 px (bordes de caminos que se meten en el objeto): borra, hasta que no
    cambie nada, los pixeles con un solo vecino opaco (4 vecinos) o ninguno."""
    arr = arr.copy()
    while True:
        op = np.pad(arr[..., 3] > 0, 1)
        neigh = (op[:-2, 1:-1].astype(int) + op[2:, 1:-1] + op[1:-1, :-2] + op[1:-1, 2:])
        loose = op[1:-1, 1:-1] & (neigh <= 1)
        if not loose.any():
            return arr
        arr[loose] = (0, 0, 0, 0)


def trim(arr):
    ys, xs = np.nonzero(arr[..., 3])
    if len(ys) == 0:
        raise ValueError('objeto vacio')
    return arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ---------------------------------------------------------------- hoja de SMW

def smw_cell_box(c, r):
    """Celda (columna, fila) de la hoja: 8x8 con paso 9. Desde la fila 42 todo sube 1 px y desde la
    columna 54 todo va 1 px a la izquierda (la fila 41 y la columna 53 miden 7)."""
    x = c * 9 if c <= 53 else c * 9 - 1
    y = r * 9 if r <= 41 else r * 9 - 1
    return x, y, (7 if c == 53 else 8), (7 if r == 41 else 8)


def smw_cells(sheet, c0, r0, c1, r1, skip=()):
    """Junta las celdas c0..c1 x r0..r1 sin las lineas de rejilla. `skip` = celdas (c, r) que no
    son del objeto (quedan transparentes)."""
    out = np.zeros(((r1 - r0 + 1) * 8, (c1 - c0 + 1) * 8, 4), np.uint8)
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            if (c, r) in skip:
                continue
            x, y, w, h = smw_cell_box(c, r)
            out[(r - r0) * 8:(r - r0) * 8 + h, (c - c0) * 8:(c - c0) * 8 + w] = sheet[y:y + h, x:x + w]
    return out


def mirror_quadrant(arr, quad):
    """Rehace un objeto simetrico desde un cuadrante limpio ('tl', 'tr', 'bl', 'br'): los discos de la
    hoja tienen una esquina pisada por la pieza de al lado."""
    h, w = arr.shape[:2]
    hh, hw = h // 2, w // 2
    y0 = 0 if quad[0] == 't' else h - hh
    x0 = 0 if quad[1] == 'l' else w - hw
    q = arr[y0:y0 + hh, x0:x0 + hw]
    if quad[1] == 'r':
        q = q[:, ::-1]
    if quad[0] == 'b':
        q = q[::-1]
    top = np.concatenate([q, q[:, ::-1]], axis=1)
    return np.concatenate([top, top[::-1]], axis=0)


# Colores de fondo fijos (clave de una letra en las listas de abajo)
WATER = [(64, 136, 248), (32, 48, 112)]
FIXED_BG = {
    'W': WATER,
    'C': [(248, 232, 176)],          # arena clara de los caminos
    'N': [(56, 48, 88)],             # cielo nocturno del bloque de nieve
    'K': [(13, 13, 14), (0, 0, 0)],  # negro de la zona de la estrella y de las cuevas
    'S': [(247, 247, 247)],          # nieve/hielo del bloque de nieve
}

# Bloques de paleta: esquina (columna, fila) en la hoja y sus colores de suelo. G = hierba (el relleno
# liso), T = tierra (el suelo de los bosques y caminos); W solo si el bloque cambia el agua.
SMW_BLOCKS = {
    'smw_green': ((0, 0), {'G': [(64, 208, 32)], 'T': [(216, 152, 96)]}),
    'smw_forest': ((27, 0), {'G': [(120, 184, 64)], 'T': [(168, 152, 48)]}),
    'smw_snow': ((0, 21), {'G': [(168, 240, 200)], 'T': [(160, 136, 200)],
                           'W': WATER + [(247, 247, 247)]}),  # aqui el mar es hielo blanco
    'smw_desert': ((27, 21), {'G': [(215, 199, 167)], 'T': [(216, 152, 96)]}),
    'smw_cave': ((0, 42), {'G': [(136, 184, 192)], 'T': [(49, 71, 95)]}),
}

# Objetos que repite cada bloque en el mismo sitio: nombre, celdas (c0, r0, c1, r1) relativas al bloque,
# fondo (letras) y opciones. 'scan' = colinas que se funden con el suelo por abajo.
SMW_COMMON = {
    'hill_eyes_big': ((2, 10, 5, 13), 'GW', {'mode': 'scan'}),
    'hill_eyes_small': ((23, 16, 24, 17), 'GW', {'mode': 'scan'}),
    'tree_round': ((5, 5, 6, 6), 'G', {}),
    'rock_sea': ((7, 5, 8, 6), 'W', {}),
    'pond_round': ((12, 7, 13, 8), 'G', {}),
    'pond_small': ((13, 9, 13, 9), 'G', {}),
    'rock_wedge': ((10, 9, 11, 10), 'G', {}),
    'pebbles': ((9, 8, 9, 8), 'G', {}),
    'rock_small': ((14, 9, 14, 9), 'G', {}),
    'bush_small': ((14, 8, 14, 8), 'G', {}),
    'bush_tall': ((9, 9, 9, 9), 'G', {}),
    'stone_post': ((13, 10, 13, 10), 'G', {}),
    'grass_tuft': ((11, 7, 11, 7), 'G', {}),
    'plateau_small': ((15, 18, 16, 19), 'G', {}),
    'round_mound': ((16, 12, 22, 18), 'G', {'quad': 'tl'}),
    'round_clearing': ((20, 7, 26, 13), 'G', {'quad': 'tl'}),
}


def common(*names, **renames):
    """Entradas de SMW_COMMON por nombre (renames: nombre_nuevo='nombre_comun')."""
    out = [(n,) + SMW_COMMON[n] for n in names]
    out += [(new,) + SMW_COMMON[old] for new, old in renames.items()]
    return out


# Por tema: (nombre, celdas, fondo, opciones). Opciones: 'abs' = celdas absolutas de la hoja (fuera del
# bloque); 'skip' = celdas que no son del objeto; 'prune' = quitar rayas sueltas de 1 px; 'min_size' =
# quitar islas de menos pixeles; 'quad' = rehacer desde un cuadrante (objetos simetricos).
SMW_THEMES = {
    'smw_green': common(*SMW_COMMON) + [
        ('bowser_valley', (21, 0, 26, 6), 'GW', {'min_size': 6}),
        # bosques con laguna: arriba y abajo les entran caminos, cuyos bordes quedarian como rayas
        ('forest_pond_big', (2, 1, 9, 4), 'TCG', {'skip': [(9, 4)], 'prune': True}),
        ('forest_pond_small', (10, 2, 13, 3), 'TCG', {'prune': True}),
        ('pillar_plain', (6, 8, 6, 9), 'W', {}),
        ('pillar_ringed', (7, 8, 7, 9), 'W', {}),
    ],
    'smw_forest': common(*SMW_COMMON) + [
        ('tree_big_eyes', (5, 2, 8, 4), 'G', {}),
    ],
    'smw_snow': common(*[n for n in SMW_COMMON if n != 'rock_sea']) + [
        ('ice_mound', (7, 5, 8, 6), 'GS', {}),
        ('moon_crescent', (23, 0, 25, 2), 'N', {}),
        ('spike_small', (21, 2, 22, 3), 'N', {}),
        ('spike_tall', (21, 4, 22, 6), 'N', {}),
        ('twinkle_small', (26, 2, 26, 2), 'N', {}),
        ('twinkle_big', (26, 3, 26, 3), 'N', {}),
        ('twinkle_gold', (26, 4, 26, 4), 'N', {}),
        ('star_ring', (56, 6, 61, 12), 'K', {'abs': True, 'min_size': 8}),
        ('sparkle_gold', [(54, 0, 55, 0), (54, 15, 55, 15)], 'K', {'abs': True}),
        ('sparkle_cyan', (54, 7, 55, 8), 'K', {'abs': True}),
    ],
    'smw_desert': common(*[n for n in SMW_COMMON if n != 'tree_round']) + [
        ('rock_mound', (5, 4, 6, 5), 'G', {}),
    ],
    'smw_cave': common('pond_round', 'pond_small', 'bush_small', 'grass_tuft', 'plateau_small',
                       'round_mound', 'round_clearing', rock_dome='bush_tall') + [
        ('rock_sea', (6, 5, 7, 6), 'W', {}),
        ('rock_mound', (4, 5, 5, 6), 'G', {}),
        ('spike_small', (21, 2, 22, 3), 'K', {}),
        ('spike_tall', (21, 4, 22, 6), 'K', {}),
        ('star_cross_big', (3, 0, 3, 0), 'T', {}),
        ('star_cross_gold', (2, 3, 2, 3), 'T', {}),
        ('star_cross_gray', (2, 2, 2, 2), 'T', {}),
    ],
}


def smw_piece(sheet, theme, box, bg, opts):
    (bc, br), colors = SMW_BLOCKS[theme]
    off = (0, 0) if opts.get('abs') else (bc, br)
    boxes = box if isinstance(box, list) else [box]
    parts = []
    for c0, r0, c1, r1 in boxes:
        skip = [(c + off[0], r + off[1]) for c, r in opts.get('skip', ())]
        parts.append(smw_cells(sheet, c0 + off[0], r0 + off[1], c1 + off[0], r1 + off[1], skip))
    arr = np.concatenate(parts, axis=0)  # varias cajas = trozos apilados (mitades de un brillo)
    if opts.get('quad'):
        arr = mirror_quadrant(arr, opts['quad'])
    cols = [ORANGE]
    for key in bg:
        cols += colors.get(key) or FIXED_BG[key]
    arr = clear_background(arr, [ORANGE], 'all')
    arr = clear_background(arr, cols, opts.get('mode', 'flood'), opts.get('sides', 'ltr'))
    if opts.get('prune'):
        arr = prune(arr)
    if opts.get('min_size'):
        arr = despeckle(arr, opts['min_size'])
    return trim(arr)


def build_smw():
    sheet = load_rgba(SHEET)
    themes = {}
    for theme, items in SMW_THEMES.items():
        themes[theme] = [(name, smw_piece(sheet, theme, box, bg, opts)) for name, box, bg, opts in items]
    return themes


# ---------------------------------------------------------------- Mario's Madness

def mm(path):
    return load_rgba(MM + '/' + path)


def mm_piece(src, rect, bg=(), mode='flood', sides='ltr', largest=False, min_size=0):
    """Recorta rect = (x0, y0, x1, y1) (x1, y1 excluidos) y quita el fondo."""
    x0, y0, x1, y1 = rect
    arr = src[y0:y1, x0:x1]
    arr = clear_background(arr, list(bg), mode, sides)
    if largest or min_size:
        arr = despeckle(arr, min_size, largest)
    return trim(arr)


FOREST_GROUND = [(120, 184, 64), (40, 176, 16)]  # suelo y matas "+" del bosque (mapa 2)
NIGHT_SKY = [(56, 48, 88)]                        # cielo del camino de estrellas (mapa 3)
FORTRESS_GROUND = [(152, 136, 104), (128, 112, 80), (104, 88, 56)]  # tierra y su borde (mapa 4)
GROUND_FLAT = FORTRESS_GROUND[:1]  # solo la tierra lisa: las matas "^" usan el tono del borde


def star_pillar(src, height):
    """Columna con estrella del mapa 3. Solo la de arriba al centro tiene la punta limpia (las otras se
    tapan entre si): su capitel (filas 52-106, sin la pestana torcida de 1-2 px de los lados) y debajo
    se repite la fila del cuerpo hasta la altura pedida (las del mod miden 68, ~100 y ~130)."""
    top = src[52:107, 101:154]
    body = np.repeat(src[106:107, 101:154], height - top.shape[0], axis=0)
    return trim(np.concatenate([top, body], axis=0))


def pipe(src, rect):
    """Tuberia del mapa 6: se hunde en el negro con un tramado. El negro del tramado y el de debajo se
    vuelven transparentes (la tuberia se desvanece); el contorno y la boca se quedan."""
    x0, y0, x1, y1 = rect
    area = src[y0:y1, x0:x1]
    green = (area[..., 3] > 0) & (area[..., :3].max(axis=2) > 0)
    ys, xs = np.nonzero(green)
    gx0, gx1, gy0, gy1 = xs.min() - 1, xs.max() + 1, ys.min() - 1, ys.max()
    arr = area[gy0:gy1 + 1, gx0:gx1 + 1].copy()
    black = (arr[..., 3] > 0) & (arr[..., :3].max(axis=2) == 0)
    inner = black[:, 2:-2].any(axis=1)  # negro por dentro: la boca arriba, el tramado abajo
    # el tramado empieza donde acaba el tramo mas largo de filas sin negro por dentro (el cuerpo liso)
    best, run, fade = 0, 0, len(inner)
    for y, has_black in enumerate(inner):
        run = 0 if has_black else run + 1
        if run > best:
            best, fade = run, y + 1
    arr[fade:][black[fade:]] = (0, 0, 0, 0)
    return trim(arr)


def castle_big():
    """El castillo del mapa 5 entero: bg2 con su anillo delantero (bg3) encima."""
    img = Image.fromarray(mm('5/bg2.png'), 'RGBA')
    img.alpha_composite(Image.fromarray(mm('5/bg3.png'), 'RGBA'))
    return trim(np.array(img))


def castle_tower_tan():
    """Torre pequena de la derecha del castillo: el muro tapa su contorno izquierdo en las filas
    104-117; se repone en negro."""
    arr = mm('5/bg2.png')[73:119, 186:210].copy()
    for y in range(arr.shape[0]):
        if arr[y, 0, 3]:
            arr[y, 0] = (0, 0, 0, 255)
    return trim(arr)


def castle_tower_gray():
    """Torre gris de la izquierda: el muro del castillo le tapa el lado derecho; la ultima columna
    del recorte es su contorno donde se ve y muro donde no (ese muro se quita)."""
    arr = mm('5/bg2.png')[110:170, 49:72].copy()
    edge = arr[:, -1]
    edge[edge[:, :3].max(axis=1) > 0] = (0, 0, 0, 0)
    return trim(arr)


def build_mm():
    forest, lava, fog = mm('2/bg1.png'), mm('2/bg2.png'), mm('2/bg3.png')
    sky, pillars = mm('3/bg1.png'), mm('3/bg2.png')
    fortress, ash, pipes = mm('4/bg2.png'), mm('5/bg1.png'), mm('6/1.png')
    return {
        'mm_forest': [
            ('tree_big', mm_piece(forest, (141, 70, 173, 94), FOREST_GROUND, largest=True)),
            ('tree_small', mm_piece(forest, (160, 111, 176, 127), FOREST_GROUND, largest=True)),
            ('trees_trio', mm_piece(forest, (63, 63, 103, 95), FOREST_GROUND, largest=True)),
            ('bush_round', mm_piece(forest, (219, 62, 227, 70), FOREST_GROUND, largest=True)),
            ('bush_pair', mm_piece(forest, (127, 62, 135, 78), FOREST_GROUND, largest=True)),
            ('lake_blue', mm_piece(forest, (84, 79, 159, 185), FOREST_GROUND, largest=True)),
            ('lake_lava', mm_piece(lava, (0, 0, 256, 249))),
            ('fog_small', mm_piece(fog, (203, 31, 225, 43), largest=True)),
            ('fog_double', mm_piece(fog, (27, 0, 65, 19), largest=True)),
            ('fog_long', mm_piece(fog, (3, 127, 49, 147), largest=True)),
        ],
        'mm_star': [
            ('star_pillar_short', star_pillar(pillars, 68)),
            ('star_pillar_mid', star_pillar(pillars, 100)),
            ('star_pillar_tall', star_pillar(pillars, 132)),
            ('moon_crescent', mm_piece(sky, (20, 40, 60, 80), NIGHT_SKY)),
            ('twinkle_small', mm_piece(sky, (196, 53, 206, 63), NIGHT_SKY)),
            ('twinkle_big', mm_piece(sky, (256 + 70, 59, 256 + 84, 73), NIGHT_SKY)),
            ('cloud_bank', mm_piece(sky, (0, 120, 256, 249), NIGHT_SKY)),
        ],
        'mm_fortress': [
            ('fortress_island', trim(fortress)),
            ('tower_glow_short', mm_piece(fortress, (50, 75, 82, 132), FORTRESS_GROUND, 'scan', 'lrb')),
            ('tower_glow_tall', mm_piece(fortress, (258, 67, 290, 156), FORTRESS_GROUND, 'scan', 'lrb')),
            ('tower_flat', mm_piece(fortress, (146, 43, 194, 132), FORTRESS_GROUND, 'scan', 'lrb')),
            ('rock_wedge_single', mm_piece(fortress, (248, 159, 268, 179), GROUND_FLAT, largest=True)),
            ('rock_wedge_pair', mm_piece(fortress, (112, 129, 147, 162), GROUND_FLAT, largest=True)),
            ('pebble_pile', mm_piece(fortress, (73, 171, 108, 204), GROUND_FLAT, min_size=10)),
            ('pebble_dark', mm_piece(fortress, (90, 131, 98, 139), GROUND_FLAT, largest=True)),
            ('pebble_light', mm_piece(fortress, (82, 131, 90, 140), GROUND_FLAT, largest=True)),
            ('ground_tuft', mm_piece(fortress, (121, 123, 130, 130), GROUND_FLAT, largest=True)),
        ],
        'mm_castle': [
            ('castle_big', castle_big()),
            ('tower_tan', castle_tower_tan()),
            ('tower_gray', castle_tower_gray()),
            ('bowser_mark', trim(mm('5/bose.png'))),
            ('ash_rock', mm_piece(ash, (215, 136, 221, 144), [(96, 120, 144)], largest=True)),
        ],
        'mm_pipes': [
            ('pipe_stub', pipe(pipes, (214, 110, 231, 140))),
            ('pipe_mid', pipe(pipes, (85, 46, 102, 125))),
            ('pipe_tall', pipe(pipes, (14, 0, 31, 90))),
            ('pipe_giant', pipe(pipes, (56, 19, 73, 125))),
        ],
    }


# ---------------------------------------------------------------- salida

NAME_RE = re.compile(r'^[a-z_]+$')


def check_names(theme, frames):
    names = [n for n, _ in frames]
    assert len(set(names)) == len(names), '%s: nombres repetidos' % theme
    for n in names:
        assert NAME_RE.match(n), '%s: nombre no valido %r' % (theme, n)
        for m in names:
            assert n == m or not m.startswith(n), '%s: %r es prefijo de %r' % (theme, n, m)


def write_packed_atlas(name, frames, width=ATLAS_W, folder=OUT_DIR):
    """Atlas Sparrow con fotogramas de distinto tamano, en filas con 1 px de separacion. frames =
    [(nombre, array RGBA)]; cada uno queda como "<nombre>0000". Se colocan de mas alto a mas bajo."""
    frames = sorted(frames, key=lambda f: (-f[1].shape[0], f[0]))
    width = min(width, max(sum(a.shape[1] + 1 for _, a in frames) - 1, max(a.shape[1] for _, a in frames)))
    x = y = row_h = 0
    places = []
    for frame_name, arr in frames:
        h, w = arr.shape[:2]
        if x and x + w > width:
            x, y, row_h = 0, y + row_h + 1, 0
        places.append((frame_name, arr, x, y))
        x += w + 1
        row_h = max(row_h, h)
    atlas = Image.new('RGBA', (width, y + row_h), (0, 0, 0, 0))
    xml = ['<?xml version="1.0" encoding="utf-8"?>', '<TextureAtlas imagePath="%s.png">' % name]
    for frame_name, arr, fx, fy in places:
        atlas.paste(Image.fromarray(np.ascontiguousarray(arr), 'RGBA'), (fx, fy))
        xml.append('\t<SubTexture name="%s0000" x="%d" y="%d" width="%d" height="%d"/>'
                   % (frame_name, fx, fy, arr.shape[1], arr.shape[0]))
    xml.append('</TextureAtlas>')
    os.makedirs(folder, exist_ok=True)
    atlas.save(os.path.join(folder, name + '.png'))
    with open(os.path.join(folder, name + '.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(xml) + '\n')
    return atlas.size


def contact_sheet(themes, path, scale=3, width=1600):
    """Hoja de contactos: cada fotograma a x3 sobre gris medio, con "tema/nombre" debajo."""
    cells = [('%s/%s' % (t, n), a) for t, frames in themes.items() for n, a in frames]
    pad, label_h = 10, 12
    x = y = row_h = 0
    places = []
    for label, arr in cells:
        w = max(arr.shape[1] * scale, len(label) * 6)
        h = arr.shape[0] * scale + label_h
        if x and x + w > width:
            x, y, row_h = 0, y + row_h + pad, 0
        places.append((label, arr, x, y))
        x += w + pad
        row_h = max(row_h, h)
    sheet = Image.new('RGBA', (width, y + row_h + pad), (128, 128, 128, 255))
    draw = ImageDraw.Draw(sheet)
    for label, arr, px, py in places:
        img = Image.fromarray(np.ascontiguousarray(arr), 'RGBA')
        img = img.resize((arr.shape[1] * scale, arr.shape[0] * scale), Image.NEAREST)
        sheet.alpha_composite(img, (px, py))
        draw.text((px, py + arr.shape[0] * scale + 1), label, fill=(255, 255, 255, 255))
    sheet.save(path)


def main():
    themes = build_smw()
    themes.update(build_mm())
    for theme, frames in themes.items():
        check_names(theme, frames)
        size = write_packed_atlas(theme, frames)
        print('%-12s %2d objetos  atlas %dx%d' % (theme, len(frames), size[0], size[1]))
    if len(sys.argv) > 1:
        contact_sheet(themes, sys.argv[1])
        print('hoja de contactos:', sys.argv[1])


if __name__ == '__main__':
    main()
