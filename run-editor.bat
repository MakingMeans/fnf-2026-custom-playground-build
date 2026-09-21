@echo off
REM Opens the compiled game straight into the Overworld Editor, skipping the menus.
REM Optional: pass a world name to open it directly, e.g.  run-editor.bat draft_world

call "%~dp0play.bat" -overworld-editor %1
