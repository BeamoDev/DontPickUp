param([switch]$Check)
# Compatibility command; common/ is the maintained source.
& (Join-Path $PSScriptRoot '../tools/SyncCommon.ps1') -Group Client -Check:$Check
