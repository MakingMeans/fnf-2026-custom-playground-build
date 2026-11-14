"""Importa "Last Course" y "Bad Day" de Mario's Madness V2 (carpeta mamami) a este juego.

Uso:  python tools/ports/mario_madness.py [carpeta assets del mod]
      (por defecto C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets)

El mod esta hecho sobre Psych 0.4.2 y casi toda su logica esta escrita en su PlayState.hx. Aqui los
archivos van directos a las carpetas del juego (nada en mods/) y la logica va en Haxe:
  source/states/stages/MarioStage.hx     lo comun de Mario's Madness (camara, HUD, rotulo, eventos)
  source/states/stages/TurmoilSweep.hx   Last Course (ataques de la lengua, esquivar)
  source/states/stages/SuperBad.hx       Bad Day (caparazones, setas, notas veneno, game over)
  source/shaders/RippleShader.hx         distorsion de Bad Day

Destino de los archivos:
  assets/base_game/shared/data/<cancion>/<cancion>-hard.json   chart convertido a psych_v1
  assets/base_game/shared/characters/<cancion>-*.json          personajes
  assets/base_game/shared/stages/turmoilsweep.json, superbad.json
  assets/base_game/shared/images/{last-course,bad-day,mario_madness}/   escenarios, HUD, flechas
  assets/base_game/shared/images/characters/<cancion>/                 atlas de personajes
  assets/base_game/shared/sounds/<cancion>/, music/<cancion>/, music/mario_madness/
  assets/base_game/songs/<cancion>/   Inst.ogg y Voices.ogg
  assets/fonts/mariones.ttf, mario2.ttf  (del repo del mod: el juego compilado las lleva dentro)

Conversion del chart (Psych 0.4.2 -> psych_v1):
  - Los eventos iban como notas en el carril -1: pasan a la lista "events".
  - Los carriles eran relativos a mustHitSection: pasan a 0-3 jugador / 4-7 rival.
  - "player3" (la GF de verdad del mod) pasa a "gfVersion".
  - Flechas y chispazos de Mario's Madness, sin el tinte RGB de Psych 1.0.
Es idempotente: se puede volver a ejecutar.
"""
import json
import os
import shutil
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/mamami/assets'
SHARED = os.path.join(ROOT, 'assets', 'base_game', 'shared')
SONGS = os.path.join(ROOT, 'assets', 'base_game', 'songs')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
LISTS = os.path.join(ROOT, 'assets', 'shared')  # weekList / stageList / characterList
# Las fuentes no estan en la carpeta del mod (van dentro del exe): se bajan del repo del codigo fuente.
FONT_URL = 'https://raw.githubusercontent.com/Dewott2501/Mario-Madness/main/assets/fonts/'

# Piezas comunes de Mario's Madness: origen (relativo a assets/ del mod) -> destino (relativo a shared/)
COMMON_FILES = {
    'images/Mario_NOTE_assets.png': 'images/mario_madness/Mario_NOTE_assets.png',
    'images/Mario_NOTE_assets.xml': 'images/mario_madness/Mario_NOTE_assets.xml',
    'shared/images/badMario_NOTE_assets.png': 'images/mario_madness/badMario_NOTE_assets.png',
    'shared/images/badMario_NOTE_assets.xml': 'images/mario_madness/badMario_NOTE_assets.xml',
    'shared/images/noteSplashes.png': 'images/mario_madness/noteSplashes.png',
    'shared/images/noteSplashes.xml': 'images/mario_madness/noteSplashes.xml',
    'shared/images/healthBarNEW.png': 'images/mario_madness/healthBarNEW.png',
    'shared/music/gameOverNew.ogg': 'music/mario_madness/gameOverNew.ogg',
    'shared/music/gameOverEndNew.ogg': 'music/mario_madness/gameOverEndNew.ogg',
}
# Cuenta atras, calificaciones y numeros del combo de Mario's Madness (los de FNF clasico, no los de
# Psych 1.0). Los escenarios los usan con "stageUI": "mario_madness" -> images/mario_madnessUI/.
COMMON_FILES.update({'shared/images/%s.png' % name: 'images/mario_madnessUI/%s.png' % name
                     for name in ('ready', 'set', 'go')})
COMMON_FILES.update({'shared/images/rating/%s.png' % name: 'images/mario_madnessUI/%s.png' % name
                     for name in ('sick', 'good', 'bad', 'shit', 'combo')})
