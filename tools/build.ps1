param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command $Godot -ErrorAction SilentlyContinue)) { throw "Set -Godot to Godot 4.7.2 console executable." }
$version = & $Godot --version
if ($version -notlike "4.7.2.*") { throw "Expected Godot 4.7.2; received $version" }
$sourceFiles = @("core/character.gd", "core/input_router.gd", "services/project_store.gd", "runtime/shared/character_view.gd", "runtime/game/controller.gd", "runtime/game/character.tscn", "runtime/game/world.gd", "runtime/game/world.tscn")
foreach ($relative in $sourceFiles) {
    $destination = Join-Path $projectRoot "exporters/templates/$relative.txt"
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $destination
}
New-Item -ItemType Directory -Path (Join-Path $projectRoot "build/hosts") -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "build/templates/windows_release_x86_64.exe"))) {
    throw "Missing Godot 4.7.2 Windows release template. Run tools/download_windows_template.py first."
}
$importLog = & $Godot --headless --path $projectRoot --editor --import 2>&1
$importCode = $LASTEXITCODE
$importLog | Set-Content -LiteralPath (Join-Path $projectRoot "build/import.log")
if ($importCode -ne 0 -or ($importLog -match "SCRIPT ERROR|Failed to load script")) { throw "Godot import failed. See build/import.log" }
foreach ($preset in @("RigPop", "DesktopHost")) {
    $exportLog = & $Godot --headless --path $projectRoot --export-release $preset 2>&1
    $exportCode = $LASTEXITCODE
    $exportLog | Set-Content -LiteralPath (Join-Path $projectRoot "build/export-$preset.log")
    if ($exportCode -ne 0 -or ($exportLog -match "SCRIPT ERROR|Failed to load script")) { throw "Export failed: $preset. See build/export-$preset.log" }
}
Write-Host "Editor: $(Join-Path $projectRoot 'build/RigPop.exe')"
Write-Host "Desktop host: $(Join-Path $projectRoot 'build/hosts/RigPopPet.exe')"
