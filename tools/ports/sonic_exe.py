"""Importa "chaos" (FLEETWAY) y "endless-us" (MAJIN) de Vs Sonic.exe (carpeta sanic) a este juego.

Uso:  python tools/ports/sonic_exe.py [carpeta sanic]
      (por defecto C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/sanic)
Necesita Pillow (para pasar las imagenes .webp a .png).

El mod es un Psych 1.0.4 modificado y compilado. Charts, personajes, escenarios y scripts van DENTRO
de "Vs Sonic.exe" como recursos de Haxe: este script los saca de la tabla de recursos de hxcpp
(cada entrada: nombre, tamano y puntero a los datos; el manifiesto manifest/default.json dice que
nombre lleva cada archivo). Las imagenes estan fuera, en .webp, y algunas recortadas: el exe trae
contents/shared/data/image_trims.json con [x, y, ancho original, alto original, ancho, alto] y aqui
se les devuelve su tamano original para que las coordenadas del mod sigan valiendo.

La logica que el mod tenia en su motor (camara por posiciones, esmeraldas, laser, HUD...) va en
Haxe: source/states/stages/SonicStage.hx, FleetwayStage.hx (chaos) y MajinStage.hx (endless-us).
Los scripts Lua que solo usan funciones normales de Psych se copian como scripts de la cancion.
Es idempotente: se puede volver a ejecutar.
"""
import io
import json
import math
import os
import re
import shutil
import struct
import sys
import urllib.parse

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else 'C:/Users/david/Downloads/QsychEngine2.0/QsychEngine2.0/sanic'
EXE = os.path.join(SRC, 'Vs Sonic.exe')
SHARED = os.path.join(ROOT, 'assets', 'base_game', 'shared')
SONGS = os.path.join(ROOT, 'assets', 'base_game', 'songs')
LISTS = os.path.join(ROOT, 'assets', 'shared')

copied = []


# ---------------------------------------------------------------- manifiesto (serializacion de Haxe)
class _Unserializer:
    def __init__(self, text):
        self.s, self.p, self.scache = text, 0, []

    def _int(self):
        start = self.p
        if self.s[self.p] == '-':
            self.p += 1
        while self.p < len(self.s) and self.s[self.p].isdigit():
            self.p += 1
        return int(self.s[start:self.p])

    def read(self):
        c = self.s[self.p]
        self.p += 1
        if c == 'n':
            return None
        if c in 'tf':
            return c == 't'
        if c == 'z':
            return 0
        if c == 'i':
            return self._int()
        if c == 'd':
            start = self.p
            while self.s[self.p] in '0123456789.-+eE':
                self.p += 1
            return float(self.s[start:self.p])
        if c == 'y':
            length = self._int()
            self.p += 1  # ':'
            value = urllib.parse.unquote(self.s[self.p:self.p + length])
            self.p += length
            self.scache.append(value)
            return value
        if c == 'R':
            return self.scache[self._int()]
        if c == 'a':
            out = []
            while self.s[self.p] != 'h':
                out.append(self.read())
            self.p += 1
            return out
        if c == 'o':
            out = {}
            while self.s[self.p] != 'g':
                key = self.read()
                out[key] = self.read()
            self.p += 1
            return out
        raise ValueError('token %r en %d' % (c, self.p - 1))