COMMON_FILES.update({'images/numbers/num%d.png' % i: 'images/mario_madnessUI/num%d.png' % i for i in range(10)})
FONT_FILES = ['mariones.ttf', 'mario2.ttf']

SONG_DATA = {
    'last-course': {
        'title': 'Last Course',
        'week_icon': 'last-course-turmoil',
        'week_color': [220, 58, 133],
        'stage': 'turmoilsweep',
        # personaje del mod -> personaje aqui
        'characters': {'bf-goomba': 'last-course-bf', 'turmoil1': 'last-course-turmoil', 'gf': 'gf'},
        # el game over usa una copia del jugador: asi aparece donde estaba en pantalla, como en el mod
        'extra_characters': {'last-course-bf-dead': 'bf-goomba'},
        'images': {
            'characters/BF_Goomba': 'characters/last-course/BF_Goomba',
            'characters/Turmoil_stand': 'characters/last-course/Turmoil_stand',
        },
        'icons': {'gbf': 'last-course-bf', 'turmoil': 'last-course-turmoil'},
        'files': {
            'shared/images/mario/Turmoil/ThirdBGTrees.png': 'images/last-course/ThirdBGTrees.png',
            'shared/images/mario/Turmoil/SecondBGTrees.png': 'images/last-course/SecondBGTrees.png',
            'shared/images/mario/Turmoil/MainFloorAndTrees.png': 'images/last-course/MainFloorAndTrees.png',
            'shared/images/mario/Turmoil/TreeLeaves.png': 'images/last-course/TreeLeaves.png',
            'shared/images/mario/Turmoil/TreesForeground.png': 'images/last-course/TreesForeground.png',
            'shared/images/mario/Turmoil/Turmoil_HARHARHARHAR.png': 'images/last-course/warning.png',
            'shared/images/mario/Turmoil/button.png': 'images/last-course/button.png',
            'shared/images/mario/Turmoil/button.xml': 'images/last-course/button.xml',
            'images/modstuff/126.png': 'images/last-course/vignette.png',
            'shared/sounds/warningT2.ogg': 'sounds/last-course/warningT2.ogg',
            'shared/sounds/TURMOIL-LENGUETAZO.ogg': 'sounds/last-course/TURMOIL-LENGUETAZO.ogg',
            'shared/sounds/turmoil_death1.ogg': 'sounds/last-course/turmoil_death1.ogg',
        },
        'game_over': {
            'gameOverChar': 'last-course-bf-dead',
            'gameOverSound': 'last-course/turmoil_death1',
            'gameOverLoop': 'mario_madness/gameOverNew',
            'gameOverEnd': 'mario_madness/gameOverEndNew',
        },
    },
    'bad-day': {
        'title': 'Bad Day',
        'week_icon': 'bad-day-mario',
        'week_color': [248, 64, 112],
        'stage': 'superbad',
        'characters': {'bfbad': 'bad-day-bf', 'badmario': 'bad-day-mario', 'gfbad': 'bad-day-gf',
                       'bfbaddeath': 'bad-day-bf-dead'},
        'extra_characters': {},
        'images': {
            'characters/bf_Bad_Day_Assets': 'characters/bad-day/bf_Bad_Day_Assets',
            'characters/gf_Bad_Day_Assets': 'characters/bad-day/gf_Bad_Day_Assets',
            'characters/badmario': 'characters/bad-day/badmario',
            'characters/BF_BadDay_DEAD_Assets': 'characters/bad-day/BF_BadDay_DEAD_Assets',
        },
        # el BF de Mario's Madness tiene su propio icono (distinto del de Psych)
        'icons': {'bad': 'bad-day-mario', 'bf': 'bad-day-bf'},
        'files': dict({
            'shared/images/mario/BadMario/lumpy.png': 'images/bad-day/lumpy.png',
            'shared/images/mario/BadMario/couch.png': 'images/bad-day/couch.png',
            'shared/images/mario/BadMario/sideBar.png': 'images/bad-day/sideBar.png',
            'shared/images/mario/BadMario/poisonVG.png': 'images/bad-day/poisonVG.png',
            'shared/images/mario/BadMario/HUD_Mario.png': 'images/bad-day/HUD_Mario.png',
            'shared/images/mario/BadMario/HUD_Mario.xml': 'images/bad-day/HUD_Mario.xml',
            'shared/images/mario/BadMario/HUD_Mario_Blue.png': 'images/bad-day/HUD_Mario_Blue.png',
            'shared/images/mario/BadMario/HUD_Mario_Blue.xml': 'images/bad-day/HUD_Mario_Blue.xml',
            'shared/images/mario/BadMario/shell.png': 'images/bad-day/shell.png',
            'shared/images/mario/BadMario/shroom.png': 'images/bad-day/shroom.png',
            'images/modstuff/bye.png': 'images/bad-day/bye.png',
            'images/modstuff/bye.xml': 'images/bad-day/bye.xml',
            'shared/sounds/fnf_loss_sfx2.ogg': 'sounds/bad-day/fnf_loss_sfx2.ogg',
            'shared/sounds/fnf_loss_sfx3.ogg': 'sounds/bad-day/fnf_loss_sfx3.ogg',
            'shared/music/badover.ogg': 'music/bad-day/badover.ogg',
            'shared/music/badoverEND.ogg': 'music/bad-day/badoverEND.ogg',
        }, **{'shared/sounds/bad-day/%s.ogg' % name: 'sounds/bad-day/%s.ogg' % name for name in (
            'line1', 'line2', 'line3', 'line4', 'line5', 'line6', 'smw_break_block', 'smw_item_reserve',
            'smw_jump', 'smw_scroll', 'smw_shell_kick', 'smw_spinjump', 'smw_stomp', 'smw_stomp2', 'smw_thud')}),
        'game_over': {
            'gameOverChar': 'bad-day-bf-dead',
            'gameOverSound': 'bad-day/fnf_loss_sfx2',
            'gameOverLoop': 'bad-day/badover',
            'gameOverEnd': 'bad-day/badoverEND',
        },
    },
}

