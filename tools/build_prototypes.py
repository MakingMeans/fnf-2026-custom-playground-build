"""Prototipos de diseno para los mundos futuros (solo imagenes, no mundos jugables): cada uno con un ambiente
de los mapas de Mario's Madness o una paleta de la hoja de SMW, pintado con el mismo metodo que el mundo 1
(terreno por codigo con su costa y su acantilado) y decorado con la biblioteca de `images/overworld/props/`.

Uso:  python tools/build_prototypes.py <carpeta_de_salida>
Escribe <carpeta>/<prototipo>.png (a escala 3, como se ve en el juego) y <carpeta>/prototipos.png (todos).
Cuando el usuario elija, el que sea se convierte en un mundo de verdad con su propio build_<mundo>.py.
"""
import math
import os
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_world1 as w1  # noqa: E402  (formas, distancias al borde y los fotogramas de nodos)

W, H = w1.W, w1.H  # una pantalla, como el mundo 1
PROPS_DIR = os.path.join(w1.IMAGES, 'overworld', 'props')
MM = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets/images/warpzone'
BLACK = (13, 12, 13)
ROAD = (248, 232, 176)

# paletas: suelo con sus bandas de costa, motitas, acantilado y su sombra, espuma
PALETTES = {
    'forest': {'ground': (120, 184, 64), 'dark': (40, 128, 48), 'mid': (40, 176, 16), 'speck': (200, 208, 128),
               'cliff': (168, 152, 48), 'cliff_shade': (120, 104, 32), 'foam': (240, 240, 240)},
    'cave': {'ground': (136, 184, 192), 'dark': (49, 71, 95), 'mid': (96, 120, 144), 'speck': (112, 136, 168),
             'cliff': (96, 120, 144), 'cliff_shade': (49, 71, 95), 'foam': None},
    'fortress': {'ground': (96, 120, 143), 'dark': (48, 72, 96), 'mid': (72, 96, 120), 'speck': (136, 160, 176),
                 'cliff': (72, 96, 120), 'cliff_shade': (48, 72, 96), 'foam': (200, 208, 232)},
    'ash': {'ground': (152, 152, 160), 'dark': (88, 88, 104), 'mid': (120, 120, 136), 'speck': (184, 184, 192),
            'cliff': (104, 96, 112), 'cliff_shade': (72, 64, 80), 'foam': None},
    'snow': {'ground': (168, 240, 200), 'dark': (128, 120, 208), 'mid': (247, 247, 247), 'speck': (247, 247, 247),
             'cliff': (160, 136, 200), 'cliff_shade': (128, 120, 208), 'foam': (247, 247, 247)},
    'desert': {'ground': (215, 199, 167), 'dark': (144, 128, 95), 'mid': (168, 152, 119), 'speck': (168, 152, 119),
               'cliff': (216, 152, 96), 'cliff_shade': (184, 120, 72), 'foam': (240, 240, 240)},
}


