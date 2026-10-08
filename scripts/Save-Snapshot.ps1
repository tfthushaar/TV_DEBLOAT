<#
.SYNOPSIS  Read-only capture of the TV's packages, home handlers, settings and memory into snapshots\.
#>
[CmdletBinding()]
param([string]$Serial, [string]$Label = 'snapshot')

. "$PSScriptRoot\Common.ps1"

$dir = Save-TvSnapshot -Serial (Get-TvSerial $Serial) -Label $Label
Write-Host "Snapshot saved: $dir" -ForegroundColor Green
