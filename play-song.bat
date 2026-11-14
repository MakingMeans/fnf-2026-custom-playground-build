@echo off
REM Opens the compiled game straight into a song, skipping title, menus and the map.
REM Usage:  play-song.bat yararara
REM When the song ends (or from the pause menu) you go to Freeplay.

if "%~1"=="" (
  echo Usage: play-song.bat ^<song^>
  echo Example: play-song.bat yararara
  pause
  exit /b 1
)

call "%~dp0play.bat" -song %1
