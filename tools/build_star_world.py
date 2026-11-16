"""Genera el mundo de las estrellas (`star_world`): el de viajar rapido entre mundos, como la Star Road de
Mario's Madness (su mundo 3: assets/images/warpzone/3 del mod).

Uso:  python tools/build_star_world.py [vista_previa.png] [--dry-run] [--force]
Necesita Pillow y numpy. Si star_world.json se ha guardado desde el editor, no lo sobrescribe salvo con
--force (igual que build_world1.py).

Escribe:
  assets/shared/overworlds/star_world.json
  assets/shared/images/overworld/star_world/      tiles.* (el suelo de nubes en 8x8) y props.* (el grupo
                                                  de columnas con estrellas y la luna, enteros)
  assets/shared/images/overworld/backgrounds/star_sky.*   el cielo de noche con estrellas que titilan
  assets/shared/music/overworld/star_world.ogg    la musica de la Star Road de Mario's Madness
y lo copia a las builds que existan (export/*/...).

Diseno: cielo morado oscuro de noche con estrellitas que titilan y la luna; abajo, un suelo de nubes
(blanco con marcas verde menta y el borde de arriba en bultitos); en el centro, las cinco columnas moradas
con estrellas de Mario's Madness (enteras, como en su mapa) con una estrella-warp encima de cada una de sus
seis puntas, una por mundo. Los caminos son arcoiris (`style: 'rainbow'`): por las nubes de lado a lado y,
de cada cruce, hacia arriba a su estrella. La tuberia de la izquierda es la pareja de la del mundo 1 (la
que se abre al derrotar su castillo). Cada estrella se abre cuando su mundo tenga un warp que vuelva aqui;
hasta entonces es un "pendiente" (el mundo todavia no existe) y su arcoiris no se ve.
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_world1 as w1  # noqa: E402  (atlas, formato del JSON y aspectos de los nodos)

ROOT = w1.ROOT
NAME = 'star_world'
OUT = os.path.join(ROOT, 'assets', 'shared', 'overworlds', NAME + '.json')
OWN_DIR = os.path.join(w1.IMAGES, 'overworld', NAME)
MM3 = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets/images/warpzone/3'
MM_MUSIC = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets/music/warpzone/3.ogg'

T = 8
W, H = 416, 224  # una pantalla, como el mundo 1

SKY = (56, 48, 88)
CLOUD = (248, 248, 248)
CLOUD_MARK = (168, 240, 200)
CLOUD_SHADE = (216, 224, 240)
CLOUD_TOP = 186  # donde empieza el suelo de nubes

# el grupo de columnas (recortado de bg2 del mod) va con su esquina aqui; sus 6 puntas de estrella
# (centros medidos en bg2) quedan desplazadas lo mismo
PILLARS_BOX = (20, 52, 235, 244)
PILLARS_AT = (101 - 0, 12)  # x, y de la esquina del recorte en el mapa
STAR_TIPS = [(127, 68), (48, 107), (206, 107), (127, 125), (77, 185), (179, 185)]

LANE = 200  # la fila de cruces sobre las nubes


def tip(i):
    x, y = STAR_TIPS[i]
    return x - PILLARS_BOX[0] + PILLARS_AT[0], y - PILLARS_BOX[1] + PILLARS_AT[1]


def rainbow(a, b, points=None):
    p = w1.path(a, b, points)
    p['style'] = 'rainbow'
    return p


# ------------------------------------------------------------------------------------------ grafo
# las seis estrellas, de abajo arriba: un mundo cada una (se pueden cambiar en el editor)
STARS = [  # (id, punta, mundo, nombre)
    ('estrella-2', 4, 'world2', 'Mundo 2'),
    ('estrella-3', 5, 'world3', 'Mundo 3'),
    ('estrella-4', 1, 'world4', 'Mundo 4'),
    ('estrella-5', 2, 'world5', 'Mundo 5'),
    ('estrella-6', 3, 'world6', 'Mundo 6'),
    ('estrella-7', 0, 'world7', 'Mundo 7'),
]


def graph():
    star_xy = {sid: tip(t) for sid, t, _, _ in STARS}
    nodes = [
        w1.node('tuberia', 56, LANE, 'Mundo 1', kind='warp', look=w1.PIPE_LOOK, world='world1'),
        w1.node('centro', 208, LANE, 'Star Road', kind='empty', look=w1.HIDDEN_LOOK, unlocked=True),
    ]
    # cruces sobre las nubes, uno bajo cada estrella de los lados (sin dibujo: BF para y sube desde ahi)
    for sid in ('estrella-4', 'estrella-2', 'estrella-3', 'estrella-5'):
        x, _ = star_xy[sid]
        nodes.append(w1.node('cruce-' + sid.split('-')[1], x, LANE, 'Cruce', kind='empty', look=w1.HIDDEN_LOOK, unlocked=True))
    for sid, _, world, name in STARS:
        x, y = star_xy[sid]
        nodes.append(w1.node(sid, x, y, name, kind='warp', look=w1.STAR_LOOK, world=world))

    lane = sorted([n for n in nodes if n['y'] == LANE], key=lambda n: n['x'])
    paths = [rainbow(a['id'], b['id']) for a, b in zip(lane, lane[1:])]
    for sid in ('estrella-4', 'estrella-2', 'estrella-3', 'estrella-5'):
        paths.append(rainbow('cruce-' + sid.split('-')[1], sid))
    paths.append(rainbow('centro', 'estrella-6'))
    paths.append(rainbow('estrella-6', 'estrella-7'))  # la de arriba del todo: despues de la del centro
    return nodes, paths


# ------------------------------------------------------------------------------------------ arte
canvas = np.zeros((H, W, 4), dtype=np.uint8)


def setpx(x, y, color):
    if 0 <= x < W and 0 <= y < H:
        canvas[y, x, :3] = color
        canvas[y, x, 3] = 255


def clouds():
    """El suelo de nubes de la Star Road: blanco, con el borde de arriba en bultitos, una sombra azulada
    bajo cada bultito y marcas verde menta sueltas ('^')."""
    rng = np.random.default_rng(7)
    top = [CLOUD_TOP + int(round(2.5 * abs(np.sin(np.pi * x / 9.0)))) for x in range(W)]
    for x in range(W):
        for y in range(top[x], H):
            setpx(x, y, CLOUD_SHADE if y - top[x] < 2 and (x // 9) % 2 else CLOUD)
    for _ in range(70):
        x = int(rng.integers(2, W - 4))
        y = int(rng.integers(CLOUD_TOP + 8, H - 3))
        setpx(x, y, CLOUD_MARK)
        setpx(x + 1, y - 1, CLOUD_MARK)
        setpx(x + 2, y, CLOUD_MARK)


def crop_rgba(path, box):
    return Image.open(path).convert('RGBA').crop(box)


def moon():
    """La luna de bg1 del mod (amarilla con su sombra azul), sin el cielo."""
    img = np.array(crop_rgba(os.path.join(MM3, 'bg1.png'), (20, 40, 56, 76)))
    sky = np.all(img[..., :3] == SKY, axis=2)
    img[sky, 3] = 0
    ys, xs = np.nonzero(img[..., 3])
    return Image.fromarray(img[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')


def pillars():
    """Las columnas de bg2 del mod, enteras. Bajo la de la derecha el dibujo trae una raya suelta de 3 px
    hasta abajo (x 230-232, y 207-243): se quita."""
    img = np.array(crop_rgba(os.path.join(MM3, 'bg2.png'), PILLARS_BOX))
    x0, y0 = PILLARS_BOX[0], PILLARS_BOX[1]
    img[207 - y0:244 - y0, 230 - x0:233 - x0, 3] = 0
    return Image.fromarray(img, 'RGBA')


def props():
    return {
        'star_pillars': pillars(),
        'moon': moon(),
    }


PROPS = [('moon', 24, 14, False), ('star_pillars', PILLARS_AT[0], PILLARS_AT[1], False)]


def sky_frames(size=128, frames=4):
    """Cielo de noche en mosaico: morado liso con estrellitas que se encienden y apagan por turnos."""
    rng = np.random.default_rng(3)
    stars = [(int(rng.integers(1, size - 1)), int(rng.integers(1, size - 1)), int(rng.integers(0, frames))) for _ in range(16)]
    result = []
    for f in range(frames):
        img = Image.new('RGBA', (size, size), SKY + (255,))
        px = img.load()
        for x, y, phase in stars:
            step = (f - phase) % frames
            if step == 0:  # encendida: cruz
                for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                    px[x + dx, y + dy] = (184, 248, 248, 255)
            elif step == 1:
                px[x, y] = (248, 248, 136, 255)
            elif step == 2:
                px[x, y] = (0, 160, 200, 255)
        result.append(('idle%04d' % f, img))
    return result


def slice_tiles():
    names, own, sprites = {}, {}, []
    for row in range(H // T):
        for col in range(W // T):
            tile = canvas[row * T:(row + 1) * T, col * T:(col + 1) * T]
            if not tile[:, :, 3].any():
                continue
            key = tile.tobytes()
            if key not in names:
                names[key] = 'sw_%04d' % len(names)
                own[names[key]] = Image.fromarray(tile.copy(), 'RGBA')
            sprites.append((col * T, row * T, names[key]))
    return sprites, own


def preview(nodes, paths, prop_images, out):
    sky = dict(sky_frames())['idle0000']
    img = Image.new('RGBA', (W, H))
    for y in range(0, H, sky.height):
        for x in range(0, W, sky.width):
            img.paste(sky, (x, y))
    img.alpha_composite(Image.fromarray(canvas, 'RGBA'))
    for name, x, y, _ in PROPS:
        img.alpha_composite(prop_images[name], (x, y))
    by_id = {n['id']: n for n in nodes}
    colors = [(255, 38, 38), (255, 38, 38), (248, 216, 0), (248, 216, 0), (0, 200, 0), (0, 200, 0), (0, 216, 248), (0, 216, 248), (128, 120, 208)]
    px = img.load()
    for p in paths:
        pts = [(by_id[p['a']]['x'], by_id[p['a']]['y'])] + [tuple(q) for q in p['points']] + [(by_id[p['b']]['x'], by_id[p['b']]['y'])]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            steps = max(abs(bx - ax), abs(by - ay))
            across = abs(bx - ax) > abs(by - ay)
            for s in range(steps + 1):
                cx, cy = ax + (bx - ax) * s // max(1, steps), ay + (by - ay) * s // max(1, steps)
                for k, color in enumerate(colors):
                    x, y = (cx, cy + k - 4) if across else (cx + k - 4, cy)
                    if 0 <= x < W and 0 <= y < H:
                        px[x, y] = color + (255,)
    for n in nodes:
        spr = w1.sparrow_frame(n['image'], n['anim']) if n['image'] else None
        if spr is not None:
            img.alpha_composite(spr, (int(n['x'] - spr.width / 2), int(n['y'] - spr.height / 2)))
    img.resize((W * 3, H * 3), Image.NEAREST).save(out)
    print('vista previa -> ' + out)


def edited_by_hand():
    if not os.path.exists(OUT):
        return False
    with open(OUT, encoding='utf-8') as f:
        text = f.read()
    try:
        return w1.world_json(json.loads(text)) != text
    except ValueError:
        return True


def main(args):
    dry = '--dry-run' in args
    files = [a for a in args if not a.startswith('--')]
    if not dry and '--force' not in args and edited_by_hand():
        raise SystemExit('star_world.json se ha editado (en el editor o a mano): usa --force para sobrescribirlo.')

    clouds()
    nodes, paths = graph()
    tiles, own = slice_tiles()
    prop_images = props()
    print('%d tiles (%d distintos)' % (len(tiles), len(own)))
    if files:
        preview(nodes, paths, prop_images, files[0])
    if dry:
        return

    image_key = 'overworld/%s/' % NAME
    sprites = [{'image': image_key + 'tiles', 'anim': name, 'fps': 0, 'x': x, 'y': y, 'flipX': False, 'flipY': False,
                'scale': 1, 'alpha': 1, 'front': False} for x, y, name in tiles]
    sprites += [{'image': image_key + 'props', 'anim': name, 'fps': 0, 'x': x, 'y': y, 'flipX': flip, 'flipY': False,
                 'scale': 1, 'alpha': 1, 'front': False} for name, x, y, flip in PROPS]
    world = {
        'displayName': 'Mundo de las estrellas',
        'bg': 'overworld/backgrounds/star_sky', 'bgAnim': 'idle', 'bgFps': 3, 'bgTile': True,
        'music': 'overworld/star_world', 'zoom': 3, 'gridSize': 8, 'startNode': 'centro',
        'player': 'overworld/overworld_bf', 'walkSpeed': 60,
        'nodes': nodes, 'sprites': sprites, 'paths': paths,
    }

    w1.write_atlas('tiles', sorted(own.items()), folder=OWN_DIR)
    w1.write_packed_atlas('props', [(name + '', img) for name, img in sorted(prop_images.items())], folder=OWN_DIR)
    w1.write_atlas('star_sky', sky_frames(), per_row=2, folder=w1.BG_DIR)
    music = os.path.join(ROOT, 'assets', 'shared', 'music', 'overworld', NAME + '.ogg')
    os.makedirs(os.path.dirname(music), exist_ok=True)
    shutil.copyfile(MM_MUSIC, music)
    text = w1.world_json(world)
    json.loads(text)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('-> ' + OUT)

    for kind in ('debug', 'release'):
        build = os.path.join(ROOT, 'export', kind, 'windows', 'bin', 'assets', 'shared')
        if not os.path.isdir(build):
            continue
        shutil.copyfile(OUT, os.path.join(build, 'overworlds', NAME + '.json'))
        build_own = os.path.join(build, 'images', 'overworld', NAME)
        if os.path.isdir(build_own):
            shutil.rmtree(build_own)
        shutil.copytree(OWN_DIR, build_own)
        for ext in ('png', 'xml'):
            shutil.copyfile(os.path.join(w1.BG_DIR, 'star_sky.' + ext), os.path.join(build, 'images', 'overworld', 'backgrounds', 'star_sky.' + ext))
        os.makedirs(os.path.join(build, 'music', 'overworld'), exist_ok=True)
        shutil.copyfile(music, os.path.join(build, 'music', 'overworld', NAME + '.ogg'))
        print('-> ' + build)


if __name__ == '__main__':
    main(sys.argv[1:])
