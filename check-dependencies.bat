@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title FNF 2026 Playground - Check dependencies
color 0b

echo ================================================================
echo   FNF 2026 Custom Playground - Verificacion de dependencias
echo ================================================================
echo.
echo  Este script comprueba y, si hace falta, instala:
echo    1. Git
echo    2. Haxe (4.3.4 o superior) + haxelib
echo    3. Visual Studio C++ Build Tools (compilador para Windows)
echo    4. Librerias Haxe del proyecto (en la carpeta local .haxelib)
echo.
echo  Requiere winget (viene con Windows 10/11) para instalar programas.
echo ================================================================
echo.

set NEED_RESTART=0

:: ---------------------------------------------------------------- Git
echo [1/4] Comprobando Git...
where git >nul 2>&1
if errorlevel 1 (
    echo   Git NO encontrado. Instalando con winget...
    winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo   ERROR: no se pudo instalar Git. Instalalo manualmente desde https://git-scm.com/downloads
        goto :fail
    )
    set NEED_RESTART=1
) else (
    for /f "tokens=3" %%v in ('git --version') do echo   OK - Git %%v
)
echo.

:: ---------------------------------------------------------------- Haxe
echo [2/4] Comprobando Haxe...
where haxe >nul 2>&1
if errorlevel 1 (
    echo   Haxe NO encontrado. Instalando con winget...
    winget install -e --id HaxeFoundation.Haxe --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo   ERROR: no se pudo instalar Haxe. Instalalo manualmente desde https://haxe.org/download/
        goto :fail
    )
    set NEED_RESTART=1
) else (
    for /f "tokens=1" %%v in ('haxe --version') do set HAXEVER=%%v
    echo   OK - Haxe !HAXEVER!
    for /f "tokens=1,2,3 delims=." %%a in ("!HAXEVER!") do (
        set /a HX_MAJOR=%%a
        set /a HX_MINOR=%%b
        set /a HX_PATCH=%%c
    )
    set HX_TOO_OLD=0
    if !HX_MAJOR! LSS 4 set HX_TOO_OLD=1
    if !HX_MAJOR! EQU 4 if !HX_MINOR! LSS 3 set HX_TOO_OLD=1
    if !HX_MAJOR! EQU 4 if !HX_MINOR! EQU 3 if !HX_PATCH! LSS 4 set HX_TOO_OLD=1
    if !HX_TOO_OLD! EQU 1 (
        echo   La version de Haxe es demasiado antigua. Se necesita 4.3.4 o superior. Actualizando...
        winget upgrade -e --id HaxeFoundation.Haxe --accept-package-agreements --accept-source-agreements
        set NEED_RESTART=1
    )
)
where haxelib >nul 2>&1
if errorlevel 1 (
    if !NEED_RESTART! EQU 0 (
        echo   ERROR: haxelib no esta en el PATH aunque Haxe si. Reinstala Haxe.
        goto :fail
    )
)
echo.

:: ---------------------------------------------------------------- Visual Studio C++
echo [3/4] Comprobando Visual Studio C++ Build Tools...
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSINSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\setup.exe"
set "VC_COMPONENTS=--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041"
set VCPATH=
set VSANY=
if exist "%VSWHERE%" (
    for /f "usebackq delims=" %%p in (`"%VSWHERE%" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VCPATH=%%p"
    for /f "usebackq delims=" %%p in (`"%VSWHERE%" -latest -products * -property installationPath`) do set "VSANY=%%p"
)
if defined VCPATH (
    echo   OK - Compilador C++ encontrado en: !VCPATH!
) else if defined VSANY (
    echo   Hay Visual Studio en "!VSANY!" pero SIN el componente C++ x64. Anadiendolo...
    "%VSINSTALLER%" modify --installPath "!VSANY!" %VC_COMPONENTS% --passive --norestart --wait
    if errorlevel 1 (
        echo   ERROR: no se pudo modificar Visual Studio. Abre "Visual Studio Installer" y anade
        echo          "Desarrollo para el escritorio con C++" manualmente.
        goto :fail
    )
) else (
    echo   No hay Visual Studio. Instalando "Visual Studio 2022 Build Tools" con C++ ^(puede tardar varios minutos^)...
    winget install -e --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --override "--wait --passive --norestart %VC_COMPONENTS%"
    if errorlevel 1 (
        echo   ERROR: no se pudo instalar Build Tools. Descargalo desde:
        echo          https://visualstudio.microsoft.com/visual-cpp-build-tools/
        echo          y marca "Desarrollo para el escritorio con C++".
        goto :fail
    )
)
echo.

if !NEED_RESTART! EQU 1 (
    echo ================================================================
    echo  Se instalaron programas nuevos. Cierra esta ventana y vuelve a
    echo  ejecutar check-dependencies.bat para instalar las librerias
    echo  Haxe ^(el PATH se actualiza al abrir una consola nueva^).
    echo ================================================================
    pause
    exit /b 0
)

:: ---------------------------------------------------------------- Librerias Haxe
echo [4/4] Instalando librerias Haxe del proyecto...
echo   Se usa un repositorio LOCAL en ".haxelib" para no tocar tus librerias globales.
if not exist ".haxelib" (
    haxelib newrepo
    if errorlevel 1 (
        echo   ERROR: no se pudo crear el repositorio local .haxelib
        goto :fail
    )
)
set "HAXELIB_PATH=%~dp0.haxelib"
echo   Esto puede tardar unos minutos segun tu conexion...
echo.

call :hl install hxcpp                 || goto :fail
call :hl install hxcpp-debug-server    || goto :fail
call :hl install lime 8.1.2            || goto :fail
call :hl install openfl 9.3.3          || goto :fail
call :hl install flixel 5.6.1          || goto :fail
call :hl install flixel-addons 3.2.2   || goto :fail
call :hl install flixel-tools 1.5.1    || goto :fail
call :hl install hscript-iris 1.1.3    || goto :fail
call :hl install tjson 1.4.0           || goto :fail
call :hl install hxdiscord_rpc 1.2.4   || goto :fail
call :hl install hxvlc 2.0.1 --skip-dependencies || goto :fail
call :hl set lime 8.1.2                || goto :fail
call :hl set openfl 9.3.3              || goto :fail
call :hl set flixel 5.6.1              || goto :fail
call :hl set flixel-addons 3.2.2       || goto :fail
call :hl git flxanimate  https://github.com/Dot-Stuff/flxanimate            768740a56b26aa0c072720e0d1236b94afe68e3e || goto :fail
call :hl git linc_luajit https://github.com/superpowers04/linc_luajit       1906c4a96f6bb6df66562b3f24c62f4c5bba14a7 || goto :fail
call :hl git funkin.vis  https://github.com/FunkinCrew/funkVis              22b1ce089dd924f15cdc4632397ef3504d464e90 || goto :fail
call :hl git grig.audio  https://gitlab.com/haxe-grig/grig.audio.git        cbf91e2180fd2e374924fe74844086aab7891666 || goto :fail

echo.
echo   Librerias instaladas:
haxelib list
echo.
echo ================================================================
echo  TODO LISTO. Ya puedes usar:
echo    run.bat            - compila y abre el juego (debug)
echo    build-release.bat  - genera la build final en export\release
echo ================================================================
pause
exit /b 0

:hl
echo   ^> haxelib %*
haxelib %* --always --quiet
if errorlevel 1 (
    echo   ERROR ejecutando: haxelib %*
    exit /b 1
)
exit /b 0

:fail
echo.
color 0c
echo ================================================================
echo  La verificacion FALLO. Revisa el error de arriba.
echo ================================================================
pause
exit /b 1