class Proto:
    """Un lienzo de W x H: fondo, capas de tierra (con su mascara de suelo y de acantilado) y decorados."""

    def __init__(self, background):
        self.img = background.copy()
        self.ground = np.zeros((H, W), bool)
        self.cliffs = np.zeros((H, W), bool)
        self.blocked = np.zeros((H, W), bool)  # carreteras y nodos: ahi no se ponen decorados de relleno

    def setpx(self, x, y, color):
        if 0 <= x < W and 0 <= y < H:
            self.img.putpixel((x, y), color + (255,))

    def land(self, mask, cliff_h, pal, seed=0):
        """Como paint_layer del mundo 1, con la paleta que toque."""
        rng = np.random.default_rng(seed)
        dist = w1.edge_distance(mask)
        colors = {1: BLACK, 2: pal['dark'], 3: pal['mid']}
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            self.setpx(x, y, colors.get(dist[y, x], pal['ground']))
            if dist[y, x] >= 5 and rng.random() < 0.012:
                self.setpx(x, y, pal['speck'])
        rock = np.zeros_like(mask)
        if cliff_h > 0:
            bottom = mask & ~np.roll(mask, -1, 0)
            for y, x in zip(*np.nonzero(bottom)):
                length = cliff_h + int(round(0.9 * abs(math.sin(math.pi * x / 6.0))))
                for k in range(1, length + 1):
                    if y + k >= H or mask[y + k, x]:
                        break
                    rock[y + k, x] = True
            for y, x in zip(*np.nonzero(rock)):
                side = not (rock[y, max(0, x - 1)] or mask[y, max(0, x - 1)]) or not (rock[y, min(W - 1, x + 1)] or mask[y, min(W - 1, x + 1)])
                shade = (y - np.nonzero(rock[:, x])[0].min()) < 2
                self.setpx(x, y, BLACK if side else (pal['cliff_shade'] if shade else pal['cliff']))
            foot = rock & ~np.roll(rock, -1, 0)
            for y, x in zip(*np.nonzero(foot)):
                self.setpx(x, y + 1, BLACK)
                if pal['foam'] is not None and not self.ground[min(H - 1, y + 2), x] and not mask[min(H - 1, y + 2), x]:
                    self.setpx(x, y + 2, pal['foam'])
        self.ground = (self.ground & ~rock) | mask
        self.cliffs = (self.cliffs & ~mask) | rock

    def prop(self, atlas, name, x, y, flip=False):
        frame = prop_frame(atlas, name)
        if flip:
            frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
        self.img.alpha_composite(frame, (int(x), int(y))) if 0 <= x and 0 <= y and x + frame.width <= W and y + frame.height <= H \
            else self.img.paste(frame, (int(x), int(y)), frame)

    def fill(self, atlas, names, area, step, seed=0, margin=3):
        """Relleno denso (un bosque): decorados en rejilla con algo de azar, solo en suelo libre."""
        rng = np.random.default_rng(seed)
        x0, y0, x1, y1 = area
        for gy in range(y0, y1, step):
            for gx in range(x0, x1, step):
                name = names[int(rng.integers(0, len(names)))]
                frame = prop_frame(atlas, name)
                x = gx + int(rng.integers(-2, 3))
                y = gy + int(rng.integers(-2, 3))
                box = (slice(max(0, y - margin), min(H, y + frame.height + margin)), slice(max(0, x - margin), min(W, x + frame.width + margin)))
                if x < 0 or y < 0 or x + frame.width > W or y + frame.height > H:
                    continue
                if not self.ground[y:y + frame.height, x:x + frame.width].all() or self.blocked[box].any():
                    continue
                self.prop(atlas, name, x, y)
                self.blocked[box] = True

    def road(self, points, swim=False):
        """Carretera como la del juego: beis en el suelo, escalera en el acantilado, puntitos en el agua."""
        samples = []
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            steps = max(1, int(max(abs(bx - ax), abs(by - ay))))
            samples += [(ax + (bx - ax) * s / steps, ay + (by - ay) * s / steps, abs(bx - ax) > abs(by - ay)) for s in range(steps)]
        samples.append((points[-1][0], points[-1][1], False))
        run = 0
        water = 0
        for i, (sx, sy, across) in enumerate(samples):
            x, y = int(sx), int(sy)
            inside = 0 <= x < W and 0 <= y < H
            self.blocked[max(0, y - 8):y + 9, max(0, x - 8):x + 9] = True
            if inside and self.cliffs[y, x]:
                run += 1
                for off, color in ((-7, BLACK), (-6, (216, 152, 96)), (5, (216, 152, 96)), (6, BLACK)):
                    self.setpx(x if across else x + off, y + off if across else y, color)
                rung = {2: BLACK, 3: ROAD, 4: (184, 120, 72)}.get(run % 6)
                if rung:
                    for off in range(-5, 5):
                        self.setpx(x if across else x + off, y + off if across else y, rung)
            elif inside and self.ground[y, x]:
                run = 0
                for yy in range(y - 4, y + 5):
                    for xx in range(x - 4, x + 5):
                        if (xx + 0.5 - sx) ** 2 + (yy + 0.5 - sy) ** 2 <= 16 and 0 <= xx < W and 0 <= yy < H and self.ground[yy, xx]:
                            self.setpx(xx, yy, ROAD)
            elif inside:
                run = 0
                water += 1
                if swim and water % 6 == 1:
                    self.setpx(x, y, (240, 240, 240))
                elif not swim:  # puente
                    for off, color in ((-4, BLACK), (-3, (216, 152, 96)), (3, (216, 152, 96)), (4, BLACK)):
                        self.setpx(x if across else x + off, y + off if across else y, color)
                    if water % 4 < 2:
                        for off in range(-2, 3):
                            self.setpx(x if across else x + off, y + off if across else y, ROAD)

    def node(self, image, anim, x, y):
        frame = w1.sparrow_frame(image, anim)
        self.img.alpha_composite(frame, (int(x - frame.width / 2), int(y - frame.height / 2)))
        self.blocked[max(0, y - 10):y + 11, max(0, x - 10):x + 11] = True

    def level(self, x, y, secret=False):
        self.node('overworld/level_dot', 'red' if secret else 'yellow', x, y)

    def bf(self, x, y):
        frame = w1.sparrow_frame('overworld/overworld_bf', 'overworld bf walk down')
        self.img.alpha_composite(frame, (int(x - frame.width / 2), int(y - frame.height + 4)))


