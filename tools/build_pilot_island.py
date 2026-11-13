"""Genera el mundo `pilot_island`: una isla de muestra compuesta con los tiles de SMW.

Compone el mapa a partir de celdas (columna, fila) de la hoja original
art/overworld_source/smw_overworld_tiles.png (celdas de 8x8 separadas por 1 px), busca cada celda
en el atlas del juego (og_mario/overworld_tiles) y escribe:

  assets/shared/overworlds/pilot_island.json           el mundo (decorados = tiles pintados)
  assets/shared/images/overworld/backgrounds/smw_sea   fondo de mar animado hecho con el tile de agua
  <preview>                                            imagen del resultado (opcional)

Uso:  python tools/build_pilot_island.py [preview.png]
Necesita Pillow.
"""
import json
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, 'art', 'overworld_source', 'smw_overworld_tiles.png')
ATLAS = os.path.join(ROOT, 'assets', 'shared', 'images', 'overworld', 'og_mario', 'overworld_tiles')
ATLAS_KEY = 'overworld/og_mario/overworld_tiles'
T = 8

sheet = Image.open(SHEET).convert('RGB')


def cell(c, r):
    return sheet.crop((c * 9, r * 9, c * 9 + T, r * 9 + T))


# ---------------------------------------------------------------- lienzo por capas
W, H = 64, 31  # 512 x 248: dos fondos de ancho, uno de alto
layers = [dict(), dict()]  # 0 = terreno, 1 = decoracion encima


PEACH = sheet.getpixel((8, 0))  # color de los separadores y de las celdas vacias de la hoja


def put(x, y, c, r, layer=0, flip=False):
    if 0 <= x < W and 0 <= y < H:
        layers[layer][(x, y)] = (c, r, flip)


def stamp(x, y, c0, r0, w, h, layer=1):
    """Copia un bloque de la hoja; las celdas vacias (color de fondo de la hoja) se saltan."""
    for dy in range(h):
        for dx in range(w):
            if PEACH in cell(c0 + dx, r0 + dy).getdata():
                continue
            put(x + dx, y + dy, c0 + dx, r0 + dy, layer)


def stamp_rows(x, y, c_origin, rows, layer=1):
    """Como stamp, pero cada fila de la hoja con su propio tramo: [(fila, col_ini, col_fin), ...]."""
    for dy, (r, c0, c1) in enumerate(rows):
        for c in range(c0, c1 + 1):
            put(x + c - c_origin, y + dy, c, r, layer)


GRASS = (10, 7)
SIDE = (2, 12)  # borde izquierdo liso: linea negra vertical


def cap(x0, y0, width, rows):
    """Saliente de hierba encima de una isla: costa curva arriba y lados rectos, sin acantilado.

    La ultima fila pisa la costa de arriba de la isla de debajo, que asi queda unida.
    """
    mid = width - 6
    top = [(2, 17), (3, 17), (4, 17)] + [((11, 6) if i % 2 == 0 else (12, 6)) for i in range(mid)] + [(7, 17), (8, 17), (9, 17)]
    for i, t in enumerate(top):
        put(x0 + i, y0, *t)
    for row in range(1, rows + 1):
        for i in range(width):
            put(x0 + i, y0 + row, *GRASS)
        put(x0, y0 + row, *SIDE)
        put(x0 + width - 1, y0 + row, *SIDE, flip=True)


