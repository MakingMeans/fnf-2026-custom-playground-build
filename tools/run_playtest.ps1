# Prueba jugable automatica del overworld con la build debug (ver source/states/OverworldPlaytest.hx).
#
#   powershell -File tools/run_playtest.ps1
#
# Monta los mundos de demostracion zz_demo* con las funciones del editor, los juega por codigo (sin
# teclas simuladas), los borra y cierra el juego. Muestra playtest_result.txt; las capturas que hace
# el propio juego quedan en export/debug/windows/bin/playtest_shots/.
param(
	[string]$Out = "$env:TEMP\fnf-playtest",
	[int]$TimeoutSec = 300
)
$bin = Join-Path $PSScriptRoot "..\export\debug\windows\bin" | Resolve-Path
New-Item -ItemType Directory -Force $Out | Out-Null
Remove-Item "$bin\playtest_result.txt" -ErrorAction SilentlyContinue

$log = Join-Path $Out "playtest_log.txt"
$p = Start-Process -FilePath "$bin\FNF2026Playground.exe" -ArgumentList "-playtest" -WorkingDirectory $bin -RedirectStandardOutput $log -PassThru
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
	Stop-Process -Id $p.Id -Confirm:$false
	"TIMEOUT: el juego seguia abierto tras $TimeoutSec s"
}
"== resultado"
if (Test-Path "$bin\playtest_result.txt") { Get-Content "$bin\playtest_result.txt" }
else { "(sin playtest_result.txt)"; Get-Content $log | Where-Object { $_ -match "PLAYTEST|rror|xception" } | Select-Object -Last 30 }
"== capturas en $bin\playtest_shots"
Get-ChildItem "$bin\playtest_shots" -Filter *.png -Name -ErrorAction SilentlyContinue
