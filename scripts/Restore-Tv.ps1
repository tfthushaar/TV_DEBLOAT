<#
.SYNOPSIS
  Undo Invoke-Debloat.ps1. Re-enables every package from the latest change log,
  or with -All every disabled package listed in packages.json.

.DESCRIPTION
  Uses `pm enable`, and falls back to `pm install-existing` for packages that were
  removed for user 0 by other means (for example the original brief's `pm uninstall --user 0`).
  A factory reset (Settings > System > Reset) also restores every stock package.
#>
[CmdletBinding()]
param([string]$Serial, [string]$Log, [switch]$All)

. "$PSScriptRoot\Common.ps1"

$Serial = Get-TvSerial $Serial
$cfg    = Get-Content (Join-Path $script:RepoRoot 'packages.json') -Raw | ConvertFrom-Json

if ($All) {
    $targets = @(Get-PackageSet $Serial '-d' | Where-Object { $cfg.packages.name -contains $_ })
} else {
    if (-not $Log) {
        $pointer = Join-Path $script:SnapshotRoot 'latest-changes.json'
        if (-not (Test-Path $pointer)) { throw 'No change log found. Use -All, or pass -Log <path to changes.json>.' }
        $Log = (Get-Content $pointer -Raw | ConvertFrom-Json).log
    }
    $targets = @(Get-Content $Log -Raw | ConvertFrom-Json)
}
if (-not $targets) { Write-Host 'Nothing to restore.'; return }

# Stock launcher first, so a working home exists before anything else changes.
$targets = @($targets | Sort-Object { if ($_ -eq 'com.google.android.tvlauncher') { 0 } else { 1 } })

foreach ($pkg in $targets) {
    $out = (Invoke-TvShell $Serial "pm enable --user 0 $pkg") -join ' '
    if ($out -notmatch 'enabled') {
        $out = (Invoke-TvShell $Serial "cmd package install-existing --user 0 $pkg") -join ' '
    }
    Write-Host "  $pkg -> $out"
}

$stillDisabled = Get-PackageSet $Serial '-d' | Where-Object { $targets -contains $_ }
if ($stillDisabled) { Write-Warning "Still disabled: $($stillDisabled -join ', ')" }
else { Write-Host 'All requested packages are enabled again.' -ForegroundColor Green }
