# Prueba automatica de una cancion con la build debug (ver source/states/SongTester.hx).
#
#   powershell -File tools/run_songtest.ps1 -Song yararara -WinShots "3,27,45,78"
#
# La juega en botplay de principio a fin (sin teclas simuladas). Con -WinShots, en esos segundos de
# cancion captura la ventana real (PrintWindow: incluye videos y shaders). Con -Shots, el juego
# guarda sus propias capturas en song_shots/ (no dibuja camaras con filtro de shader ni videos;
# -NoShaders quita el filtro para ver el escenario). Al acabar muestra song_test.txt y los errores
# de los scripts que salieron por consola.
#
# Game over: -Die 40 deja la vida a 0 en el segundo 40, -DeathShots "0.5,3,8" captura la ventana en
# esos segundos desde que se abre el game over y -DeathConfirm 10 pulsa "reintentar" a los 10 s.
# -Hit "Bad Poison": el bot tambien pulsa las notas de esos tipos (normalmente las deja pasar).
# -Skip "emerald": el bot deja pasar las notas de esos tipos (p. ej. jugar chaos sin esmeraldas).
# -Pause 30: abre el menu de pausa en el segundo 30, captura la ventana y acaba.
param(
	[Parameter(Mandatory = $true)][string]$Song,
	[string]$Shots = "",
	[string]$WinShots = "",
	[string]$Out = "$env:TEMP\fnf-songtest",
	[int]$TimeoutSec = 900,
	[switch]$NoShaders,
	[string]$Die = "",
	[string]$DeathShots = "",
	[string]$DeathConfirm = "",
	[string]$Hit = "",
	[string]$Skip = "",
	[string]$Pause = ""
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class SongTestWindow { [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
public struct RECT { public int L, T, R, B; } }
"@
$bin = Join-Path $PSScriptRoot "..\export\debug\windows\bin" | Resolve-Path
$shotDir = Join-Path $Out "winshots_$Song"
New-Item -ItemType Directory -Force $shotDir | Out-Null
Get-ChildItem $shotDir -Filter *.png | Remove-Item -Confirm:$false
Remove-Item "$bin\song_winshot.txt", "$bin\song_test.txt" -ErrorAction SilentlyContinue

$gameArgs = @("-song", $Song, "-test")
if ($Shots -ne "") { $gameArgs += @("-shots", $Shots) }
if ($WinShots -ne "") { $gameArgs += @("-winshots", $WinShots) }
if ($NoShaders) { $gameArgs += "-noshaders" }
if ($Die -ne "") { $gameArgs += @("-die", $Die) }
if ($DeathShots -ne "") { $gameArgs += @("-deathshots", $DeathShots) }
if ($DeathConfirm -ne "") { $gameArgs += @("-deathconfirm", $DeathConfirm) }
if ($Hit -ne "") { $gameArgs += @("-hit", "`"$Hit`"") }
if ($Skip -ne "") { $gameArgs += @("-skip", "`"$Skip`"") }
if ($Pause -ne "") { $gameArgs += @("-pause", $Pause) }
$log = Join-Path $Out "songtest_$Song.log"
$p = Start-Process -FilePath "$bin\FNF2026Playground.exe" -ArgumentList $gameArgs -WorkingDirectory $bin -RedirectStandardOutput $log -PassThru
$start = Get-Date
while (-not $p.HasExited -and ((Get-Date) - $start).TotalSeconds -lt $TimeoutSec) {
	if (Test-Path "$bin\song_winshot.txt") {
		$name = (Get-Content "$bin\song_winshot.txt" -Raw).Trim()
		$p.Refresh(); $h = $p.MainWindowHandle
		$r = New-Object SongTestWindow+RECT; [SongTestWindow]::GetWindowRect($h, [ref]$r) | Out-Null
		if (($r.R - $r.L) -gt 0) {
			$b = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T); $g = [System.Drawing.Graphics]::FromImage($b); $hdc = $g.GetHdc()
			[SongTestWindow]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $b.Save("$shotDir\$name.png")
		}
		Remove-Item "$bin\song_winshot.txt" -Confirm:$false
	}
	Start-Sleep -Milliseconds 100
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Confirm:$false; "TIMEOUT tras $TimeoutSec s" }
"== resultado"
Get-Content "$bin\song_test.txt" -ErrorAction SilentlyContinue
"== errores de scripts en consola"
Select-String -Path $log -Pattern "\[lua\]|Critical|Exception|ERROR|Error" | Select-Object -First 30 | ForEach-Object { $_.Line }
"== capturas de ventana en $shotDir"
Get-ChildItem $shotDir -Filter *.png -Name