_frames = {}


def prop_frame(atlas, name):
    key = (atlas, name)
    if key not in _frames:
        base = os.path.join(PROPS_DIR, atlas)
        img = Image.open(base + '.png').convert('RGBA')
        for sub in ET.parse(base + '.xml').getroot().iter('SubTexture'):
            if sub.get('name') == name + '0000':
                x, y, w, h = (int(sub.get(k)) for k in ('x', 'y', 'width', 'height'))
                _frames[key] = img.crop((x, y, x + w, y + h))
                break
        else:
            raise KeyError('%s/%s' % key)
    return _frames[key]


def tiled(tile):
    bg = Image.new('RGBA', (W, H))
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            bg.paste(tile, (x, y))
    return bg


def sea():
    return tiled(dict(w1.sea_frames())['idle0000'])


def flat(color):
    return Image.new('RGBA', (W, H), color + (255,))


def night():
    bg = flat((56, 48, 88))
    rng = np.random.default_rng(5)
    for _ in range(60):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, H))
        bg.putpixel((x, y), ((184, 248, 248) if rng.random() < 0.5 else (248, 248, 136)) + (255,))
    return bg


def path_through(p, pts):
    """Una carretera por varios nodos seguidos (en L entre cada dos)."""
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        p.road([(ax, ay), (bx, ay), (bx, by)] if ax != bx and ay != by else [(ax, ay), (bx, by)])


# ------------------------------------------------------------------------------------------ prototipos
def forest():
    """Bosque (mundo 2 de Mario's Madness): isla tapada de arboles con ojos y un lago en medio."""
    pal = PALETTES['forest']
    p = Proto(sea())
    p.land(w1.land(w1.rounded_rect(14, 18, 402, 196, 12)), 14, pal, seed=1)
    p.prop('mm_forest', 'lake_blue', 170, 46)
    p.blocked[40:160, 160:255] = True
    nodes = [(48, 176), (112, 176), (112, 120), (112, 56), (300, 56), (300, 120), (372, 120)]
    path_through(p, nodes)
    for x, y in nodes[:-1]:
        p.level(x, y, secret=(x, y) == (112, 56))
    p.node('overworld/castle', 'idle', 372, 120)
    p.fill('mm_forest', ['tree_big', 'trees_trio', 'tree_small', 'tree_big'], (18, 22, 400, 186), 14, seed=2)
    p.fill('smw_forest', ['tree_round', 'bush_tall', 'tree_big_eyes'], (18, 22, 400, 186), 9, seed=3, margin=1)
    p.bf(48, 176)
    return p