# ---------------------------------------------------------------- recursos del exe
class ExeResources:
    def __init__(self, exe_path):
        self.data = open(exe_path, 'rb').read()
        d = self.data
        pe = struct.unpack_from('<I', d, 0x3C)[0]
        nsec = struct.unpack_from('<H', d, pe + 6)[0]
        opt_size = struct.unpack_from('<H', d, pe + 20)[0]
        opt = pe + 24
        self.image_base = struct.unpack_from('<Q', d, opt + 24)[0]
        self.sections = []
        for i in range(nsec):
            off = opt + opt_size + i * 40
            vsize, va, rawsize, rawptr = struct.unpack_from('<IIII', d, off + 8)
            self.sections.append((va, vsize, rawptr, rawsize))

    def _va_to_off(self, addr):
        rva = addr - self.image_base
        for va, vsize, rawptr, rawsize in self.sections:
            if va <= rva < va + rawsize:
                return rawptr + (rva - va)
        return None

    def _off_to_va(self, off):
        for va, vsize, rawptr, rawsize in self.sections:
            if rawptr <= off < rawptr + rawsize:
                return self.image_base + va + (off - rawptr)
        return None

    def get(self, class_name, size):
        """Datos del recurso de lime "__ASSET__:file_<className>" (comprueba su tamano)."""
        d = self.data
        name_off = d.find(('__ASSET__:file_' + class_name).encode() + b'\0')
        if name_off < 0:
            raise SystemExit('No esta en el exe: ' + class_name)
        ref = d.find(struct.pack('<Q', self._off_to_va(name_off)))
        _, _, length, ptr = struct.unpack_from('<qQqQ', d, ref - 8)
        if length != size:
            raise SystemExit('Tamano inesperado de %s: %d (manifiesto: %d)' % (class_name, length, size))
        if length == 0:
            return b''
        start = self._va_to_off(ptr)
        return d[start:start + length]


class Mod:
    def __init__(self, root):
        self.root = root
        manifest = json.load(open(os.path.join(root, 'manifest', 'default.json'), encoding='utf-8'))
        self.assets = {a['id']: a for a in _Unserializer(manifest['assets']).read()}
        self.exe = ExeResources(EXE)
        self.trims = json.loads(self.read('contents/shared/data/image_trims.json').decode('utf-8'))

    def read(self, asset_id):
        asset = self.assets.get(asset_id)
        if asset is not None and 'className' in asset:
            return self.exe.get(asset['className'], asset.get('size', 0))
        path = os.path.join(self.root, *asset_id.split('/'))
        if not os.path.exists(path):
            raise SystemExit('No existe en el mod: ' + asset_id)
        return open(path, 'rb').read()

    def text(self, asset_id):
        return self.read(asset_id).decode('utf-8-sig')

    def json(self, asset_id):
        return json.loads(self.text(asset_id))

    def image(self, asset_id_noext):
        """PNG de una imagen .webp del mod, con el margen que le quito su recorte."""
        img = Image.open(io.BytesIO(self.read(asset_id_noext + '.webp'))).convert('RGBA')
        key = asset_id_noext.split('contents/', 1)[-1]
        trim = self.trims.get(key)
        if trim:
            x, y, width, height = trim[:4]
            full = Image.new('RGBA', (width, height), (0, 0, 0, 0))
            full.paste(img, (x, y))
            img = full
        out = io.BytesIO()
        img.save(out, 'PNG', optimize=True)
        return out.getvalue()


