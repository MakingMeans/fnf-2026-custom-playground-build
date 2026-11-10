@echo off
REM Opens the already compiled game. Does NOT rebuild (use run.bat for that).

setlocal
set "ROOT=%~dp0"
set "DEBUG=%ROOT%export\debug\windows\bin\FNF2026Playground.exe"
set "RELEASE=%ROOT%export\release\windows\bin\FNF2026Playground.exe"

REM /D: the game must start inside its own folder. It looks for assets\ relative to the
REM working directory, so launching it from anywhere else (tests\, the repo root...) loads
REM nothing: empty worlds and the flixel "beep" looping instead of the music.
if exist "%DEBUG%" (
  start "" /D "%ROOT%export\debug\windows\bin" "%DEBUG%" %*
  exit /b 0
)

if exist "%RELEASE%" (
  start "" /D "%ROOT%export\release\windows\bin" "%RELEASE%" %*
  exit /b 0
)

echo No compiled build found.
echo Run run.bat once to compile the game.
pause
exit /b 1
