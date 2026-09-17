param([string]$Lune = (Join-Path $PSScriptRoot '..\.tools\lune\lune.exe'))
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Lune)) { throw 'Pass -Lune with the path to an installed Lune executable.' }
$Lune = (Resolve-Path -LiteralPath $Lune).Path
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & (Join-Path $PSScriptRoot 'SyncCore.ps1') -Check
    & (Join-Path $PSScriptRoot 'SyncSettings.ps1') -Check
    foreach ($suite in @('Validate', 'Startup', 'Runtime', 'Concurrency', 'Queues', 'FirstPersonCamera',
        'InteractionDetection', 'Containers', 'ContainerLabels', 'TaggedInteractions', 'Telephone', 'ReceiverMotion', 'Television', 'Throwing', 'PhoneRepair', 'Dialogue', 'Orders',
        'Prototype', 'PhoneGameplay', 'Pickup', 'Improvements', 'Engagement', 'ShiftPhases', 'PrototypeStartup', 'ShopDirection', 'Settings', 'CustomerAnimations', 'PrototypeStorage', 'HUDPanels', 'SystemLayout')) {
        & $Lune run "tests/$suite.luau"
        if ($LASTEXITCODE -ne 0) { throw "$suite failed with exit code $LASTEXITCODE" }
    }
} finally { Pop-Location }
