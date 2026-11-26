param([string]$Python = "python", [switch]$SkipInstall)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$venv = Join-Path $projectRoot "build/psd-venv"
$runtime = Join-Path $venv "Scripts/python.exe"
if (-not (Test-Path -LiteralPath $runtime)) {
    & $Python -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw "Could not create PSD build environment." }
}
if (-not $SkipInstall) {
    & $runtime -m pip install -r (Join-Path $PSScriptRoot "psd/requirements.txt")
    if ($LASTEXITCODE -ne 0) { throw "Could not install PSD build dependencies." }
}
& $runtime -m PyInstaller --noconfirm --clean --onedir --name RigPopPsd --collect-all psd_tools --distpath (Join-Path $projectRoot "build/helpers/psd") --workpath (Join-Path $projectRoot "build/psd-work") --specpath (Join-Path $projectRoot "build") (Join-Path $PSScriptRoot "psd/import_psd.py")
if ($LASTEXITCODE -ne 0) { throw "PSD helper build failed." }
$licenseRoot = Join-Path $projectRoot "build/helpers/psd/RigPopPsd/licenses"
New-Item -ItemType Directory -Path $licenseRoot -Force | Out-Null
$pythonBase = & $runtime -c "import sys; print(sys.base_prefix)"
foreach ($license in Get-ChildItem -LiteralPath $pythonBase -File -Filter "LICENSE*") {
    Copy-Item -LiteralPath $license.FullName -Destination (Join-Path $licenseRoot "Python-$($license.Name)")
}
foreach ($metadata in Get-ChildItem -LiteralPath (Join-Path $venv "Lib/site-packages") -Directory -Filter "*.dist-info") {
    foreach ($entry in Get-ChildItem -LiteralPath $metadata.FullName -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|COPYING|NOTICE)' }) {
        $destination = Join-Path $licenseRoot "$($metadata.Name)/$($entry.Name)"
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $entry.FullName -Destination $destination
    }
}
