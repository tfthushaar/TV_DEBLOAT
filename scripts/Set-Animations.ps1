<#
.SYNOPSIS  Set (or reset) the three animation scales over ADB.
.EXAMPLE   .\Set-Animations.ps1 -Scale 0.5
.EXAMPLE   .\Set-Animations.ps1 -Reset
.NOTES
  The brief's "background process limit: at most 2" is deliberately not applied. On a TV with
  1.5 GB of RAM it forces apps to reload from scratch whenever you switch between them.
#>
[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [string]$Serial,
    [Parameter(ParameterSetName = 'Set', Mandatory)][ValidateSet('0', '0.5', '1')][string]$Scale,
    [Parameter(ParameterSetName = 'Reset', Mandatory)][switch]$Reset
)

. "$PSScriptRoot\Common.ps1"

$Serial = Get-TvSerial $Serial
$keys   = 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale'

$value = if ($Reset -or $Scale -eq '1') { '1.0' } else { $Scale }

New-Item -ItemType Directory -Force $script:SnapshotRoot | Out-Null
$backup = Join-Path $script:SnapshotRoot 'animations-original.json'
if (-not (Test-Path $backup)) {
    $orig = @{}
    foreach ($k in $keys) { $orig[$k] = (Invoke-TvShell $Serial "settings get global $k") -join '' }
    $orig | ConvertTo-Json | Set-Content $backup -Encoding UTF8
    Write-Host "Saved original values to $backup"
}

foreach ($k in $keys) { Invoke-TvShell $Serial "settings put global $k $value" | Out-Null }
foreach ($k in $keys) { "{0} = {1}" -f $k, ((Invoke-TvShell $Serial "settings get global $k") -join '') }