# ---------------------------------------------------------------- atlas de Animate: offsets de flixel-animate
class AnimateBounds:
    """Recuadro de cada simbolo de un atlas de Animate, calculado como flixel-animate.

    El mod dibuja sus personajes de atlas con flixel-animate, que coloca cada animacion respecto al
    recuadro de todo el timeline de su simbolo (Timeline.getWholeBounds: union de todos sus
    fotogramas, sin capas ocultas ni mascaras y con el margen de los filtros), y escala desde el centro
    del recuadro del timeline principal. Nuestro flxanimate dibuja el simbolo en sus coordenadas
    propias y escala desde (0, 0). Para que se vean igual: offset nuestro = offset del mod
    + esquina del recuadro * escala - centro principal * (1 - escala) (ver convert_atlas_offsets).
    """

    def __init__(self, folder):
        anim = json.load(open(os.path.join(folder, 'Animation.json'), encoding='utf-8-sig'))
        sheet = json.load(open(os.path.join(folder, 'spritemap1.json'), encoding='utf-8-sig'))
        self.sprites = {}
        for entry in sheet['ATLAS']['SPRITES']:
            s = entry['SPRITE']
            self.sprites[s['name']] = (s['h'], s['w']) if s.get('rotated') else (s['w'], s['h'])
        self.main = anim['AN']['SN']
        self.symbols = {self.main: anim['AN']['TL']}
        for s in anim.get('SD', {}).get('S', []):
            self.symbols[s['SN']] = s['TL']
        self.counts = {name: max([sum(fr['DU'] for fr in layer.get('FR', [])) for layer in tl['L']] or [0])
                       for name, tl in self.symbols.items()}
        self.cache = {}

    @staticmethod
    def _matrix(el):
        m = el.get('M3D') or el.get('Matrix3D')
        if isinstance(m, dict):
            return (m['m00'], m['m01'], m['m10'], m['m11'], m['m30'], m['m31'])
        if m is None:
            mx = el.get('MX') or el.get('Matrix')
            return tuple(mx) if mx else (1, 0, 0, 1, 0, 0)
        return (m[0], m[1], m[4], m[5], m[12], m[13])

    @staticmethod
    def _mul(p, q):  # q y luego p
        a, b, c, d, tx, ty = p
        e, f, g, h, ux, uy = q
        return (a * e + c * f, b * e + d * f, a * g + c * h, b * g + d * h, a * ux + c * uy + tx, b * ux + d * uy + ty)

    @staticmethod
    def _union(r, s):
        if r is None:
            return s
        if s is None:
            return r
        return (min(r[0], s[0]), min(r[1], s[1]), max(r[2], s[2]), max(r[3], s[3]))

    @staticmethod
    def _frame(layer, index):
        for fr in layer.get('FR', []):
            if fr['I'] <= index < fr['I'] + fr['DU']:
                return fr
        return None

    def _sub_index(self, si, index):
        """SymbolInstance.getFrameIndex (sin LF, que estos atlas no traen)."""
        first = si.get('FF', 0)
        count = self.counts.get(si['SN'], 0)
        loop = si.get('LP', 'LP')
        if count <= 0:
            return 0
        if loop in ('SF', 'singleframe'):
            return first
        if loop in ('PO', 'playonce'):
            return first + min(index, count - first - 1)
        return (first + index) % count

    @staticmethod
    def _filter_margin(filters):
        """FilterRenderer.expandFilterBounds para desenfoque, resplandor y sombra."""
        if isinstance(filters, dict):
            filters = [dict(v, _type=k) for k, v in filters.items()]
        left = top = right = bottom = 0
        for f in filters or []:
            kind = f.get('_type') or f.get('N') or ''
            bx = math.ceil(f.get('BLX', f.get('blurX', 0)) or 0)
            by = math.ceil(f.get('BLY', f.get('blurY', 0)) or 0)
            if kind in ('BLF', 'blurFilter') or (kind in ('GF', 'glowFilter') and not f.get('IN')):
                left, right, top, bottom = left + bx, right + bx, top + by, bottom + by
            elif kind in ('DSF', 'dropShadowFilter'):
                dist, ang = f.get('D', 4), f.get('AL', 45)
                ox, oy = int(dist * math.cos(math.radians(ang))), int(dist * math.sin(math.radians(ang)))
                left += math.ceil(max(-ox, 0) + bx)
                right += math.ceil(max(ox, 0) + bx)
                top += math.ceil(max(-oy, 0) + by)
                bottom += math.ceil(max(oy, 0) + by)
        return left, top, right, bottom

    def _element(self, el, local, m, depth):
        if 'SI' in el:
            si = el['SI']
            if si['SN'] not in self.symbols:
                return None
            r = self._timeline(si['SN'], self._sub_index(si, local), self._mul(m, self._matrix(si)), depth + 1)
            if r is not None and si.get('F') and si.get('ST') in ('MC', 'movieclip'):
                l, t, rr, b = self._filter_margin(si['F'])
                r = (r[0] - l, r[1] - t, r[2] + rr, r[3] + b)
            return r
        if 'ASI' in el:
            asi = el['ASI']
            w, h = self.sprites.get(asi['N'], (0, 0))
            mm = self._mul(m, self._matrix(asi))
            xs = [mm[0] * x + mm[2] * y + mm[4] for x, y in ((0, 0), (w, 0), (0, h), (w, h))]
            ys = [mm[1] * x + mm[3] * y + mm[5] for x, y in ((0, 0), (w, 0), (0, h), (w, h))]
            return (min(xs), min(ys), max(xs), max(ys))
        return None

    def _timeline(self, name, index, m, depth=0):
        if depth > 40:
            return None
        layers = self.symbols[name]['L']
        rect = None
        for i, layer in enumerate(layers):
            if layer.get('LT') in ('Clp', 'Clipper'):
                continue  # las mascaras no se dibujan
            mask = None
            if layer.get('Clpb') is not None:
                mask = next((l for l in reversed(layers[:i]) if l.get('LN') == layer['Clpb'] and l.get('LT') in ('Clp', 'Clipper')), None)
                if mask is None:
                    continue  # enmascarada por una capa que no existe: flixel-animate la oculta
            fr = self._frame(layer, index)
            if fr is None or not fr.get('E'):
                continue
            r = None
            for el in fr['E']:
                r = self._union(r, self._element(el, index - fr['I'], m, depth))
            if r is not None and mask is not None:
                mfr = self._frame(mask, index)
                mr = None
                for el in (mfr or {}).get('E', []):
                    mr = self._union(mr, self._element(el, index - mfr['I'], m, depth))
                if mr is not None:
                    r = (max(r[0], mr[0]), max(r[1], mr[1]), min(r[2], mr[2]), min(r[3], mr[3]))
            rect = self._union(rect, r)
        return rect

    def whole(self, name):
        """(x, y, ancho, alto) de todo el timeline del simbolo."""
        if name not in self.cache:
            rect = None
            for i in range(self.counts.get(name, 0)):
                rect = self._union(rect, self._timeline(name, i, (1, 0, 0, 1, 0, 0)))
            self.cache[name] = (0, 0, 0, 0) if rect is None else (rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1])
        return self.cache[name]


