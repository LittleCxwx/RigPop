param([string]$Godot = "godot", [string]$Python = "python")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot "build"
$zig = Join-Path $buildRoot "native-toolchain/ziglang/zig.exe"
if (-not (Test-Path -LiteralPath $zig)) {
    & $Python -m pip install --target (Join-Path $buildRoot "native-toolchain") ziglang==0.13.0
    if ($LASTEXITCODE -ne 0) { throw "Could not install the pinned native compiler." }
}
Push-Location $buildRoot
try {
    & $Godot --headless --dump-gdextension-interface
    if ($LASTEXITCODE -ne 0) { throw "Could not generate GDExtension headers." }
} finally { Pop-Location }
$destination = Join-Path $projectRoot "platform/windows/bin"
New-Item -ItemType Directory -Path $destination -Force | Out-Null
& $zig c++ -target x86_64-windows-gnu -shared -O2 -s -fno-exceptions -fno-rtti -I $buildRoot (Join-Path $projectRoot "platform/windows/rigpop_windows.cpp") -o (Join-Path $destination "rigpop_windows.dll") -luser32 -lcomctl32
if ($LASTEXITCODE -ne 0) { throw "Native Windows integration build failed." }
