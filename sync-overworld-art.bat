@echo off
REM Copies assets/shared/images/overworld/ into the compiled builds so new sprites
REM show up in the Overworld Editor without a full rebuild.

setlocal
set "ROOT=%~dp0"
set "SOURCE=%ROOT%assets\shared\images\overworld"

if not exist "%SOURCE%" (
  echo Source folder not found: %SOURCE%
  pause
  exit /b 1
)

call :copyTo "%ROOT%export\debug\windows\bin\assets\shared\images\overworld"
call :copyTo "%ROOT%export\release\windows\bin\assets\shared\images\overworld"

echo.
echo Done.
pause
exit /b 0

:copyTo
if not exist "%~dp1" exit /b 0
echo Copying to %~1
xcopy "%SOURCE%" "%~1" /E /I /Y >nul
exit /b 0
