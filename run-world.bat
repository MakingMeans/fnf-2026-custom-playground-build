@echo off
REM Opens the compiled game straight into an overworld map, skipping title and menus.
REM Usage:  run-world.bat            -> opens the default map (hub)
REM         run-world.bat draft_world -> opens that map

call "%~dp0play.bat" -overworld %1
