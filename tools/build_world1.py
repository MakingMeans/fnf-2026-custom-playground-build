"""Genera el mundo 1 (`world1`) segun el boceto del usuario.

Uso:  python tools/build_world1.py

Escribe assets/shared/overworlds/world1.json y lo copia a las builds que existan (export/*/...),
para verlo sin recompilar. De momento es el grafo (nodos, caminos y desbloqueos) sobre el mar; el
arte con los tiles de SMW se anadira aqui mismo mas adelante. Si se edita el mundo en el editor,
NO volver a ejecutar este script: sobrescribiria esos cambios.

Boceto (de abajo arriba):
  - Isla baja: Inicio (punto de aparicion, no es nivel) con una tuberia encima; a la derecha
    yararara (primer nivel) y Bad Day en la esquina; de ahi sube a Chaos, el cruce de 3 caminos.
  - Desde Chaos, por unos escalones, a la meseta: Last Course y el castillo (World of Chaos); el
    camino sigue hacia el este.
  - Desde Chaos, a la izquierda y por el puente hacia el norte: Endless, que abre la salida secreta
    de Chaos (las 7 esmeraldas); el camino sigue hacia el norte.
  - La tuberia y los caminos del norte y del este no llevan a ningun sitio hasta que haya otros
    mundos: acaban en un punto de paso.
"""
import json
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'shared', 'overworlds', 'world1.json')
WEEK = 'world1'

LEVEL_LOOK = {'image': 'overworld/og_mario/level_tiles', 'anim': 'tile0002', 'animDone': 'tile0003', 'fps': 0}
CASTLE_LOOK = {'image': 'overworld/og_mario/level_blocks', 'anim': 'tile0010', 'animDone': '', 'fps': 0}
DOT_LOOK = {'image': 'overworld/dot', 'anim': 'idle', 'animDone': '', 'fps': 6}
PIPE_LOOK = {'image': 'overworld/pipe', 'anim': 'idle', 'animDone': '', 'fps': 6}


def node(node_id, x, y, name, kind='level', song='', look=None, unlocked=False, unlocks=None, secret=None):
    data = {
        'id': node_id, 'x': x, 'y': y, 'type': kind,
        'image': '', 'anim': '', 'animDone': '', 'fps': 0,
        'name': name, 'song': song, 'week': WEEK if kind == 'level' else '', 'difficulty': '', 'world': '',
        'unlocked': unlocked, 'unlocks': unlocks or [],
        'needLevels': 0, 'secretUnlocks': secret or [], 'secretMode': 'fc', 'secretMisses': 0, 'secretAccuracy': 95,
    }
    data.update(look or (LEVEL_LOOK if kind == 'level' else DOT_LOOK))
    return data


def path(a, b, points=None):
    return {'a': a, 'b': b, 'points': points or [], 'dots': 'overworld/dot', 'dotAnim': 'idle', 'dotSpacing': 16,
            'unlockedBy': '', 'secret': False}


def build():
    nodes = [
        node('inicio', 80, 272, 'Inicio', kind='empty', unlocked=True),
        node('tuberia', 80, 208, 'Tuberia (sin destino)', kind='empty', look=PIPE_LOOK, unlocked=True),
        node('yararara', 176, 272, 'YARARARA', song='yararara', unlocked=True, unlocks=['bad-day']),
        node('bad-day', 352, 272, 'Bad Day', unlocks=['chaos']),
        # salida normal: los escalones a la meseta; salida secreta (7 esmeraldas): el puente al norte
        node('chaos', 352, 200, 'Chaos', unlocks=['last-course'], secret=['endless']),
        node('last-course', 352, 88, 'Last Course', unlocks=['castillo']),
        node('castillo', 448, 88, 'World of Chaos', look=CASTLE_LOOK, unlocks=['camino-este']),
        node('endless', 208, 88, 'Endless', unlocks=['camino-norte']),
        node('camino-norte', 208, 24, 'Hacia el norte', kind='empty'),
        node('camino-este', 560, 88, 'Hacia el este', kind='empty'),
    ]
    paths = [
        path('inicio', 'tuberia'),
        path('inicio', 'yararara'),
        path('yararara', 'bad-day'),
        path('bad-day', 'chaos'),
        path('chaos', 'last-course'),
        path('last-course', 'castillo'),
        path('castillo', 'camino-este'),
        path('chaos', 'endless', [[208, 200]]),  # a la izquierda y luego al norte por el puente
        path('endless', 'camino-norte'),
    ]
    return {
        'displayName': 'Mundo 1',
        'bg': 'overworld/backgrounds/sea', 'bgAnim': 'idle', 'bgFps': 6, 'bgTile': True,
        'music': 'freakyMenu', 'zoom': 3, 'gridSize': 8, 'startNode': 'inicio',
        'player': 'overworld/overworld_bf', 'walkSpeed': 60,
        'nodes': nodes, 'sprites': [], 'paths': paths,
    }


def main():
    text = json.dumps(build(), indent='\t', ensure_ascii=False) + '\n'
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('-> ' + OUT)
    for kind in ('debug', 'release'):
        build_dir = os.path.join(ROOT, 'export', kind, 'windows', 'bin', 'assets', 'shared', 'overworlds')
        if os.path.isdir(build_dir):
            shutil.copyfile(OUT, os.path.join(build_dir, 'world1.json'))
            print('-> ' + build_dir)


if __name__ == '__main__':
    main()
