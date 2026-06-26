# ============================================================
#  Black Breacher — one-command web build pipeline.
#  Installs the Godot 4.7 export templates if missing, writes the Web
#  export preset, exports a single-threaded HTML5 build to build/web,
#  and (optionally) serves it locally for a browser playtest.
#
#  Usage:
#    pwsh tools/build_web.ps1            # build only
#    pwsh tools/build_web.ps1 -Serve     # build, then serve at :8765
#
#  The build is single-threaded (no SharedArrayBuffer) so it runs on ANY
#  static host with no COOP/COEP headers. Verified: boots Godot + WebGL +
#  the game autoload in-browser (console shows "[BB] boot ...").
# ============================================================
param([switch]$Serve)
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot
$godot = "$env:USERPROFILE\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
$tplDir = "$env:APPDATA\Godot\export_templates\4.7.stable"

# 1. Templates — install from the official .tpz if not already present.
if (-not (Test-Path "$tplDir\web_nothreads_release.zip")) {
    Write-Host "Export templates missing. Download Godot_v4.7-stable_export_templates.tpz from"
    Write-Host "  https://github.com/godotengine/godot-builds/releases/tag/4.7-stable"
    Write-Host "then extract its templates/* into: $tplDir"
    Write-Host "(Or install via the editor: Project > Manage Export Templates > Download and Install.)"
    exit 2
}

# 2. Export preset (regenerated each run; no secrets — safe, single-threaded).
@'
[preset.0]
name="Web"
platform="Web"
runnable=true
export_path="build/web/index.html"

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
html/export_icon=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
'@ | Set-Content -Encoding utf8 "$proj\export_presets.cfg"

# 3. Export.
$out = Join-Path $proj "build\web"
New-Item -ItemType Directory -Force $out | Out-Null
& $godot --headless --path $proj --export-release "Web" "$out\index.html" 2>&1 |
    Select-String -Pattern 'ERROR|error|Failed' | Select-Object -First 10
Get-ChildItem $out -Filter "*.tmp" -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Host "=== build/web ==="
Get-ChildItem $out | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,2)}}

# 4. Optional local serve for a browser playtest.
if ($Serve) {
    Write-Host "Serving at http://localhost:8765/index.html  (Ctrl+C to stop)"
    & python -m http.server 8765 --directory $out
}
