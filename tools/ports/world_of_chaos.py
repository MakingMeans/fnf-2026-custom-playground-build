"""Importa "world of chaos" (mod de Codename Engine, carpeta clubpe) a este juego.

Uso:  python tools/ports/world_of_chaos.py [carpeta clubpe]
      (por defecto C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/clubpe)

El mod es de Codename Engine: su chart (songs/world of chaos/charts/hard.json + events.json) no tiene
secciones, los personajes son XML y casi todo lo hacen eventos de Codename y scripts HScript. Aqui:
  - El chart pasa a psych_v1 (secciones de 4 pulsos; el cambio a 154 BPM se pone al empezar la seccion
    26, 39 ms antes que en el mod). Los eventos de Codename se guardan como "WoC <nombre>" con sus
    parametros en JSON (los lee states/stages/ClubStage.hx); "Change Character" pasa al de Psych.
  - Los personajes pasan de XML a JSON con las cuentas de Codename (ver convert_character).
  - La logica (camara, eventos, HUD, fondo, game over, pausa) esta en Haxe: ClubStage.hx.
Es idempotente: se puede volver a ejecutar.
"""
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/clubpe'
SHARED = os.path.join(ROOT, 'assets', 'base_game', 'shared')
SONGS = os.path.join(ROOT, 'assets', 'base_game', 'songs')
LISTS = os.path.join(ROOT, 'assets', 'shared')
SONG = 'world-of-chaos'

copied = []


def src(*parts):
    return os.path.join(SRC, *parts)


def dst(rel):
    return rel if os.path.isabs(rel) else os.path.join(SHARED, *rel.split('/'))