def island(x0, y0, width, grass_rows):
    """Isla baja estilo SMW: costa curva arriba, lados rectos, y abajo un acantilado con espuma.

    Ocupa `width` tiles de ancho (minimo 8) y grass_rows + 3 de alto.
    """
    assert width >= 8
    mid = width - 6
    # costa de arriba (verde sobre agua): extremos de la colina-lente y centro plano
    top = [(2, 17), (3, 17), (4, 17)] + [((11, 6) if i % 2 == 0 else (12, 6)) for i in range(mid)] + [(7, 17), (8, 17), (9, 17)]
    for i, t in enumerate(top):
        put(x0 + i, y0, *t)
    # hierba, con los lados rectos (el derecho es el izquierdo volteado)
    for row in range(1, grass_rows + 1):
        for i in range(width):
            put(x0 + i, y0 + row, *GRASS)
        put(x0, y0 + row, *SIDE)
        put(x0 + width - 1, y0 + row, *SIDE, flip=True)
    # hierba que acaba sobre el acantilado
    y = y0 + grass_rows + 1
    bottom = [(2, 19), (3, 19), (4, 19)] + [((11, 11) if i % 2 == 0 else (12, 11)) for i in range(mid)] + [(7, 19), (8, 19), (9, 19)]
    for i, t in enumerate(bottom):
        put(x0 + i, y, *t)
    # pie del acantilado con espuma
    foam = [(2, 20), (3, 20), (4, 20)] + [((5, 20) if i % 2 == 0 else (6, 20)) for i in range(mid)] + [(7, 20), (8, 20), (9, 20)]
    for i, t in enumerate(foam):
        put(x0 + i, y + 1, *t)


# La meseta de la hoja: su parte de arriba da al mar y su acantilado baja a la hierba de la isla
PLATEAU = [(6, 9, 14), (7, 8, 15), (8, 8, 15), (9, 8, 15), (10, 8, 15), (11, 8, 15), (12, 8, 15), (13, 9, 14), (14, 11, 12)]
SAND = [(7, 22, 24), (8, 21, 25), (9, 20, 26), (10, 20, 26), (11, 20, 26), (12, 21, 25), (13, 22, 24)]
MEADOW = [(12, 18, 20), (13, 17, 21), (14, 16, 22), (15, 16, 22), (16, 16, 22), (17, 17, 21), (18, 18, 20)]


def scene():
    # isla principal: cuerpo ancho, un saliente bajo a la derecha y la meseta alta a la izquierda
    island(14, 9, 36, 13)
    cap(37, 7, 10, 2)
    stamp_rows(19, 6, 7, PLATEAU, layer=0)  # su fila 9 coincide con la costa de la isla

    # islote con arboles, arriba a la derecha
    island(53, 2, 9, 3)
    stamp(55, 3, 3, 5, 2, 2)
    stamp(58, 3, 5, 5, 2, 2)

    # rocas en el mar
    stamp(4, 6, 6, 8, 2, 2, layer=0)
    stamp(55, 22, 6, 8, 2, 2, layer=0)
    stamp(8, 14, 7, 5, 2, 2, layer=0)
    stamp(40, 27, 7, 5, 2, 2, layer=0)
    stamp(6, 23, 6, 8, 2, 2, layer=0)

    # --- sobre la isla principal
    stamp(15, 12, 2, 10, 4, 4)      # colina con ojos
    stamp(32, 11, 25, 16, 2, 2)     # colinas pequenas
    stamp(21, 18, 25, 16, 2, 2)
    stamp_rows(39, 12, 20, SAND)    # claro de arena
    stamp_rows(27, 14, 16, MEADOW)  # prado oscuro
    stamp(34, 17, 12, 7, 2, 2)      # estanque
    stamp(39, 8, 3, 5, 2, 2)        # arboles
    stamp(42, 9, 5, 5, 2, 2)
    stamp(16, 18, 3, 5, 2, 2)
    stamp(18, 19, 5, 5, 2, 2)
    stamp(46, 19, 3, 5, 2, 2)
    stamp(29, 16, 5, 5, 2, 2)       # arboles dentro del prado
    stamp(31, 17, 3, 5, 2, 2)
    for x, y, c, r in [(24, 17, 9, 9), (36, 14, 9, 9), (37, 20, 14, 8), (24, 20, 11, 7), (33, 21, 12, 9),
                       (47, 15, 9, 8), (30, 12, 14, 9), (47, 12, 13, 9), (20, 16, 12, 10), (36, 11, 11, 7),
                       (17, 16, 12, 9), (30, 21, 9, 8), (44, 21, 14, 9), (28, 12, 12, 9)]:
        put(x, y, c, r, 1)


