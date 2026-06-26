# ============================================================
#  Black Breacher — automated headless playthrough regression test.
#  Drives the real main.tscn through the entire mission loop
#  (enter -> 3 waves -> boss -> objective -> mission clear) and
#  asserts every link. Exit 0 = PASS, 1 = FAIL.
#
#  Usage:   pwsh tools/run_playthrough.ps1 [path-to-godot.exe]
#  If no Godot path is given, it looks for the bundled 4.7 build.
# ============================================================
param(
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot   # repo root (tools/ is one level down)

if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    $candidates = @(
        "$env:USERPROFILE\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe",
        "C:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe"
    )
    $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Godot) { Write-Error "Godot 4.7 console exe not found. Pass its path as the first argument."; exit 2 }

$log = Join-Path $env:TEMP "bb_playthrough.log"
if (Test-Path $log) { Remove-Item $log -Force }

$pr = Start-Process -FilePath $Godot `
    -ArgumentList @("--headless","--path",$proj,"res://tests/playthrough/playthrough_bootstrap.tscn") `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -NoNewWindow
$pr.WaitForExit(120000) | Out-Null
if (-not $pr.HasExited) { $pr.Kill(); Write-Error "Playthrough timed out (120s wall)."; exit 3 }

$out = Get-Content $log -Raw
$out -split "`n" | Where-Object { $_ -match 'phase|PLAYTHROUGH' } | ForEach-Object { Write-Output $_.Trim() }

if ($out -match 'PLAYTHROUGH_OK') { exit 0 } else { exit 1 }