def underground():
    """Subterraneo (mundo 6 de Mario's Madness): rocas de cueva sobre negro y tuberias verdes de alturas distintas."""
    pal = PALETTES['cave']
    p = Proto(flat((8, 8, 16)))
    p.land(w1.land(w1.rounded_rect(16, 132, 150, 186, 8)), 16, pal, seed=1)
    p.land(w1.land(w1.rounded_rect(170, 92, 290, 150, 8)), 16, pal, seed=2)
    p.land(w1.land(w1.rounded_rect(300, 40, 404, 110, 8)), 16, pal, seed=3)
    for name, x in (('pipe_tall', 20), ('pipe_giant', 160), ('pipe_mid', 296), ('pipe_stub', 120), ('pipe_tall', 380), ('pipe_mid', 240)):
        frame = prop_frame('mm_pipes', name)
        p.prop('mm_pipes', name, x, H - frame.height)
    p.road([(48, 160), (120, 160)])
    p.road([(120, 160), (120, 172), (210, 172), (210, 120)])  # puente por el aire hasta la otra roca
    p.road([(210, 120), (256, 120)])
    p.road([(256, 120), (256, 140), (330, 140), (330, 76)])
    p.road([(330, 76), (380, 76)])
    for x, y in ((48, 160), (120, 160), (210, 120), (256, 120), (330, 76)):
        p.level(x, y, secret=(x, y) == (256, 120))
    p.node('overworld/pipe', 'idle', 380, 76)
    for atlas, name, x, y in (('smw_cave', 'spike_tall', 70, 138), ('smw_cave', 'spike_small', 92, 146), ('smw_cave', 'rock_mound', 182, 100),
                              ('smw_cave', 'pond_round', 268, 98), ('smw_cave', 'spike_tall', 360, 48), ('smw_cave', 'rock_dome', 316, 92),
                              ('smw_cave', 'spike_small', 26, 140)):
        p.prop(atlas, name, x, y)
    p.bf(48, 160)
    return p


def fortress():
    """Fortaleza (mundo 4 de Mario's Madness): un anillo de piedra con torres en agua oscura."""
    pal = PALETTES['fortress']
    p = Proto(flat((16, 32, 96)))
    ring = w1.land(w1.rounded_rect(40, 20, 376, 180, 24)) & ~w1.land(w1.rounded_rect(120, 64, 296, 136, 16))
    p.land(ring, 20, pal, seed=1)
    for name, x, y in (('tower_glow_tall', 40, 10), ('tower_glow_tall', 344, 10), ('tower_flat', 184, -10)):
        p.prop('mm_fortress', name, x, max(0, y))
    nodes = [(80, 156), (80, 48), (208, 44), (336, 48), (336, 156), (208, 160)]
    path_through(p, nodes + [(80, 156)])
    for x, y in nodes:
        p.level(x, y, secret=(x, y) == (336, 48))
    for name, x, y in (('rock_wedge_pair', 140, 150), ('pebble_pile', 256, 146), ('rock_wedge_single', 300, 30), ('pebble_light', 120, 40),
                       ('ground_tuft', 280, 160), ('pebble_dark', 60, 100)):
        p.prop('mm_fortress', name, x, y)
    p.bf(80, 156)
    return p


def lava():
    """Castillo y lava (mundo 5 de Mario's Madness): ceniza, un lago de lava y el castillo grande."""
    pal = PALETTES['ash']
    p = Proto(flat((200, 40, 16)))  # lava de fondo
    p.land(w1.land(w1.rounded_rect(8, 60, 280, 210, 14), w1.rounded_rect(200, 8, 408, 120, 14)), 12, pal, seed=1)
    p.prop('mm_forest', 'lake_lava', 96, 70)
    p.blocked[64:180, 90:175] = True
    p.prop('mm_castle', 'castle_big', 252, 0) if False else None
    nodes = [(40, 180), (200, 180), (240, 96), (300, 40)]
    path_through(p, nodes)
    for x, y in nodes[:-1]:
        p.level(x, y)
    p.prop('mm_castle', 'tower_gray', 352, 10)
    p.prop('mm_castle', 'tower_tan', 376, 30)
    p.node('overworld/castle', 'idle', 300, 40)
    for name, x, y in (('ash_rock', 60, 120), ('ash_rock', 220, 150), ('bowser_mark', 248, 120), ('ash_rock', 330, 90)):
        p.prop('mm_castle', name, x, y)
    p.bf(40, 180)
    return p


