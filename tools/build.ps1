param([string]$Godot = "godot", [string]$Icon = "")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command $Godot -ErrorAction SilentlyContinue)) { throw "Set -Godot to Godot 4.7.2 console executable." }
$version = & $Godot --version
if ($version -notlike "4.7.2.*") { throw "Expected Godot 4.7.2; received $version" }
& (Join-Path $PSScriptRoot "sync_templates.ps1")
New-Item -ItemType Directory -Path (Join-Path $projectRoot "build/hosts") -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "build/templates/windows_release_x86_64.exe"))) {
    throw "Missing Godot 4.7.2 Windows release template. Run tools/download_windows_template.py first."
}
$prepareArgs = @("--headless", "--path", $projectRoot, "--script", "res://tools/prepare_build.gd")
if ($Icon) { $prepareArgs += @("--", "--icon", (Resolve-Path -LiteralPath $Icon).Path) }
$prepareLog = & $Godot @prepareArgs 2>&1
$prepareCode = $LASTEXITCODE
$prepareLog | Set-Content -LiteralPath (Join-Path $projectRoot "build/prepare.log")
if ($prepareCode -ne 0 -or ($prepareLog -match "SCRIPT ERROR|Failed to load script")) { throw "Build preparation failed. See build/prepare.log" }
$importLog = & $Godot --headless --path $projectRoot --editor --import --quit 2>&1
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
