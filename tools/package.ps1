$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$infoPath = Join-Path $buildRoot "build_info.json"
if (-not (Test-Path -LiteralPath $infoPath)) { throw "Run tools/build.ps1 before packaging." }
$info = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json
if ($info.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw "Invalid build version." }
$packageName = "RigPop-$($info.version)-win64"
$stageParent = Join-Path $buildRoot ("package-" + [guid]::NewGuid().ToString("N"))
$releaseRoot = Join-Path $stageParent $packageName
$archive = Join-Path $buildRoot "$packageName.zip"
try {
    # Build from an explicit file list, never from a previously used portable directory.
    foreach ($relative in @("RigPop.exe", "RigPop.pck", "hosts/RigPopPet.exe", "hosts/RigPopPet.pck")) {
        $source = Join-Path $buildRoot $relative
        if (-not (Test-Path -LiteralPath $source)) { throw "Missing build output: $relative" }
        $target = Join-Path $releaseRoot $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    New-Item -ItemType Directory -Path (Join-Path $releaseRoot "licenses") -Force | Out-Null
    foreach ($license in Get-ChildItem -LiteralPath (Join-Path $projectRoot "licenses") -File) {
        Copy-Item -LiteralPath $license.FullName -Destination (Join-Path $releaseRoot "licenses")
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot "docs/user_guide.md") -Destination (Join-Path $releaseRoot "README.md")
    Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.md") -Destination $releaseRoot
    Copy-Item -LiteralPath $infoPath -Destination (Join-Path $releaseRoot "BUILD_INFO.json")
    $stagedArchive = Join-Path $stageParent "$packageName.zip"
    Compress-Archive -LiteralPath $releaseRoot -DestinationPath $stagedArchive
    Move-Item -LiteralPath $stagedArchive -Destination $archive -Force
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $packageName.zip" | Set-Content -LiteralPath (Join-Path $buildRoot "SHA256SUMS.txt") -Encoding ascii
    Write-Host "Archive: $archive"
    Write-Host "SHA256: $hash"
} finally {
    if (Test-Path -LiteralPath $stageParent) {
        if ((Split-Path -Parent ([IO.Path]::GetFullPath($stageParent))) -ne [IO.Path]::GetFullPath($buildRoot)) {
            throw "Refusing to remove a staging directory outside build/."
        }
        Remove-Item -LiteralPath $stageParent -Recurse -Force
    }
}