def convert_atlas_offsets(data, atlas_rel):
    """Pasa los offsets de un personaje de atlas del mod (flixel-animate) a los de nuestro flxanimate."""
    bounds = AnimateBounds(os.path.join(SHARED, 'images', *atlas_rel.split('/')))
    scale = data.get('scale', 1)
    main = bounds.whole(bounds.main)
    # origen: centro del recuadro del timeline principal, con el tamano entero (frameWidth/frameHeight)
    origin_x, origin_y = int(main[2]) * 0.5, int(main[3]) * 0.5
    for anim in data['animations']:
        name = anim['name']
        if name not in bounds.symbols:
            print('  aviso: %s no tiene el simbolo "%s"' % (atlas_rel, name))
            continue
        box = bounds.whole(name)
        offsets = anim.get('offsets') or [0, 0]
        anim['offsets'] = [round(offsets[0] + box[0] * scale - origin_x * (1 - scale), 1),
                           round(offsets[1] + box[1] * scale - origin_y * (1 - scale), 1)]
    return main


def write(rel, data):
    path = os.path.join(SHARED, *rel.split('/')) if not os.path.isabs(rel) else rel
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data if isinstance(data, bytes) else data.encode('utf-8'))
    copied.append(path)


def write_json(rel, value):
    write(rel, json.dumps(value, indent='\t', ensure_ascii=False) + '\n')


def add_to_list(list_file, entry):
    path = os.path.join(LISTS, *list_file.split('/'))
    with open(path, encoding='utf-8') as f:
        lines = [line.strip() for line in f.read().splitlines()]
    if entry in lines:
        return
    lines = [line for line in lines if line] + [entry]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def replace_once(text, old, new, what):
    if text.count(old) < 1:
        raise SystemExit('No encuentro en %s: %r' % (what, old))
    return text.replace(old, new)