def copy(source, rel):
    path = dst(rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shutil.copyfile(source, path)
    copied.append(path)


def write_json(rel, value):
    path = dst(rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(value, indent='\t', ensure_ascii=False) + '\n')
    copied.append(path)


def add_to_list(list_file, entry):
    path = os.path.join(LISTS, *list_file.split('/'))
    with open(path, encoding='utf-8') as f:
        lines = [line.strip() for line in f.read().splitlines()]
    if entry in lines:
        return
    lines = [line for line in lines if line] + [entry]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


# ---------------------------------------------------------------- personajes
# personaje del mod -> (nombre aqui, hueco en el escenario, es jugador)
CHARACTERS = {
    'monicaPe-faker': ('woc-monica-faker', 'dad', False),
    'monica': ('woc-monica', 'dad', False),
    'bigmonica': ('woc-big-monica', 'dad', False),
    'saori': ('woc-saori', 'boyfriend', True),
    'saorichikita': ('woc-saori-chibi', 'boyfriend', True),
}
ICONS = {'monica': 'woc-monica', 'monika': 'woc-monika', 'monikaaksak': 'woc-monikaaksak', 'saori': 'woc-saori'}


def sparrow_frames(xml_path):
    """[(nombre, ancho de origen, alto de origen)] de un atlas Sparrow, en orden."""
    text = open(xml_path, encoding='utf-8').read()
    out = []
    for attrs in re.findall(r'<SubTexture ([^/]*)/>', text):
        a = dict(re.findall(r'(\w+)="([^"]*)"', attrs))
        out.append((a['name'], int(float(a.get('frameWidth', a['width']))), int(float(a.get('frameHeight', a['height'])))))
    return out


def parse_indices(text):
    """CoolUtil.parseNumberRange de Codename: "0..9" o "1,2,5..7"."""
    out = []
    for part in text.split(','):
        part = part.strip()
        if '..' in part:
            a, b = part.split('..')
            out.extend(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def convert_character(name, stage_cam):
    """XML de Codename -> JSON de Psych.

    Codename dibuja un personaje en P (su posicion en el escenario) con offset = -x/-y del XML (o +x si
    es jugador: "offsets volteados"), y el offset de cada animacion va ANTES de la escala (frameOffset),
    asi que se escala con el sprite. Para la jugadora ademas voltea el sprite dos veces (flipX y escala
    negativa) e intercambia singLEFT y singRIGHT. Psych pone los offsets despues de la escala y no
    voltea nada. Con s = escala, F = offset de la animacion, G = x/y del XML, o = centro del primer
    fotograma del atlas y W = ancho de origen de los fotogramas de la animacion:
      rival:    posicion ( G.x, G.y), offset (s * F.x, s * F.y)
      jugadora: posicion (-G.x, G.y), offset (-s * (F.x + 2 * o.x - W), s * F.y)
    flip_x queda igual que en el XML (Psych ya lo invierte al jugador).
    """
    new_name, slot, is_player = CHARACTERS[name]
    root = ET.parse(src('data', 'characters', name + '.xml')).getroot()
    att = root.attrib
    gx, gy = float(att.get('x', 0)), float(att.get('y', 0))
    scale = float(att.get('scale', 1))
    flip = att.get('flipX') == 'true'
    sprite = att.get('sprite', name)
    icon = att.get('icon', name)
    hold = float(att.get('holdTime', 4))

    frames = sparrow_frames(src('images', 'characters', sprite + '.xml'))
    first_w, first_h = frames[0][1], frames[0][2]

    def frame_width(prefix, indices):
        names = [f for f in frames if f[0].startswith(prefix)]
        return names[0][1] if names else first_w

    anims = []
    for node in root.findall('anim'):
        a = node.attrib
        anims.append({
            'anim': a['name'], 'name': a['anim'], 'fps': float(a.get('fps', 24)), 'loop': a.get('loop') == 'true',
            'indices': parse_indices(a['indices']) if 'indices' in a else [],
            'x': float(a.get('x', 0)), 'y': float(a.get('y', 0)),
        })

    if is_player:  # swapLeftRightAnimations(): singLEFT<v> <-> singRIGHT<v>
        by_name = {anim['anim']: anim for anim in anims}
        variants = [''] + [n[len('singRIGHT'):] for n in by_name if n.startswith('singRIGHT') and n != 'singRIGHT']
        for v in variants:
            left, right = by_name.get('singLEFT' + v), by_name.get('singRIGHT' + v)
            if left is not None:
                left['anim'] = 'singRIGHT' + v
            if right is not None:
                right['anim'] = 'singLEFT' + v

    out_anims = []
    for anim in anims:
        if is_player:
            w = frame_width(anim['name'], anim['indices'])
            off_x = -scale * (anim['x'] + 2 * (first_w * 0.5) - w)
        else:
            off_x = scale * anim['x']
        out_anims.append({
            'anim': anim['anim'], 'name': anim['name'], 'fps': round(anim['fps']), 'loop': anim['loop'],
            'indices': anim['indices'], 'offsets': [round(off_x, 2), round(scale * anim['y'], 2)],
        })
    # con "-alt" activo Psych pide singXmiss-alt; Codename usaba la normal si no existia
    names = {a['anim'] for a in out_anims}
    for direction in ('LEFT', 'DOWN', 'UP', 'RIGHT'):
        miss = next((a for a in out_anims if a['anim'] == 'sing%smiss' % direction), None)
        if miss is not None and 'sing%s-alt' % direction in names and 'sing%smiss-alt' % direction not in names:
            out_anims.append(dict(miss, anim='sing%smiss-alt' % direction))
    out_anims.sort(key=lambda a: a['anim'])

    # Camara de Codename: centro del primer fotograma (sin escalar) + (-100 jugador / 150 rival, -100)
    # + x/y del XML + camx/camy + camxoffset/camyoffset del escenario. ClubStage la suma a la
    # posicion del personaje en el escenario (no usa la camara de Psych).
    cam = [first_w * 0.5 + (-100 if is_player else 150) + gx + float(att.get('camx', 0)) + stage_cam[slot][0],
           first_h * 0.5 - 100 + gy + float(att.get('camy', 0)) + stage_cam[slot][1]]
    color = att.get('color', '#A1A1A1').lstrip('#')
    data = {
        'animations': out_anims,
        'no_antialiasing': False,
        'image': 'characters/woc/' + sprite,
        'position': [-gx if is_player else gx, gy],
        'healthicon': ICONS.get(icon, 'woc-' + icon),
        'flip_x': flip,
        'healthbar_colors': [int(color[i:i + 2], 16) for i in (0, 2, 4)],
        'camera_position': [round(cam[0], 2), round(cam[1], 2)],
        'sing_duration': round(hold / 1.1, 3),  # Codename: holdTime pasos; Psych: 1.1 pasos por unidad
        'scale': scale,
        'vocals_file': '',
    }
    write_json('characters/%s.json' % new_name, data)
    for ext in ('png', 'xml'):
        copy(src('images', 'characters', '%s.%s' % (sprite, ext)), 'images/characters/woc/%s.%s' % (sprite, ext))
    return new_name


# ---------------------------------------------------------------- chart
BPM_START = 100
BPM_CHANGE_SECTION = 26  # el "BPM Change" del mod esta en 62439 ms = paso 416.26: aqui, al empezar la seccion 26
BPM_AFTER = 154


def section_start_times(count):
    times = []
    t = 0.0
    for i in range(count):
        times.append(t)
        bpm = BPM_START if i < BPM_CHANGE_SECTION else BPM_AFTER
        t += 4 * 60000 / bpm
    return times


def convert_chart():
    chart = json.load(open(src('songs', 'world of chaos', 'charts', 'hard.json'), encoding='utf-8'))
    events = chart['events'] + json.load(open(src('songs', 'world of chaos', 'events.json'), encoding='utf-8'))['events']
    lines = chart['strumLines']  # 0 = Monika (rival, flechas ocultas), 1 = Saori (jugadora)
    last_time = max(n['time'] + n.get('sLen', 0) for line in lines for n in line['notes'])
    starts = section_start_times(int(last_time / (4 * 60000 / BPM_AFTER)) + 40)
    while starts[-1] > last_time + 4000:
        starts.pop()

    # a quien mira la camara al empezar cada seccion (solo para el editor de charts)
    cam_events = sorted([e for e in events if e['name'] == 'Camera Movement'], key=lambda e: e['time'])

    sections = []
    for i, start in enumerate(starts):
        target = 1
        for e in cam_events:
            if e['time'] <= start + 1:
                target = e['params'][0]
        sections.append({
            'sectionNotes': [], 'sectionBeats': 4, 'mustHitSection': target == 1, 'gfSection': False,
            'altAnim': False, 'changeBPM': i == BPM_CHANGE_SECTION, 'bpm': BPM_AFTER if i >= BPM_CHANGE_SECTION else BPM_START,
        })

    def section_of(time):
        for i in range(len(starts) - 1, -1, -1):
            if time >= starts[i] - 0.5:
                return i
        return 0

    count = 0
    for index, line in enumerate(lines):
        player = line['type'] == 1
        for n in line['notes']:
            lane = n['id'] % 4 + (0 if player else 4)  # psych_v1: 0-3 jugador, 4-7 rival
            note = [n['time'], lane, n.get('sLen', 0)]
            sections[section_of(n['time'])]['sectionNotes'].append(note)
            count += 1
    for section in sections:
        section['sectionNotes'].sort(key=lambda note: (note[0], note[1]))

    # eventos: los de Codename como "WoC <nombre>" con los parametros en JSON; Change Character, al de Psych
    psych_events = {}
    order = {'Scroll Speed Change': lambda e: e['params'][0] is True}  # a la vez: primero el fijo, luego el tween
    for e in sorted(events, key=lambda e: (e['time'], order.get(e['name'], lambda e: 0)(e))):
        if e['name'] == 'BPM Change':
            continue
        if e['name'] == 'Change Character':
            line, char = e['params'][0], e['params'][1]
            entry = ['Change Character', 'bf' if line == 1 else 'dad', CHARACTERS[char][0]]
        else:
            entry = ['WoC ' + e['name'], json.dumps(e['params'], separators=(',', ':')), '']
        psych_events.setdefault(e['time'], []).append(entry)

    out = {
        'song': 'World of Chaos', 'notes': sections, 'events': [[t, psych_events[t]] for t in sorted(psych_events)],
        'bpm': BPM_START, 'speed': chart.get('scrollSpeed', 2.4), 'needsVoices': True,
        'player1': 'woc-saori', 'player2': 'woc-monica-faker', 'gfVersion': 'gf', 'stage': 'club',
        'format': 'psych_v1', 'offset': 0, 'arrowSkin': '', 'splashSkin': '',
        # el game over lo hace ClubStage (WoCGameOver), sin personaje, sonido ni musica de Psych
    }
    write_json('data/%s/%s-hard.json' % (SONG, SONG), out)
    return count, sum(len(v) for v in psych_events.values())


# ---------------------------------------------------------------- escenario, HUD, sonidos
def port_assets():
    for folder in ('1', '2', '3'):
        for name in os.listdir(src('images', 'fondos', folder)):
            if name.startswith('ejemplo'):
                continue  # bocetos del autor, no se usan
            copy(src('images', 'fondos', folder, name), 'images/woc/bg/%s/%s' % (folder, name))
    for name, out in (('healthBarBG', 'healthBarBG'), ('healthBarBG2', 'healthBarBG2'), ('healthbar', 'healthBar')):
        copy(src('images', 'healthbar', name + '.png'), 'images/woc/hud/%s.png' % out)
    for icon, new in ICONS.items():
        copy(src('images', 'icons', icon + '.png'), 'images/icons/icon-%s.png' % new)
    for ext in ('png', 'xml'):
        copy(src('images', 'characters', 'saoriGameover.' + ext), 'images/woc/saoriGameover.' + ext)
    # pausa
    for name in ('pausebg', 'pausebar'):
        copy(src('images', 'Pausa', name + '.png'), 'images/woc/pause/%s.png' % name)
    for i in (1, 2, 3):
        copy(src('images', 'Pausa', 'Personajes', 'Fase %d.png' % i), 'images/woc/pause/fase%d.png' % i)
    for name in ('resume', 'reset', 'options', 'controls', 'exit'):
        for ext in ('png', 'xml'):
            copy(src('images', 'Pausa', 'buttons', '%s.%s' % (name, ext)), 'images/woc/pause/%s.%s' % (name, ext))
    # cuenta atras y calificaciones del mod ("stageUI": "woc"); numeros y "combo", los normales
    for name in ('ready', 'set', 'go'):
        copy(src('images', 'game', name + '.png'), 'images/wocUI/%s.png' % name)
    for name in ('sick', 'good', 'bad', 'shit'):
        copy(src('images', 'game', 'score', name + '.png'), 'images/wocUI/%s.png' % name)
    for name in ['combo'] + ['num%d' % i for i in range(10)]:
        copy(os.path.join(LISTS, 'images', name + '.png'), 'images/wocUI/%s.png' % name)
    # sonidos, musica, shaders y fuente
    copy(src('sounds', 'gameover_music.ogg'), 'sounds/woc/gameover_music.ogg')
    copy(src('sounds', 'reset.ogg'), 'sounds/woc/reset.ogg')
    for name in ('open', 'confirmMenu', 'scrollMenu'):
        copy(src('sounds', 'menu', name + '.ogg'), 'sounds/woc/%s.ogg' % name)
    copy(src('music', 'pausa_music.ogg'), 'music/woc/pausa_music.ogg')
    for name in ('adjustColor', 'distortion'):
        copy(src('shaders', name + '.frag'), 'shaders/woc-%s.frag' % name)
    copy(src('fonts', 'doki.ttf'), os.path.join(ROOT, 'assets', 'fonts', 'doki.ttf'))
    # audio de la cancion
    song_dir = src('songs', 'world of chaos', 'song')
    for name, out in (('Inst.ogg', 'Inst.ogg'), ('Voices-saori.ogg', 'Voices-Player.ogg'), ('Voices-monika.ogg', 'Voices-Opponent.ogg')):
        copy(os.path.join(song_dir, name), os.path.join(SONGS, SONG, out))


def port_stage(stage_xml):
    def pos(tag):
        node = stage_xml.find(tag)
        return [float(node.get('x', 0)), float(node.get('y', 0))]
    write_json('stages/club.json', {
        'directory': '', 'defaultZoom': 0.5,  # Script.hx: defaultCamZoom = 0.5
        'isPixelStage': False, 'stageUI': 'woc', 'hide_girlfriend': True,
        'boyfriend': pos('boyfriend'), 'opponent': pos('dad'), 'girlfriend': [0, 0],
        'camera_boyfriend': [0, 0], 'camera_opponent': [0, 0], 'camera_girlfriend': [0, 0], 'camera_speed': 1,
    })


def port_week_and_lists(names):
    week_path = os.path.join(SHARED, 'weeks', 'world1.json')
    with open(week_path, encoding='utf-8') as f:
        week = json.load(f)
    if not any(entry[0].lower().replace(' ', '-') == SONG for entry in week['songs']):
        week['songs'].append(['World of Chaos', 'woc-monica', [146, 113, 253]])  # meta.json: #9271FD
    with open(week_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(week, indent='\t', ensure_ascii=False) + '\n')
    add_to_list('data/stageList.txt', 'club')
    for name in names:
        add_to_list('data/characterList.txt', name)


def main():
    if not os.path.isdir(SRC):
        raise SystemExit('No existe la carpeta del mod: ' + SRC)
    stage_xml = ET.parse(src('data', 'stages', 'club.xml')).getroot()
    stage_cam = {tag: (float(stage_xml.find(tag).get('camxoffset', 0)), float(stage_xml.find(tag).get('camyoffset', 0)))
                 for tag in ('boyfriend', 'dad')}
    names = [convert_character(name, stage_cam) for name in CHARACTERS]
    notes, events = convert_chart()
    port_stage(stage_xml)
    port_assets()
    port_week_and_lists(names)
    total = sum(os.path.getsize(path) for path in set(copied))
    print('world of chaos: %d notas, %d eventos' % (notes, events))
    print('%d archivos, %.1f MB' % (len(set(copied)), total / 1048576))


if __name__ == '__main__':
    main()
