param([string]$Archive = "")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
if (-not $Archive) {
    $info = Get-Content -LiteralPath (Join-Path $buildRoot "build_info.json") -Raw | ConvertFrom-Json
    $Archive = Join-Path $buildRoot "RigPop-$($info.version)-win64.zip"
}
$Archive = (Resolve-Path -LiteralPath $Archive).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("RigPop-release-check-" + [guid]::NewGuid().ToString("N"))
$zip = [IO.Compression.ZipFile]::OpenRead($Archive)
try {
    foreach ($entry in $zip.Entries) {
        $entryPath = [IO.Path]::GetFullPath((Join-Path $testRoot $entry.FullName))
        if (-not $entryPath.StartsWith($testRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Archive entry escapes its extraction directory."
        }
        if ($entry.FullName -match '(^|[/\\])(\.git|\.godot|portable_data|templates|tests|tools|core|editor|services|runtime|exporters)([/\\]|$)') {
            throw "Development or user data found in release archive: $($entry.FullName)"
        }
    }
} finally { $zip.Dispose() }
Expand-Archive -LiteralPath $Archive -DestinationPath $testRoot
$roots = @(Get-ChildItem -LiteralPath $testRoot -Directory)
if ($roots.Count -ne 1) { throw "Expected one portable application directory." }
$releaseRoot = $roots[0].FullName
foreach ($relative in @("RigPop.exe", "RigPop.pck", "hosts/RigPopPet.exe", "hosts/RigPopPet.pck", "BUILD_INFO.json", "README.md", "THIRD_PARTY_NOTICES.md", "licenses/Godot-MIT.txt", "licenses/Godot-COPYRIGHT.txt", "licenses/Noto-OFL.txt", "licenses/Lucide.txt")) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot $relative) -PathType Leaf)) { throw "Missing release dependency: $relative" }
}

function Invoke-ReleaseCheck([string]$Executable, [string[]]$Arguments, [string]$Log) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw "Release check timed out: $Executable"
    }
    if ($process.ExitCode -ne 0) { throw "Release check failed (exit $($process.ExitCode)). See $Log" }
    $content = Get-Content -LiteralPath $Log -Raw
    if ($content -match 'SCRIPT ERROR|Failed to load script|Error loading resource|Failed loading resource') { throw "Runtime errors found in $Log" }
}

$editorLog = Join-Path $testRoot "editor.log"
Invoke-ReleaseCheck (Join-Path $releaseRoot "RigPop.exe") @("--headless", "--log-file", ('"{0}"' -f $editorLog), "--", "--verify-install") $editorLog
$reports = @(Get-ChildItem -LiteralPath (Join-Path $releaseRoot "portable_data") -Filter verification.json -Recurse -File)
if ($reports.Count -ne 1) { throw "Missing or ambiguous installation verification report." }
$report = Get-Content -LiteralPath $reports[0].FullName -Raw | ConvertFrom-Json
if (@($report.errors).Count -ne 0 -or @($report.outputs.PSObject.Properties).Count -ne 3) { throw "Save, reopen or export verification failed." }
$pet = @(Get-ChildItem -LiteralPath $reports[0].DirectoryName -Filter RigPopPet.exe -Recurse -File)
if ($pet.Count -ne 1) { throw "Desktop executable was not exported." }
$petLog = Join-Path $testRoot "pet.log"
Invoke-ReleaseCheck $pet[0].FullName @("--headless", "--log-file", ('"{0}"' -f $petLog), "--quit-after", "10") $petLog
@{
    archive = $Archive
    sha256 = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    extracted_directory = $releaseRoot
    installation_report = $reports[0].FullName
    editor_exit_code = 0
    desktop_exit_code = 0
    errors = @()
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $buildRoot "release-verification.json") -Encoding utf8
Write-Host "PASS: extracted release starts, saves, reopens, exports all three formats and runs the exported desktop character."
Write-Host "Isolated verification directory: $testRoot"