# ---------------------------------------------------------------- chaos (FLEETWAY)
CHAOS_CHARACTERS = {  # personaje del mod -> aqui
    'bffletway': 'chaos-bf',
    'fletway': 'chaos-fleetway',
    'bffleet-dead': 'chaos-bf-dead',
}
CHAOS_CHARACTER_IMAGES = {  # imagen del personaje en el mod -> aqui (las dos primeras son atlas de Animate)
    'characters/bfchaos': 'characters/chaos/bf',
    'characters/super sonic': 'characters/chaos/fleetway',
    'characters/DEAHT': 'characters/chaos/bf-dead',
}
CHAOS_ICONS = {'bffleet': 'chaos-bf', 'bfsuperfleet': 'chaos-bf-super', 'fleet': 'chaos-fleetway'}
# imagenes sueltas (con .xml si son atlas Sparrow): ruta del mod sin extension -> aqui
CHAOS_IMAGES = {
    'bg/1': 'chaos/bg/1', 'bg/2': 'chaos/bg/2', 'bg/3': 'chaos/bg/3', 'bg/4': 'chaos/bg/4',
    'bg/eat': 'chaos/bg/eat', 'bg/puelco': 'chaos/bg/puelco', 'bg/rayo': 'chaos/bg/rayo',
    'grad': 'chaos/grad', 'hud/emerald': 'chaos/hud/emerald', 'hud/hud_chaos': 'chaos/hud/hud_chaos',
    'spacebar': 'chaos/spacebar',
}
CHAOS_IMAGES.update({'bg/emerals/' + c: 'chaos/bg/emerals/' + c
                     for c in ('green', 'yellow', 'blue', 'purple', 'gray', 'cyan', 'red', 'master')})
CHAOS_ATLASES = {'bg/sonic': 'chaos/bg/sonic'}
CHAOS_SOUNDS = ['beam', 'emerald', 'laser_moment', 'robot', 'sonicscream', 'SUPERBF'] + ['voicelines/%d' % i for i in range(1, 13)]


def port_image(mod, src_noext, dst_noext):
    """Imagen suelta: .webp -> .png (con su margen) y su .xml si lo tiene."""
    write('images/%s.png' % dst_noext, mod.image(src_noext))
    if src_noext + '.xml' in mod.assets or os.path.exists(os.path.join(mod.root, *(src_noext + '.xml').split('/'))):
        write('images/%s.xml' % dst_noext, mod.read(src_noext + '.xml'))


def port_atlas(mod, src_folder, dst_folder):
    """Atlas de Animate: Animation.json y spritemap1.json salen del exe y spritemap1.webp se pasa a .png."""
    write('images/%s/Animation.json' % dst_folder, mod.read(src_folder + '/Animation.json'))
    write('images/%s/spritemap1.json' % dst_folder, mod.read(src_folder + '/spritemap1.json'))
    write('images/%s/spritemap1.png' % dst_folder, mod.image(src_folder + '/spritemap1'))


def port_characters(mod, folder, names, images, icons):
    atlases = set()
    for old, new in images.items():
        src = 'contents/%s/images/%s' % (folder, old)
        if src + '/Animation.json' in mod.assets:
            port_atlas(mod, src, new)
            atlases.add(new)
        else:
            port_image(mod, src, new)
    for old, new in names.items():
        data = mod.json('contents/%s/characters/%s.json' % (folder, old))
        data['image'] = images[data['image']]
        data['healthicon'] = icons.get(data['healthicon'], data['healthicon'])
        data.pop('_editor_isPlayer', None)
        if data['image'] in atlases:
            convert_atlas_offsets(data, data['image'])
        write_json('characters/%s.json' % new, data)
    for old, new in icons.items():
        src = 'contents/%s/images/icons/%s' % (folder, old)
        if src + '.webp' not in mod.assets:
            src = 'contents/%s/images/icons/icon-%s' % (folder, old)
        write('images/icons/icon-%s.png' % new, mod.image(src))