# Escenarios en formato Psych 1.0. Las posiciones de camara fijas de Mario's Madness (los valores
# 3-6 de cada personaje en el JSON del mod) van en las clases de los escenarios.
STAGES = {
    'turmoilsweep': {
        'directory': '',
        'defaultZoom': 0.9,
        'isPixelStage': False,
        'boyfriend': [870, 120],
        'girlfriend': [500, 50],
        'opponent': [-100, 130],
        'hide_girlfriend': True,  # el mod la creaba invisible
        'stageUI': 'mario_madness',
        'camera_boyfriend': [0, 0],
        'camera_opponent': [0, 0],
        'camera_girlfriend': [0, 0],
        'camera_speed': 1,
    },
    'superbad': {
        'directory': '',
        'defaultZoom': 1.1,
        'isPixelStage': False,
        'boyfriend': [570, 50],
        'girlfriend': [600, 320],
        'opponent': [90, -190],
        'hide_girlfriend': False,
        'stageUI': 'mario_madness',
        'camera_boyfriend': [0, 0],
        'camera_opponent': [0, 0],
        'camera_girlfriend': [0, 0],
        'camera_speed': 1,
    },
}

copied = []


def src(rel):
    return os.path.join(SRC, *rel.split('/'))


def copy(from_rel, to_abs):
    os.makedirs(os.path.dirname(to_abs), exist_ok=True)
    shutil.copyfile(src(from_rel), to_abs)
    copied.append(to_abs)


def write_json(to_abs, data):
    os.makedirs(os.path.dirname(to_abs), exist_ok=True)
    with open(to_abs, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(data, indent='\t', ensure_ascii=False) + '\n')
    copied.append(to_abs)


def read_json(rel):
    with open(src(rel), encoding='utf-8-sig') as f:
        return json.load(f)


