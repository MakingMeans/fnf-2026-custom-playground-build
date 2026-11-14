"""Importa la cancion "yararara" del mod YARARARA (teto1, motor Qsych / Psych 1.0.4) a este juego.

Uso:  python tools/ports/yararara.py [carpeta del mod]
      (por defecto C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/teto1/mods/YARARARA)

Todo va directo a las carpetas del juego (nada en mods/):
  assets/base_game/shared/data/yararara/    chart (yararara-hard.json) y scripts de la cancion
  assets/base_game/shared/characters/       personajes yararara-*.json
  assets/base_game/shared/stages/           yararara.json + yararara.lua
  assets/base_game/shared/images/...        personajes, iconos, escenario y zombis
  assets/base_game/shared/sounds/yararara/  sonido del golpe
  assets/base_game/shared/shaders/          yararara-chrom.frag
  assets/base_game/songs/yararara/          Inst, Voices-Player, Voices-Opponent
  assets/videos/yararara/                   los tres videos

Cambios respecto al mod (el resultado se ve y suena igual):
  - Nombres propios para lo que tenia nombre generico (personajes "1", "BF-GF", "teto-miku";
    videos "1"/"2"/"3"; sonido "HIT"; shader "chrom"), y sin espacios en las rutas.
  - Los eventos propios (10 scripts de custom_events/) van como scripts de la cancion: en
    custom_events/ serian globales, y "Flash" o "Set Cam Zoom" chocarian con los eventos de otras
    canciones del mundo que se llaman igual.
  - Zombis: el escenario cargaba 15 atlas de 4096x4096 que son solo 3 imagenes distintas. Ahora
    son 3 archivos compartidos (de ~1 GB de textura a ~200 MB). Ademas, los huecos 3, 6, 7 y 8
    pedian "zombies-N" pero el archivo se llamaba "zombeis-N" (errata), asi que en el mod no
    cargaban; aqui usan su zombi.
  - chrom.lua no falla con los shaders desactivados en las opciones.
Es idempotente: se puede volver a ejecutar.
"""
import json
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/teto1/mods/YARARARA'
SHARED = os.path.join(ROOT, 'assets', 'base_game', 'shared')
SONGS = os.path.join(ROOT, 'assets', 'base_game', 'songs')
VIDEOS = os.path.join(ROOT, 'assets', 'videos')
LISTS = os.path.join(ROOT, 'assets', 'shared')  # weekList / stageList / characterList

# nombre en el mod -> nombre aqui
CHARACTERS = {
    'BF-GF': 'yararara-bf-gf',
    'teto-miku': 'yararara-teto-miku',
    '1': 'yararara-gf',
    'yararara bf': 'yararara-bf',
    'yararara bf2': 'yararara-bf2',
    'yararara teto': 'yararara-teto',
    'yararara teto2': 'yararara-teto2',
}
# imagen de personaje en el mod -> aqui (sin la extension)
CHARACTER_IMAGES = {
    'characters/BF-GF': 'characters/yararara/bf-gf',
    'characters/teto-miku': 'characters/yararara/teto-miku',
    'characters/invisible': 'characters/yararara/invisible',
    'characters/yararara bf': 'characters/yararara/bf',
    'characters/yararara bf2': 'characters/yararara/bf2',
    'characters/yararara teto': 'characters/yararara/teto',
    'characters/yararara teto2': 'characters/yararara/teto2',
}
STAGE_IMAGES = {
    'yararara bg/yalala-bj/kw': 'yararara/stage/kw',
    'yararara bg/yalala-bj/kke': 'yararara/stage/kke',
    'yararara bg/yalala-bj/teto-0': 'yararara/stage/teto-0',
    'yararara bg/yalala-bj/yaraarara background': 'yararara/stage/background',
}
# las 3 imagenes distintas de zombi
ZOMBIE_FILES = {'a': 'zombies-1', 'b': 'zombies-2', 'c': 'zombeis-3'}
# que zombi lleva cada hueco 1..15 (3, 6, 7 y 8 son los "zombeis" que no cargaban por la errata)
ZOMBIE_SLOTS = ['a', 'b', 'c', 'b', 'a', 'c', 'c', 'c', 'a', 'b', 'b', 'a', 'b', 'b', 'a']
VIDEO_NAMES = {'1': 'yararara/1', '2': 'yararara/2', '3': 'yararara/3'}
# scripts de la cancion: origen -> nombre aqui
SONG_SCRIPTS = {
    'data/songs/yararara/Fuck.lua': 'hud-intro.lua',
    'data/songs/yararara/chrom.lua': 'chrom.lua',
    'data/songs/yararara/Play video for hud by Psych Engine V1.04 (1) (1).lua': 'hud-videos.lua',
    'data/custom_events/233.lua': 'event-233.lua',
    'data/custom_events/Cinematics (With HUD).lua': 'event-cinematics.lua',
    'data/custom_events/Flash.lua': 'event-flash.lua',
    'data/custom_events/HITTING Mode.lua': 'event-hitting-mode.lua',
    'data/custom_events/Screen Flash.lua': 'event-screen-flash.lua',
    'data/custom_events/Set Cam Zoom.lua': 'event-set-cam-zoom.lua',
    'data/custom_events/Set Camera Bop.lua': 'event-set-camera-bop.lua',
    'data/custom_events/Zoom Camera.lua': 'event-zoom-camera.lua',
    'data/custom_events/cameraSetTarget.lua': 'event-camera-set-target.lua',
    'data/custom_events/playVideo.lua': 'event-play-video.lua',
}