def port_chart(mod, src_id, dst_song, names, stage, arrow_skin, extra=None):
    chart = mod.json(src_id)
    chart = chart.get('song', chart) if isinstance(chart.get('song'), dict) else chart
    chart['player1'] = names[chart['player1']]
    chart['player2'] = names[chart['player2']]
    chart['gfVersion'] = 'gf'
    chart['stage'] = stage
    chart['arrowSkin'] = arrow_skin
    chart['splashSkin'] = None
    chart['disableNoteRGB'] = True
    chart['format'] = 'psych_v1'  # el mod ya las guardaba con los carriles de Psych 1.0 (psych_v1_convert)
    chart.pop('validScore', None)
    if extra:
        chart.update(extra)
    write_json('data/%s/%s-hard.json' % (dst_song, dst_song), chart)
    return sum(len(sec['sectionNotes']) for sec in chart['notes']), sum(len(e[1]) for e in chart.get('events', []))


def port_audio(mod, folder, song, files):
    for name in files:
        data = mod.read('contents/%s/songs/%s/%s' % (folder, song, name))
        path = os.path.join(SONGS, song, name)
        write(path, data)


def port_week_and_lists(songs, stages, characters):
    week_path = os.path.join(SHARED, 'weeks', 'world1.json')
    with open(week_path, encoding='utf-8') as f:
        week = json.load(f)
    for title, icon, color in songs:
        folder = title.lower().replace(' ', '-')
        if not any(entry[0].lower().replace(' ', '-') == folder for entry in week['songs']):
            week['songs'].append([title, icon, color])
    with open(week_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(week, indent='\t', ensure_ascii=False) + '\n')
    for stage in stages:
        add_to_list('data/stageList.txt', stage)
    for name in characters:
        add_to_list('data/characterList.txt', name)


# ---------------------------------------------------------------- endless-us (MAJIN)
ENDLESS_CHARACTERS = {'bf m': 'endless-us-bf', 'majin': 'endless-us-majin'}
ENDLESS_CHARACTER_IMAGES = {'characters/BOYFRIEND': 'characters/endless-us/bf', 'characters/USendless': 'characters/endless-us/majin'}
ENDLESS_ICONS = {'bf': 'endless-us-bf', 'majin': 'endless-us-majin'}
ENDLESS_STAGE_IMAGES = ['bg', '33', '3', '22', '2', '11', '1', 'a', 'three', 'two', 'one', 'gofun']
ENDLESS_SHADERS = ['chromabber', 'brightness', 'blackwhite', 'DropShadowShader']


def port_endless_stage(mod):
    stage = mod.json('contents/MAJIN/stages/majin.json')
    stage['directory'] = ''
    stage.pop('preload', None)
    stage.pop('_editorMeta', None)
    for obj in stage['objects']:
        if 'image' in obj:
            obj['image'] = obj['image'].replace('majin/', 'endless-us/stage/', 1)
    write_json('stages/majin.json', stage)

    lua = mod.text('contents/MAJIN/stages/majin.lua')
    lua = re.sub(r'path = "majin/', 'path = "endless-us/stage/', lua)
    lua = replace_once(lua, "playSound('sonic sfx', 0.8, 'USSpin')", "playSound('endless-us/sonic sfx', 0.8, 'USSpin')", 'majin.lua')
    write('stages/majin.lua', lua.replace('\r\n', '\n'))
    for name in ENDLESS_STAGE_IMAGES:
        port_image(mod, 'contents/MAJIN/images/majin/' + name, 'endless-us/stage/' + name)


