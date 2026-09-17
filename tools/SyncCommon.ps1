param([switch]$Check, [ValidateSet('All', 'Server', 'Client')][string]$Group = 'All')
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifest = Get-Content -LiteralPath (Join-Path $repo 'project.sources.json') -Raw | ConvertFrom-Json
function Resolve-ProjectPath([string]$relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $repo $relative))
    if (-not $path.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Mapping escapes the project: $relative"
    }
    return $path
}
$count = 0
foreach ($module in $manifest.CommonModules) {
    if ($Group -ne 'All' -and $module.Group -ne $Group) { continue }
    $source = Resolve-ProjectPath $module.Source
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing common source: $($module.Source)" }
    foreach ($relative in $module.Targets) {
        $target = Resolve-ProjectPath $relative
        if ($relative -notmatch '^src/[GL](Server|Client)/[^/]+/[^/]+\.luau$') { throw "Invalid deployment target: $relative" }
        if ($Check) {
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing deployment: $relative. Run tools/SyncCommon.ps1." }
            if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
                throw "Common deployment differs: $relative. Edit $($module.Source), then run tools/SyncCommon.ps1."
            }
        } else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        $count += 1
    }
}
Write-Output "Common $Group package: $count deployments $(if ($Check) { 'verified' } else { 'synchronized' })."