def snow():
    """Nieve / Star World de SMW: suelo menta y blanco con riscos morados bajo un cielo de noche."""
    pal = PALETTES['snow']
    p = Proto(night())
    p.land(w1.land(w1.rounded_rect(20, 96, 396, 190, 12)), 16, pal, seed=1)
    p.land(w1.land(w1.rounded_rect(150, 30, 300, 80, 10)), 16, pal, seed=2)
    p.prop('smw_snow', 'moon_crescent', 30, 20)
    nodes = [(48, 168), (128, 168), (208, 168), (224, 120), (224, 56), (280, 56)]
    path_through(p, nodes)
    for x, y in nodes:
        p.level(x, y, secret=(x, y) == (224, 120))
    p.road([(208, 168), (330, 168)])
    p.node('overworld/star', 'idle', 330, 168)
    for name, x, y in (('hill_eyes_big', 300, 104), ('ice_mound', 70, 120), ('ice_mound', 360, 140), ('tree_round', 150, 120), ('spike_tall', 250, 36),
                       ('sparkle_gold', 100, 40), ('sparkle_cyan', 340, 60), ('twinkle_big', 60, 70), ('hill_eyes_small', 168, 40)):
        p.prop('smw_snow', name, x, y)
    p.bf(48, 168)
    return p


def desert():
    """Desierto de SMW: arena con sus colinas con ojos, rocas y un oasis."""
    pal = PALETTES['desert']
    p = Proto(sea())
    p.land(w1.land(w1.rounded_rect(14, 20, 402, 194, 12)), 14, pal, seed=1)
    p.land(w1.land(w1.rounded_rect(240, 36, 380, 92, 10)), 14, pal, seed=2)
    nodes = [(40, 172), (120, 172), (120, 104), (200, 104), (264, 64), (352, 64)]
    path_through(p, nodes)
    for x, y in nodes[:-1]:
        p.level(x, y, secret=(x, y) == (200, 104))
    p.node('overworld/castle', 'idle', 352, 64)
    for name, x, y in (('hill_eyes_big', 40, 40), ('hill_eyes_big', 72, 52), ('hill_eyes_small', 170, 140), ('rock_wedge', 230, 150),
                       ('pond_round', 300, 140), ('pebbles', 160, 60), ('stone_post', 90, 120), ('rock_small', 340, 170), ('bush_small', 260, 120),
                       ('rock_mound', 60, 120)):
        p.prop('smw_desert', name, x, y)
    p.bf(40, 172)
    return p


PROTOTYPES = [('bosque', forest), ('subterraneo', underground), ('fortaleza', fortress), ('lava', lava), ('nieve', snow), ('desierto', desert)]


def main(args):
    out = args[0] if args else '.'
    os.makedirs(out, exist_ok=True)
    shots = []
    for name, build in PROTOTYPES:
        img = build().img.resize((W * 3, H * 3), Image.NEAREST)
        img.save(os.path.join(out, name + '.png'))
        shots.append((name, img))
        print('-> ' + name)
    cols = 2
    sheet = Image.new('RGB', (cols * W * 2 + 30, (len(shots) + 1) // cols * (H * 2 + 24) + 10), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    for i, (name, img) in enumerate(shots):
        x = 10 + (i % cols) * (W * 2 + 10)
        y = 10 + (i // cols) * (H * 2 + 24)
        sheet.paste(img.resize((W * 2, H * 2), Image.NEAREST), (x, y + 14))
        draw.text((x, y), name.upper(), fill=(255, 220, 0))
    sheet.save(os.path.join(out, 'prototipos.png'))
    print('-> prototipos.png')


if __name__ == '__main__':
    main(sys.argv[1:])