def add_to_list(list_file, entry):
    path = os.path.join(LISTS, *list_file.split('/'))
    with open(path, encoding='utf-8') as f:
        lines = [line.strip() for line in f.read().splitlines()]
    if entry in lines:
        return
    lines = [line for line in lines if line] + [entry]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def port_chart(song, info):
    chart = read_json('data/songData/%s/%s.json' % (song, song))['song']
    names = info['characters']
    chart['player1'] = names[chart['player1']]
    chart['player2'] = names[chart['player2']]
    # Psych 0.4.2 sacaba la GF de "player3"; "gfVersion" era un campo viejo sin uso
    chart['gfVersion'] = names[chart.pop('player3', None) or chart.get('gfVersion') or 'gf']

    events = {}
    notes_kept = 0
    for section in chart['notes']:
        must_hit = section.get('mustHitSection', True)
        beats = section.get('sectionBeats')
        if not isinstance(beats, (int, float)):
            steps = section.get('lengthInSteps') or 16
            beats = steps / 4
        section['sectionBeats'] = beats
        for key in ('lengthInSteps', 'typeOfSection'):
            section.pop(key, None)
        if section.get('gfSection') is None:
            section['gfSection'] = False
        new_notes = []
        for note in section['sectionNotes']:
            if note[1] < 0:
                # evento guardado como nota del carril -1: [tiempo, -1, nombre, valor1, valor2]
                value1 = note[3] if len(note) > 3 else ''
                value2 = note[4] if len(note) > 4 else ''
                events.setdefault(note[0], []).append([note[2], str(value1), str(value2)])
                continue
            player = must_hit if note[1] < 4 else not must_hit
            lane = note[1] % 4 + (0 if player else 4)
            new_note = [note[0], lane, note[2]]
            if len(note) > 3 and isinstance(note[3], str) and note[3]:
                new_note.append(note[3])
            new_notes.append(new_note)
            notes_kept += 1
        section['sectionNotes'] = new_notes

    chart['events'] = [[time, events[time]] for time in sorted(events)]
    chart['format'] = 'psych_v1'
    chart['arrowSkin'] = 'mario_madness/Mario_NOTE_assets'
    chart['splashSkin'] = 'mario_madness/noteSplashes'
    chart['disableNoteRGB'] = True
    chart['offset'] = 0
    chart['stage'] = info['stage']
    chart.pop('validScore', None)
    chart.update(info['game_over'])
    write_json(os.path.join(SHARED, 'data', song, '%s-hard.json' % song), chart)
    return notes_kept, sum(len(e) for e in events.values())


def port_characters(info):
    sources = dict((old, new) for old, new in info['characters'].items() if new != 'gf')
    for new, old in info['extra_characters'].items():
        sources[old + '>' + new] = new
    for key, new in sources.items():
        old = key.split('>')[0]
        data = read_json('characters/%s.json' % old)
        data['image'] = info['images'][data['image']]
        data['healthicon'] = info['icons'].get(data['healthicon'], data['healthicon'])
        write_json(os.path.join(SHARED, 'characters', new + '.json'), data)
    for old, new in info['images'].items():
        for ext in ('.png', '.xml'):
            copy('shared/images/' + old + ext, os.path.join(SHARED, 'images', *new.split('/')) + ext)
    for old, new in info['icons'].items():
        copy('images/icons/icon-%s.png' % old, os.path.join(SHARED, 'images', 'icons', 'icon-%s.png' % new))


def port_files(files):
    for old, new in files.items():
        copy(old, os.path.join(SHARED, *new.split('/')))


def port_audio(song):
    for name in ('Inst.ogg', 'Voices.ogg'):
        copy('songs/%s/%s' % (song, name), os.path.join(SONGS, song, name))


def port_fonts():
    os.makedirs(FONTS, exist_ok=True)
    for name in FONT_FILES:
        path = os.path.join(FONTS, name)
        if os.path.exists(path):
            continue
        print('descargando', FONT_URL + name)
        with urllib.request.urlopen(FONT_URL + name, timeout=60) as response:
            data = response.read()
        with open(path, 'wb') as f:
            f.write(data)
        copied.append(path)


def port_week_and_lists():
    week_path = os.path.join(SHARED, 'weeks', 'world1.json')
    with open(week_path, encoding='utf-8') as f:
        week = json.load(f)
    for song, info in SONG_DATA.items():
        if not any(entry[0].lower().replace(' ', '-') == song for entry in week['songs']):
            week['songs'].append([info['title'], info['week_icon'], info['week_color']])
    with open(week_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(week, indent='\t', ensure_ascii=False) + '\n')

    for stage in STAGES:
        add_to_list('data/stageList.txt', stage)
    for info in SONG_DATA.values():
        for name in list(info['characters'].values()) + list(info['extra_characters']):
            if name != 'gf':
                add_to_list('data/characterList.txt', name)


def main():
    if not os.path.isdir(SRC):
        raise SystemExit('No existe la carpeta del mod: ' + SRC)
    port_files(COMMON_FILES)
    port_fonts()
    for stage, data in STAGES.items():
        write_json(os.path.join(SHARED, 'stages', stage + '.json'), data)
    for song, info in SONG_DATA.items():
        notes, events = port_chart(song, info)
        port_characters(info)
        port_files(info['files'])
        port_audio(song)
        print('%s: %d notas, %d eventos' % (song, notes, events))
    port_week_and_lists()
    total = sum(os.path.getsize(path) for path in set(copied))
    print('Mario\'s Madness: %d archivos, %.1f MB' % (len(set(copied)), total / 1048576))


if __name__ == '__main__':
    main()
