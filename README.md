# FNF 2026 Custom Playground

Build personal de *Friday Night Funkin'* basada en [Psych Engine](https://github.com/ShadowMario/FNF-PsychEngine) (commit `5c67ced`, versión 1.0 pre-release, marzo 2025) para experimentar y modificar el código fuente libremente.

El README original de Psych Engine está en [docs/PSYCH_ENGINE_README.md](docs/PSYCH_ENGINE_README.md) y sus instrucciones de compilación en [docs/BUILDING.md](docs/BUILDING.md).

## Puesta en marcha (Windows)

Scripts disponibles, en el orden en que se usan:

| Script | Qué hace |
|---|---|
| `check-dependencies.bat` | Comprueba Git, Haxe ≥ 4.3.4 y el compilador C++ de Visual Studio. Instala lo que falte con `winget`. Después crea un repositorio haxelib **local** en `.haxelib/` e instala todas las librerías con las versiones exactas que necesita el engine. |
| `run.bat` | Compila en modo *debug* y abre el juego (`lime test windows -debug`). Úsalo mientras programas. |
| `build-release.bat` | Genera la build final optimizada en `export/release/windows/bin` y abre la carpeta. Ese directorio completo es lo que se distribuye. |
| `clean.bat` | Borra `export/` para forzar una compilación desde cero (útil ante errores raros del linker). |

1. Ejecuta `check-dependencies.bat`. Si instala algún programa nuevo, te pedirá cerrar y volver a ejecutarlo (para que se actualice el PATH).
2. Ejecuta `run.bat`. La primera compilación tarda entre 5 y 10 minutos; las siguientes solo recompilan lo que cambió.
3. Cuando quieras una build para compartir, `build-release.bat`.

Los scripts aceptan argumentos extra que se pasan a lime, por ejemplo `run.bat -clean` o `build-release.bat -D officialBuild`.

### Si compilas desde una terminal en vez de con los .bat

Define antes la variable `HAXELIB_PATH` apuntando al `.haxelib` del proyecto:

```bat
set HAXELIB_PATH=%CD%\.haxelib
haxelib run lime test windows -debug
```

Motivo: cuando lime lanza hxcpp para compilar el C++ (desde `export\...\obj`), hxcpp resuelve las librerías con el repositorio haxelib **global** en vez del `.haxelib` del proyecto, y falla con `Could not find haxelib "hxvlc"`. `HAXELIB_PATH` tiene prioridad sobre cualquier otra detección, así que fuerza el repositorio correcto en toda la cadena. Los .bat y las tareas de VS Code ya la definen.

## Dónde está cada cosa

- [source/](source/) — código Haxe del engine. Punto de entrada: [source/Main.hx](source/Main.hx). Estados del juego en `source/states/`, lógica de la partida en `source/states/PlayState.hx`, sistemas en `source/backend/`.
- [Project.xml](Project.xml) — configuración de lime/openfl: nombre del ejecutable, ventana, librerías, defines (`LUA_ALLOWED`, `HSCRIPT_ALLOWED`, `VIDEOS_ALLOWED`, `BASE_GAME_FILES`, etc.).
- [assets/](assets/) — assets hardcodeados del juego. `assets/base_game/` contiene las semanas y canciones del juego original.
- [example_mods/](example_mods/) — se copian a `mods/` junto al ejecutable; mods softcodeados (Lua/HScript) que se cargan sin recompilar.
- `.haxelib/` (ignorado por git) — librerías Haxe de este proyecto, aisladas de las globales.
- `export/` (ignorado por git) — salidas de compilación.

## Cambios respecto a Psych Engine original

- `Project.xml`: nombre, ejecutable, package y company renombrados a este proyecto (v0.1.0).
- `Project.xml`: `BASE_GAME_FILES` y `VIDEOS_ALLOWED` activados fuera de `officialBuild`, para que la build incluya el contenido base y soporte de vídeo sin flags extra.
- Contenido del juego base reducido al **Tutorial**: se eliminaron las semanas 1-7 y Weekend 1 (charts, canciones, personajes, stages, vídeos, fondos de menú, logros semanales). `assets/base_game/` solo conserva el chart y audio del tutorial, la canción `test` del chart editor, el stage por defecto (`week1/`) y el stage `stage.json`.
- Código: se borraron los scripts de stage de esas semanas (`source/states/stages/`) y sus objetos auxiliares; `PlayState` solo enlaza `stage`, `StageData.vanillaSongStage` siempre devuelve `stage`, y `Achievements` ya no define los logros por semana.
- Listas hardcodeadas (`assets/shared/weeks/weekList.txt`, `data/stageList.txt`, `data/characterList.txt`) reducidas a `tutorial`, `stage` y `bf`/`gf`.
- Scripts `.bat` en la raíz y configuración de VS Code (`.vscode/`) con tareas y extensiones recomendadas (`nadako.vshaxe`, `openfl.lime-vscode-extension`).

## Licencia

El engine se distribuye bajo la licencia Apache 2.0 de Psych Engine (ver [LICENSE](LICENSE)). Créditos completos en [docs/PSYCH_ENGINE_README.md](docs/PSYCH_ENGINE_README.md).
