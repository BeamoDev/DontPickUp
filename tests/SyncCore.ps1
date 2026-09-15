param([switch]$Check)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'src\LServer\Core'
$target = Join-Path $repo 'src\GServer\Core'
if (-not $Check) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
foreach ($file in Get-ChildItem -LiteralPath $source -File -Filter '*.luau') {
    $destination = Join-Path $target $file.Name
    if ($Check) {
        if (-not (Test-Path -LiteralPath $destination)) { throw "Missing Game copy: $($file.Name)" }
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
            throw "Core copies differ: $($file.Name)"
        }
    } else {
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }
}
foreach ($file in Get-ChildItem -LiteralPath $target -File -Filter '*.luau') {
    if (-not (Test-Path -LiteralPath (Join-Path $source $file.Name))) { throw "Unexpected Game Core file: $($file.Name)" }
}
Write-Output 'Lobby and Game server Core copies match.'