def port_endless_scripts(mod):
    out = 'data/endless-us/'
    write(out + 'script.lua', mod.text('contents/MAJIN/data/endless-us/script.lua').replace('\r\n', '\n'))
    # evento propio de la cancion (en custom_events/ seria global)
    lua = mod.text('contents/MAJIN/custom_events/changenoteSkin.lua').replace('\r\n', '\n')
    lua = lua.replace("'noteSkins/NOTE_assets_ENDLESS'", "'endless-us/noteSkins/NOTE_assets_ENDLESS'")
    lua = lua.replace("'noteSkins/'..", "'endless-us/noteSkins/'..")
    write(out + 'event-changenoteskin.lua', lua)
    write(out + 'events.json', mod.read('contents/MAJIN/data/endless-us/events.json'))
    for name in ENDLESS_SHADERS:
        write('shaders/endless-us-%s.frag' % name, mod.read('contents/MAJIN/shaders/%s.frag' % name))
    port_image(mod, 'contents/MAJIN/images/noteSkins/NOTE_assets_ENDLESS', 'endless-us/noteSkins/NOTE_assets_ENDLESS')
    write('sounds/endless-us/sonic sfx.ogg', mod.read('contents/MAJIN/sounds/sonic sfx.ogg'))


def port_endless_game_over(mod):
    """Game over de endless-us: el BF muerto general del mod (atlas "game over"), los majins y sus sonidos."""
    port_atlas(mod, 'assets/shared/images/characters/game over', 'characters/endless-us/bf-dead')
    data = mod.json('assets/shared/characters/bf-dead.json')
    data['image'] = 'characters/endless-us/bf-dead'
    data['healthicon'] = 'endless-us-bf'
    data.pop('_editor_isPlayer', None)
    convert_atlas_offsets(data, data['image'])
    write_json('characters/endless-us-bf-dead.json', data)
    port_atlas(mod, 'contents/MAJIN/images/gameovers/us/us', 'endless-us/gameover/us')
    port_image(mod, 'contents/MAJIN/images/gameovers/us/evil majin', 'endless-us/gameover/evil majin')
    port_image(mod, 'contents/MAJIN/images/hud/blueVg', 'endless-us/hud/blueVg')
    write('sounds/endless-us/death.ogg', mod.read('contents/MAJIN/sounds/deathSounds/endless-us-sfx.ogg'))
    for name in ('firstLOOK', 'secondLOOK'):
        write('sounds/endless-us/%s.ogg' % name, mod.read('contents/MAJIN/sounds/deathSounds/%s.ogg' % name))
    write('music/endless-us/gameOver.ogg', mod.read('contents/MAJIN/music/deathSongs/endless-us.ogg'))
    write('music/endless-us/gameOverEnd.ogg', mod.read('contents/MAJIN/music/gameOverEnd.ogg'))


def port_common(mod):
    """Lo que usan las dos canciones: skin de notas, splashes (noteSplashGlobal.lua) y la fuente de la cuenta atras."""
    port_image(mod, 'assets/shared/images/noteSkins/NOTENORMAL_assets', 'sonic_exe/NOTENORMAL_assets')
    for name in ('noteSplashes', 'noteSplashes-endless-us', 'holds/noteSplashesHOLD', 'holds/noteSplashesHOLD-endless-us'):
        port_image(mod, 'contents/images/exeSplashes/' + name, 'sonic_exe/splashes/' + name)
    # las fuentes van compiladas como clases (no como recursos), pero el mod deja una copia en disco
    with open(os.path.join(mod.root, 'assets', 'fonts', 'SonicCD.ttf'), 'rb') as f:
        write(os.path.join(ROOT, 'assets', 'fonts', 'SonicCD.ttf'), f.read())


