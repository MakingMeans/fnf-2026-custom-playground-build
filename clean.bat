@echo off
cd /d "%~dp0"
title FNF 2026 Playground - Clean
color 0d

echo Esto borra la carpeta "export" (builds debug y release compiladas).
echo El codigo fuente, assets y librerias NO se tocan.
echo.
choice /c SN /m "Continuar? [S]i / [N]o"
if errorlevel 2 exit /b 0

if exist "export" (
    rmdir /s /q "export"
    echo Carpeta export borrada. La proxima compilacion sera desde cero.
) else (
    echo No hay nada que limpiar.
)
pause
