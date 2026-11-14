$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$files = @("core/character.gd", "core/input_router.gd", "services/project_store.gd", "runtime/shared/character_view.gd", "runtime/game/controller.gd", "runtime/game/character.tscn", "runtime/game/world.gd", "runtime/game/world.tscn")
foreach ($relative in $files) {
    $destination = Join-Path $projectRoot "exporters/templates/$relative.txt"
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $destination
}
