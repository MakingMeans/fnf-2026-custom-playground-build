@echo off
cd /d "%~dp0"
title FNF 2026 Playground - Run (debug)
color 0a

if not exist ".haxelib" (
    echo No se encontro la carpeta .haxelib con las librerias del proyecto.
    echo Ejecuta primero check-dependencies.bat
    pause
    exit /b 1
)

:: Fuerza el repositorio haxelib local del proyecto. Sin esto, hxcpp (que se
:: ejecuta desde export\...\obj) no encuentra .haxelib y usa las librerias globales.
set "HAXELIB_PATH=%~dp0.haxelib"

echo ================================================================
echo  Compilando y ejecutando en modo DEBUG (Windows x64)
echo  La primera compilacion puede tardar 5-10 minutos. Las siguientes
echo  son mucho mas rapidas (solo se recompila lo que cambio).
echo  Salida: export\debug\windows\bin
echo ================================================================
echo.

haxelib run lime test windows -debug %*
if errorlevel 1 (
    echo.
    color 0c
    echo ================================================================
    echo  Error al compilar o ejecutar. Revisa los mensajes de arriba.
    echo  Si el error es "LNK1120: unresolved externals", ejecuta clean.bat
    echo  y vuelve a intentarlo.
    echo ================================================================
    pause
    exit /b 1
)
echo.
echo Juego cerrado.