copied = []


def src(*parts):
    return os.path.join(SRC, *parts)


def copy(from_rel, to_abs):
    os.makedirs(os.path.dirname(to_abs), exist_ok=True)
    shutil.copyfile(src(from_rel), to_abs)
    copied.append(to_abs)


def read_text(rel):
    with open(src(rel), encoding='utf-8-sig', newline='') as f:
        return f.read().replace('\r\n', '\n')


def write_text(to_abs, text):
    os.makedirs(os.path.dirname(to_abs), exist_ok=True)
    with open(to_abs, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    copied.append(to_abs)


def replace_once(text, old, new, what):
    count = text.count(old)
    if count < 1:
        raise SystemExit('No encuentro en %s: %r' % (what, old))
    return text.replace(old, new)


def add_to_list(list_file, entry):
    path = os.path.join(LISTS, *list_file.split('/'))
    with open(path, encoding='utf-8') as f:
        lines = [line.strip() for line in f.read().splitlines()]
    if entry in lines:
        return
    lines = [line for line in lines if line] + [entry]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def port_chart():
    chart = json.loads(read_text('data/songs/yararara/yararara.json'))
    chart['player1'] = CHARACTERS[chart['player1']]
    chart['player2'] = CHARACTERS[chart['player2']]
    chart['gfVersion'] = CHARACTERS[chart['gfVersion']]
    for _, events in chart['events']:
        for event in events:
            if event[0] == 'Change Character':
                event[2] = CHARACTERS[event[2]]
            elif event[0] == 'playVideo':
                event[1] = VIDEO_NAMES[event[1]]
    write_text(os.path.join(SHARED, 'data', 'yararara', 'yararara-hard.json'), json.dumps(chart, indent='\t', ensure_ascii=False) + '\n')


def port_characters():
    for old, new in CHARACTERS.items():
        data = json.loads(read_text('data/characters/%s.json' % old))
        data['image'] = CHARACTER_IMAGES[data['image']]
        write_text(os.path.join(SHARED, 'characters', new + '.json'), json.dumps(data, indent='\t', ensure_ascii=False) + '\n')
    for old, new in CHARACTER_IMAGES.items():
        for ext in ('.png', '.xml'):
            copy('images/' + old + ext, os.path.join(SHARED, 'images', *new.split('/')) + ext)
    for icon in ('icon-yararara-bf.png', 'icon-yararara-teto.png'):
        copy('images/icons/' + icon, os.path.join(SHARED, 'images', 'icons', icon))


def port_stage():
    stage = json.loads(read_text('data/stages/yararara.json'))
    write_text(os.path.join(SHARED, 'stages', 'yararara.json'), json.dumps(stage, indent='\t') + '\n')

    lua = read_text('data/stages/yararara.lua')
    for old, new in STAGE_IMAGES.items():
        lua = replace_once(lua, "'%s'" % old, "'%s'" % new, 'yararara.lua')
    # zombis: cada hueco carga su atlas compartido (antes, 15 archivos con 3 imagenes distintas)
    for kind in ('zombies', 'pzombies'):
        lua = replace_once(lua,
            "makeAnimatedLuaSprite('%s-'..i, 'yararara bg/zombeis/zombies-'..i," % kind,
            "makeAnimatedLuaSprite('%s-'..i, 'yararara/zombies/zombie-'..ZOMBIE_ATLAS[i]," % kind, 'yararara.lua')
    table = ', '.join("'%s'" % slot for slot in ZOMBIE_SLOTS)
    header = ('-- Zombi de cada hueco (1..15): tres atlas compartidos en vez de quince archivos.\n'
              '-- Los huecos 3, 6, 7 y 8 son los que en el mod no cargaban por la errata "zombeis".\n'
              'ZOMBIE_ATLAS = {%s}\n\n' % table)
    write_text(os.path.join(SHARED, 'stages', 'yararara.lua'), header + lua)

    for old, new in STAGE_IMAGES.items():
        copy('images/' + old + '.png', os.path.join(SHARED, 'images', *new.split('/')) + '.png')
    for kind, name in ZOMBIE_FILES.items():
        for ext in ('.png', '.xml'):
            copy('images/yararara bg/zombeis/' + name + ext, os.path.join(SHARED, 'images', 'yararara', 'zombies', 'zombie-' + kind + ext))


def port_scripts():
    out = os.path.join(SHARED, 'data', 'yararara')
    for rel, name in SONG_SCRIPTS.items():
        text = read_text(rel)
        if name == 'hud-videos.lua':
            for old, new in VIDEO_NAMES.items():
                text = replace_once(text, 'name = "%s",' % old, 'name = "%s",' % new, name) if ('name = "%s",' % old) in text else text
        elif name == 'event-hitting-mode.lua':
            text = replace_once(text, 'precacheSound("HIT");', 'precacheSound("yararara/hit");', name)
            text = replace_once(text, 'playSound("HIT", 1);', 'playSound("yararara/hit", 1);', name)
        elif name == 'chrom.lua':
            # con los shaders desactivados, el mod llamaba igual a setSpriteShader y al filtro: error
            text = replace_once(text, 'initLuaShader("chrom")', 'initLuaShader("yararara-chrom")', name)
            text, count = re.subn(r'[ \t]*if shadersEnabled == true then\s*makeLuaSprite\("shaderImage"\)\s*'
                                  r'makeGraphic\("shaderImage", screenWidth, screenHeight\)\s*end\s*'
                                  r'setSpriteShader\("shaderImage", "chrom"\)\n',
                                  '\tif shadersEnabled ~= true then return end -- sin shaders, no hay filtro que poner\n\n'
                                  '\tmakeLuaSprite("shaderImage")\n'
                                  '\tmakeGraphic("shaderImage", screenWidth, screenHeight)\n'
                                  '\tsetSpriteShader("shaderImage", "yararara-chrom")\n', text)
            if count != 1:
                raise SystemExit('No encuentro el bloque del shader en chrom.lua')
            text = replace_once(text, '''function onUpdate()
    setShaderFloat("shaderImage", "iTime", os.clock())''', '''function onUpdate()
    if shadersEnabled ~= true then return end
    setShaderFloat("shaderImage", "iTime", os.clock())''', name)
        write_text(os.path.join(out, name), text)
    copy('shaders/chrom.frag', os.path.join(SHARED, 'shaders', 'yararara-chrom.frag'))
    copy('sounds/HIT.ogg', os.path.join(SHARED, 'sounds', 'yararara', 'hit.ogg'))


def port_audio_and_videos():
    for name in ('Inst.ogg', 'Voices-Player.ogg', 'Voices-Opponent.ogg'):
        copy('songs/yararara/' + name, os.path.join(SONGS, 'yararara', name))
    for old, new in VIDEO_NAMES.items():
        copy('videos/%s.mp4' % old, os.path.join(VIDEOS, *new.split('/')) + '.mp4')


def port_week_and_lists():
    week_path = os.path.join(SHARED, 'weeks', 'world1.json')
    if os.path.exists(week_path):
        with open(week_path, encoding='utf-8') as f:
            week = json.load(f)
    else:
        week = {
            'songs': [],
            'weekCharacters': ['', 'bf', 'gf'],
            'weekBackground': 'stage',
            'storyName': 'Mundo 1',
            'weekBefore': '',
            'weekName': 'Mundo 1',
            'startUnlocked': True,
            'difficulties': '',
            'hideStoryMode': True,   # el mundo 1 se juega desde el overworld
            'hideFreeplay': False,
        }
    if not any(song[0].lower() == 'yararara' for song in week['songs']):
        week['songs'].append(['YARARARA', 'icon-yararara-teto', [255, 0, 0]])
    os.makedirs(os.path.dirname(week_path), exist_ok=True)
    with open(week_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(week, indent='\t', ensure_ascii=False) + '\n')

    add_to_list('weeks/weekList.txt', 'world1')
    add_to_list('data/stageList.txt', 'yararara')
    for name in CHARACTERS.values():
        add_to_list('data/characterList.txt', name)


def main():
    if not os.path.isdir(SRC):
        raise SystemExit('No existe la carpeta del mod: ' + SRC)
    port_chart()
    port_characters()
    port_stage()
    port_scripts()
    port_audio_and_videos()
    port_week_and_lists()
    total = sum(os.path.getsize(path) for path in set(copied))
    print('yararara: %d archivos, %.1f MB' % (len(set(copied)), total / 1048576))


if __name__ == '__main__':
    main()
