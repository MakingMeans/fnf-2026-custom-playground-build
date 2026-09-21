@echo off
REM Copies the worlds saved by the in-game Overworld Editor back into the repo assets.
REM The editor already tries to write both copies, this script is the manual fallback.

setlocal
set "ROOT=%~dp0"
set "TARGET=%ROOT%assets\shared\overworlds"

if not exist "%TARGET%" mkdir "%TARGET%"

call :copyFrom "%ROOT%export\debug\windows\bin\assets\shared\overworlds"
call :copyFrom "%ROOT%export\release\windows\bin\assets\shared\overworlds"

echo.
echo Done. Worlds are in: %TARGET%
pause
exit /b 0

:copyFrom
if not exist "%~1" exit /b 0
echo Copying from %~1
copy /Y "%~1\*.json" "%TARGET%" >nul
exit /b 0