# ---------------------------------------------------------------- salida
def atlas_lookup():
    img = Image.open(ATLAS + '.png').convert('RGBA')
    table = {}
    for sub in ET.parse(ATLAS + '.xml').getroot().iter('SubTexture'):
        x, y, w, h = (int(sub.get(k)) for k in ('x', 'y', 'width', 'height'))
        if w != T or h != T:
            continue
        tile = img.crop((x, y, x + T, y + T)).convert('RGB')
        table.setdefault(tile.tobytes(), sub.get('name'))
    return table


def frame_name(table, c, r):
    name = table.get(cell(c, r).tobytes())
    if name is None:
        raise SystemExit('La celda (%d, %d) de la hoja no esta en el atlas' % (c, r))
    # el XML numera "tile0042" + "0000": el juego busca por el nombre completo del fotograma
    return name


def build_sea():
    """Fondo de mar: cada fotograma es el tile de agua (columna 0, filas 0-7) repetido."""
    out_dir = os.path.join(ROOT, 'assets', 'shared', 'images', 'overworld', 'backgrounds')
    fw, fh = 256, 248
    frames = [0, 2, 4, 6]
    atlas = Image.new('RGBA', (fw * 2, fh * 2))
    xml = ['<?xml version="1.0" encoding="utf-8"?>', '<TextureAtlas imagePath="smw_sea.png">']
    for i, row in enumerate(frames):
        tile = cell(0, row)
        frame = Image.new('RGB', (fw, fh))
        for y in range(0, fh, T):
            for x in range(0, fw, T):
                frame.paste(tile, (x, y))
        ox, oy = (i % 2) * fw, (i // 2) * fh
        atlas.paste(frame, (ox, oy))
        xml.append('\t<SubTexture name="idle%04d" x="%d" y="%d" width="%d" height="%d"/>' % (i, ox, oy, fw, fh))
    xml.append('</TextureAtlas>')
    atlas.save(os.path.join(out_dir, 'smw_sea.png'))
    with open(os.path.join(out_dir, 'smw_sea.xml'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(xml) + '\n')


def main():
    scene()
    table = atlas_lookup()

    sprites = []
    for layer in layers:
        for (x, y) in sorted(layer, key=lambda p: (p[1], p[0])):
            c, r, flip = layer[(x, y)]
            sprites.append({'image': ATLAS_KEY, 'anim': frame_name(table, c, r), 'fps': 0, 'x': x * T, 'y': y * T,
                            'flipX': flip, 'flipY': False, 'scale': 1, 'alpha': 1, 'front': False})

    world = {
        'displayName': 'Isla piloto',
        'bg': 'overworld/backgrounds/smw_sea', 'bgAnim': 'idle', 'bgFps': 4, 'bgTile': True,
        'music': 'freakyMenu', 'zoom': 3, 'gridSize': 8, 'startNode': 'inicio',
        'player': 'overworld/overworld_bf', 'walkSpeed': 60,
        'nodes': [{'id': 'inicio', 'x': 256, 'y': 140, 'type': 'empty', 'image': 'overworld/dot', 'anim': 'idle', 'animDone': '', 'fps': 6,
                   'name': 'Isla piloto', 'song': '', 'week': '', 'difficulty': '', 'world': '', 'unlocked': True, 'unlocks': []}],
        'sprites': sprites,
        'paths': [],
    }
    build_sea()
    out = os.path.join(ROOT, 'assets', 'shared', 'overworlds', 'pilot_island.json')
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(world, f, indent='\t')
    print('%d tiles -> %s' % (len(sprites), out))

    if len(sys.argv) > 1:
        sea = cell(0, 0)
        preview = Image.new('RGB', (W * T, H * T))
        for y in range(H):
            for x in range(W):
                preview.paste(sea, (x * T, y * T))
        for layer in layers:
            for (x, y), (c, r, flip) in layer.items():
                tile = cell(c, r)
                preview.paste(tile.transpose(Image.FLIP_LEFT_RIGHT) if flip else tile, (x * T, y * T))
        preview.resize((W * T * 3, H * T * 3), Image.NEAREST).save(sys.argv[1])
        print('vista previa -> ' + sys.argv[1])


if __name__ == '__main__':
    main()
