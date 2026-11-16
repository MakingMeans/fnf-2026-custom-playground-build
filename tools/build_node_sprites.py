"""Sprites de nodo sacados de los tiles de nivel de Super Mario World (og_mario/level_tiles 16x16 y level_blocks
32x32), cada uno en su propio atlas como los de Mario's Madness (overworld/castle, star, pipe...), para elegirlos
como aspecto de un nodo en el editor.

Uso:  python tools/build_node_sprites.py
Escribe assets/shared/images/overworld/nodes/<nombre>.png/.xml y los copia a las builds (export/*/.../bin).
Cada animacion es "<anim>0000", "<anim>0001"...: el nodo usa `anim` y, si tiene, `animDone` al superarlo
(castillos y fortalezas derrumbados, interruptores pulsados, puerta abierta). Ojo con los prefijos: una animacion
no puede empezar como otra ("yellow" y "yellow_pressed" chocarian), por eso las pulsadas son "pressed_<color>".
"""
import os
import shutil
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ROOT, 'assets', 'shared', 'images', 'overworld')
OUT = os.path.join(IMAGES, 'nodes')

# nombre -> {animacion: [(atlas, tile), ...]}; 'T' = level_tiles (16x16), 'B' = level_blocks (32x32)
NODES = {
    'smw_yoshi_house': {'idle': [('T', 7)]},                       # la casa de Yoshi azul (punto de partida)
    'smw_ghost_house': {'idle': [('T', 41)]},                      # casa fantasma
    'smw_house': {'idle': [('T', 42)]},                            # la casa marron (como la del Top Secret Area)
    'smw_castle': {'idle': [('T', 8)], 'dead': [('T', 49)]},       # castillo; superado, derrumbado con la bandera
    'smw_fortress': {'idle': [('T', 28)], 'dead': [('T', 23)]},    # torre de fortaleza; superada, en ruinas
    'smw_boss_castle': {'idle': [('B', 5)]},                       # castillo grande de torres (32x32)
    'smw_bowser_castle': {'idle': [('B', 17)]},                    # la puerta del castillo de Bowser con su escalera (32x32)
    'smw_switch': {                                                # palacios de los interruptores; superado, pulsado
        'yellow': [('T', 68)], 'pressed_yellow': [('T', 69)],
        'green': [('T', 77)], 'pressed_green': [('T', 78)],
        'red': [('T', 86)], 'pressed_red': [('T', 87)],
        'blue': [('T', 75)], 'pressed_blue': [('T', 76)],
    },
    'smw_star': {'idle': [('T', 6), ('T', 40), ('T', 48), ('T', 40)]},   # estrella que brilla
    'smw_pipe': {'idle': [('T', 24)]},
    'smw_door': {'closed': [('T', 57)], 'open': [('T', 58)]},     # puerta azul (cerrada / abierta)
    'smw_dirt_level': {                                            # nivel en un hoyo de tierra (Vanilla Dome)
        'yellow': [('T', 4), ('T', 20), ('T', 38), ('T', 59)],
        'red': [('T', 5), ('T', 21), ('T', 39), ('T', 60)],
    },
}


def load_atlas(name):
    base = os.path.join(IMAGES, 'og_mario', name)
    img = Image.open(base + '.png').convert('RGBA')
    tiles = {}
    for sub in ET.parse(base + '.xml').getroot().iter('SubTexture'):
        x, y, w, h = (int(sub.get(k)) for k in ('x', 'y', 'width', 'height'))
        tiles[int(sub.get('name')[-4:])] = img.crop((x, y, x + w, y + h))
    return tiles


def write_atlas(name, frames):
    """Atlas Sparrow en fila: frames = [(nombre, imagen)], todas del mismo tamano."""
    fw, fh = frames[0][1].size
    atlas = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
    xml = ['<?xml version="1.0" encoding="utf-8"?>', '<TextureAtlas imagePath="%s.png">' % name]
    for i, (frame_name, img) in enumerate(frames):
        atlas.paste(img, (i * fw, 0))
        xml.append('\t<SubTexture name="%s" x="%d" y="0" width="%d" height="%d"/>' % (frame_name, i * fw, fw, fh))
    xml.append('</TextureAtlas>')
    atlas.save(os.path.join(OUT, name + '.png'))
    with open(os.path.join(OUT, name + '.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(xml) + '\n')


def main():
    sources = {'T': load_atlas('level_tiles'), 'B': load_atlas('level_blocks')}
    os.makedirs(OUT, exist_ok=True)
    for name, anims in NODES.items():
        names = list(anims)
        for a in names:
            clash = [b for b in names if b != a and b.startswith(a)]
            if clash:
                raise SystemExit('%s: la animacion "%s" es prefijo de %s' % (name, a, clash))
        frames = [('%s%04d' % (anim, i), sources[kind][tile]) for anim, tiles in anims.items() for i, (kind, tile) in enumerate(tiles)]
        write_atlas(name, frames)
        print('-> overworld/nodes/%s (%s)' % (name, ', '.join(names)))
    for kind in ('debug', 'release'):
        build = os.path.join(ROOT, 'export', kind, 'windows', 'bin', 'assets', 'shared', 'images', 'overworld')
        if os.path.isdir(build):
            dest = os.path.join(build, 'nodes')
            if os.path.isdir(dest):
                shutil.rmtree(dest)
            shutil.copytree(OUT, dest)


if __name__ == '__main__':
    main()
