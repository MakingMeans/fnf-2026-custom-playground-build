"""Copia la tienda de Gaster de Friday Night Dustin' (mod de Codename Engine, carpeta `dustin` del paquete
Qsych) y escribe los dialogos de nuestras tiendas.

Uso:  python tools/ports/gaster_shop.py
Solo lee la carpeta del mod (no la toca). Escribe:
  assets/shared/images/gaster_shop/   background_gaster, light, gaster (atlas con sus caras) y keys/ (las
                                      cuatro llaves del mod: guilty, mirror, virus, wrath)
  assets/shared/music/gaster_shop.ogg
  assets/shared/sounds/gaster_shop/   vanish (Gaster desaparece), wingding1..7 (sus susurros), select,
                                      levelup (pantalla de EXP ganada), key_get (montado aqui: recoger la llave)
  assets/fonts/8bit-jve.ttf, assets/fonts/pixel-wingdings.otf, assets/fonts/DTM-Mono.ttf
  assets/shared/data/gaster_shop/<tienda>.json   lo que dice Gaster: "first" (la primera vez) y "return"

La tienda en el juego es states/GasterShopState.hx (rehecha a partir de su data/states/ShopState.hx). Cada
mundo tendra la suya; la del mundo 1 (gaster_w1) solo es charla: avisa de que existen las llaves.
"""
import json
import os
import shutil
import subprocess

FFMPEG = 'C:/Program Files/Krita (x64)/bin/ffmpeg.exe'  # el unico ffmpeg del equipo (no se pueden instalar paquetes)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MOD = 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/dustin/mods/dustin'
SHARED = os.path.join(ROOT, 'assets', 'shared')

COPIES = [
    ('images/menus/shop/background_gaster.png', 'shared', 'images/gaster_shop/background_gaster.png'),
    ('images/menus/shop/light.png', 'shared', 'images/gaster_shop/light.png'),
    ('images/menus/shop/gaster.png', 'shared', 'images/gaster_shop/gaster.png'),
    ('images/menus/shop/gaster.xml', 'shared', 'images/gaster_shop/gaster.xml'),
    ('images/menus/shop/keys_images/guilty key.png', 'shared', 'images/gaster_shop/keys/guilty.png'),
    ('images/menus/shop/keys_images/mirror key.png', 'shared', 'images/gaster_shop/keys/mirror.png'),
    ('images/menus/shop/keys_images/virus key.png', 'shared', 'images/gaster_shop/keys/virus.png'),
    ('images/menus/shop/keys_images/wrath key.png', 'shared', 'images/gaster_shop/keys/wrath.png'),
    ('music/gaster_shop.ogg', 'shared', 'music/gaster_shop.ogg'),
    ('sounds/menu/gaster-vanish.ogg', 'shared', 'sounds/gaster_shop/vanish.ogg'),
    ('sounds/menu/select.ogg', 'shared', 'sounds/gaster_shop/select.ogg'),
    ('fonts/8bit-jve.ttf', 'fonts', '8bit-jve.ttf'),
    ('fonts/pixel-wingdings.otf', 'fonts', 'pixel-wingdings.otf'),
    # pantalla de EXP ganada (su songs/misc_getrichquick.hx; la rehace PlayState.showExpGain)
    ('fonts/DTM-Mono.ttf', 'fonts', 'DTM-Mono.ttf'),
    ('sounds/levelup.ogg', 'shared', 'sounds/gaster_shop/levelup.ogg'),
] + [('sounds/wing_oggster/snd_wngdng%d.ogg' % i, 'shared', 'sounds/gaster_shop/wingding%d.ogg' % i) for i in range(1, 8)]

# Lo que dice Gaster en cada tienda, en ingles (lo que ve el jugador va en ingles; como en el mod: mayusculas y
# frases cortas). Caras: idle, talk, focus, surprised, scary, goofy (las de su atlas).
DIALOGUES = {
    # mundo 1: al final del camino que abre la llave escondida en Bad Day. Todavia no vende nada
    'gaster_w1': {
        'first': [
            {'text': 'WELCOME.', 'face': 'talk'},
            {'text': 'YOU HAVE FOUND A PATH\nTHAT SHOULD NOT BE HERE.', 'face': 'focus'},
            {'text': 'INTERESTING.\nVERY INTERESTING.', 'face': 'surprised'},
            {'text': 'THAT KEY WAS NOT THERE\nBY ACCIDENT.', 'face': 'talk'},
            {'text': 'THERE ARE MORE KEYS.\nONE IN EVERY WORLD.', 'face': 'focus'},
            {'text': 'WHAT YOU CHOOSE TO OPEN\nWILL DECIDE HOW IT ALL ENDS.', 'face': 'scary'},
            {'text': 'FOR NOW, I HAVE NOTHING\nTO OFFER YOU.', 'face': 'talk'},
            {'text': 'SEEK ME IN THE NEXT WORLD.', 'face': 'focus'},
        ],
        'return': [
            {'text': 'WELCOME BACK.', 'face': 'talk'},
            {'text': 'SEEK ME IN THE NEXT WORLD.', 'face': 'focus'},
        ],
    },
}


def build_key_get():
    """El sonido de recoger la llave de Bad Day: una rafaga de susurros de Gaster (6 wingdings seguidos, como
    cuando habla) sobre la cola de su sonido de desvanecerse, +4 dB con limitador para que se oiga sobre la
    cancion. Los wingdings sueltos duran 60-90 ms y se perdian."""
    folder = os.path.join(SHARED, 'sounds', 'gaster_shop')
    blips = [3, 5, 4, 7, 2, 5]
    inputs = []
    for n in blips:
        inputs += ['-i', os.path.join(folder, 'wingding%d.ogg' % n)]
    inputs += ['-i', os.path.join(folder, 'vanish.ogg')]
    chains = ['[%d]aformat=channel_layouts=stereo,adelay=%d|%d[a%d]' % (i, 75 * i, 75 * i, i) for i in range(len(blips))]
    chains.append('[%d]aformat=channel_layouts=stereo,volume=0.7,atrim=0:1.6,afade=t=out:st=1.2:d=0.4[v]' % len(blips))
    mix = ''.join('[a%d]' % i for i in range(len(blips))) + '[v]amix=inputs=%d:normalize=0,volume=4dB,alimiter=limit=0.95' % (len(blips) + 1)
    out = os.path.join(folder, 'key_get.ogg')
    subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y'] + inputs + ['-filter_complex', ';'.join(chains) + ';' + mix,
                    '-ar', '44100', '-ac', '2', '-c:a', 'vorbis', '-strict', '-2', out], check=True)
    print('-> ' + os.path.relpath(out, ROOT))


def main():
    for src, kind, dst in COPIES:
        base = os.path.join(ROOT, 'assets', 'fonts') if kind == 'fonts' else SHARED
        out = os.path.join(base, *dst.split('/'))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copyfile(os.path.join(MOD, *src.split('/')), out)
        print('-> ' + os.path.relpath(out, ROOT))
    build_key_get()
    for name, data in DIALOGUES.items():
        out = os.path.join(SHARED, 'data', 'gaster_shop', name + '.json')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w', encoding='utf-8', newline='\n') as f:
            f.write(json.dumps(data, indent='\t', ensure_ascii=False) + '\n')
        print('-> ' + os.path.relpath(out, ROOT))


if __name__ == '__main__':
    main()