def port_chaos(mod):
    notes, events = port_chart(mod, 'contents/FLEETWAY/data/chaos/chaos.json', 'chaos', CHAOS_CHARACTERS, 'fleetw',
                               'sonic_exe/NOTENORMAL_assets', {
                                   # gameOver.hx del mod (bffleet-dead, laser_moment y la musica de FLEETWAY)
                                   'gameOverChar': 'chaos-bf-dead', 'gameOverSound': 'chaos/laser_moment',
                                   'gameOverLoop': 'chaos/gameOver', 'gameOverEnd': 'chaos/gameOverEnd'})
    stage = mod.json('contents/FLEETWAY/stages/fleetw.json')
    stage.update({'stageUI': 'normal', 'camera_boyfriend': [0, 0], 'camera_opponent': [0, 0], 'camera_girlfriend': [0, 0], 'camera_speed': 1})
    write_json('stages/fleetw.json', stage)
    for name in ('cameraSettings.json', 'lyrics.json', 'healthProps.json'):
        write('data/chaos/' + name, mod.read('contents/FLEETWAY/data/chaos/' + name))
    port_characters(mod, 'FLEETWAY', CHAOS_CHARACTERS, CHAOS_CHARACTER_IMAGES, CHAOS_ICONS)
    for old, new in CHAOS_IMAGES.items():
        port_image(mod, 'contents/FLEETWAY/images/' + old, new)
    for old, new in CHAOS_ATLASES.items():
        port_atlas(mod, 'contents/FLEETWAY/images/' + old, new)
    for name in CHAOS_SOUNDS:
        write('sounds/chaos/%s.ogg' % name, mod.read('contents/FLEETWAY/sounds/%s.ogg' % name))
    for name in ('gameOver', 'gameOverEnd'):
        write('music/chaos/%s.ogg' % name, mod.read('contents/FLEETWAY/music/%s.ogg' % name))
    port_audio(mod, 'FLEETWAY', 'chaos', ['Inst.ogg', 'Voices.ogg', 'Voices-Opponent.ogg'])
    print('chaos: %d notas, %d eventos' % (notes, events))


def port_endless(mod):
    notes, events = port_chart(mod, 'contents/MAJIN/data/endless-us/endless-us.json', 'endless-us', ENDLESS_CHARACTERS, 'majin',
                               'sonic_exe/NOTENORMAL_assets', {
                                   # raimbow death screens.hx del mod (bf-dead general y los sonidos de MAJIN)
                                   'gameOverChar': 'endless-us-bf-dead', 'gameOverSound': 'endless-us/death',
                                   'gameOverLoop': 'endless-us/gameOver', 'gameOverEnd': 'endless-us/gameOverEnd'})
    for name in ('cameraSettings.json', 'healthProps.json'):
        write('data/endless-us/' + name, mod.read('contents/MAJIN/data/endless-us/' + name))
    port_characters(mod, 'MAJIN', ENDLESS_CHARACTERS, ENDLESS_CHARACTER_IMAGES, ENDLESS_ICONS)
    port_endless_stage(mod)
    port_endless_scripts(mod)
    port_endless_game_over(mod)
    port_image(mod, 'contents/MAJIN/images/hud/hud_majin', 'endless-us/hud/hud_majin')
    for name in ('circle', 'text'):
        port_image(mod, 'contents/images/StartScreens/endless-us/' + name, 'endless-us/StartScreen/' + name)
    port_audio(mod, 'MAJIN', 'endless-us', ['Inst.ogg', 'Voices.ogg'])
    print('endless-us: %d notas, %d eventos (+ events.json)' % (notes, events))


def main():
    if not os.path.isdir(SRC):
        raise SystemExit('No existe la carpeta del mod: ' + SRC)
    mod = Mod(SRC)
    port_common(mod)
    port_chaos(mod)
    port_endless(mod)
    port_week_and_lists(
        [('Chaos', 'chaos-fleetway', [146, 113, 253]), ('Endless US', 'endless-us-majin', [0, 15, 255])],
        ['fleetw', 'majin'],
        list(CHAOS_CHARACTERS.values()) + list(ENDLESS_CHARACTERS.values()) + ['endless-us-bf-dead'])
    total = sum(os.path.getsize(path) for path in set(copied))
    print('Vs Sonic.exe: %d archivos, %.1f MB' % (len(set(copied)), total / 1048576))


if __name__ == '__main__':
    main()
