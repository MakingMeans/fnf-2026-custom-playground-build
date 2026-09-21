@echo off
REM Opens the already compiled game. Does NOT rebuild (use run.bat for that).

setlocal
set "ROOT=%~dp0"
set "DEBUG=%ROOT%export\debug\windows\bin\FNF2026Playground.exe"
set "RELEASE=%ROOT%export\release\windows\bin\FNF2026Playground.exe"

if exist "%DEBUG%" (
  start "" "%DEBUG%" %*
  exit /b 0
)

if exist "%RELEASE%" (
  start "" "%RELEASE%" %*
  exit /b 0
)

echo No compiled build found.
echo Run run.bat once to compile the game.
pause
exit /b 1
