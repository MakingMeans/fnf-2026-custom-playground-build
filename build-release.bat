@echo off
cd /d "%~dp0"
title FNF 2026 Playground - Build release
color 0e

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
echo  Compilando build RELEASE (Windows x64) para distribuir
echo  Salida: export\release\windows\bin
echo  Esa carpeta completa es lo que se comparte/empaqueta en un .zip
echo ================================================================
echo.

haxelib run lime build windows -release %*
if errorlevel 1 (
    echo.
    color 0c
    echo ================================================================
    echo  Error al compilar. Revisa los mensajes de arriba.
    echo  Si el error es "LNK1120: unresolved externals", ejecuta clean.bat
    echo  y vuelve a intentarlo.
    echo ================================================================
    pause
    exit /b 1
)

echo.
echo ================================================================
echo  Build lista en: %~dp0export\release\windows\bin
echo ================================================================
start "" explorer.exe "%~dp0export\release\windows\bin"
pause
