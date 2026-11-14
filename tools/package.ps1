$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$releaseRoot = Join-Path $buildRoot "RigPop-0.1.0-win64"
foreach ($relative in @("RigPop.exe", "RigPop.pck", "hosts/RigPopPet.exe", "hosts/RigPopPet.pck")) {
    $source = Join-Path $buildRoot $relative
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing build output: $relative" }
    $target = Join-Path $releaseRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}
New-Item -ItemType Directory -Path (Join-Path $releaseRoot "licenses") -Force | Out-Null
foreach ($license in Get-ChildItem -LiteralPath (Join-Path $projectRoot "licenses") -File) {
    Copy-Item -LiteralPath $license.FullName -Destination (Join-Path $releaseRoot "licenses") -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot "docs/user_guide.md") -Destination (Join-Path $releaseRoot "README.md") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.md") -Destination $releaseRoot -Force
$archive = Join-Path $buildRoot "RigPop-0.1.0-win64.zip"
Compress-Archive -LiteralPath $releaseRoot -DestinationPath $archive -Force
Write-Host "Portable directory: $releaseRoot"
Write-Host "Archive: $archive"
