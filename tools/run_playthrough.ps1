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
$pr.WaitForExit(240000) | Out-Null
if (-not $pr.HasExited) { $pr.Kill(); Write-Error "Playthrough timed out (240s wall)."; exit 3 }
$pr.WaitForExit() | Out-Null   # no-arg wait settles ExitCode after a timed wait

# The driver encodes the verdict in its process exit code (quit 0 = pass,
# quit 1 = fail). That is authoritative — the final stdout line can be lost
# to pipe buffering on a fast exit, so do NOT grade by grepping stdout.
$out = Get-Content $log -Raw
$out -split "`n" | Where-Object { $_ -match 'PLAYTHROUGH|mission .* cleared|resupply|upgrade applied|NAV_POLYS' } | ForEach-Object { Write-Output $_.Trim() }

# Verdict: prefer the driver's process exit code (quit 0 = pass, 1 = fail).
# If it didn't settle, fall back to the stdout marker (which can be lost to
# pipe buffering on a fast exit — hence the exit code is primary).
$code = $pr.ExitCode
if ($null -eq $code) {
    if ($out -match 'PLAYTHROUGH_OK') { $code = 0 } else { $code = 1 }
}
$verdict = if ($code -eq 0) { "PASS" } else { "FAIL" }
Write-Output "--- playthrough verdict: $verdict (exit $code) ---"
exit $code
