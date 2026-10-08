<#
.SYNOPSIS  Connect to the TV over network ADB and remember it for the other scripts.
.EXAMPLE   .\Connect-Tv.ps1 -Address 192.168.1.50
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Address)

. "$PSScriptRoot\Common.ps1"

$serial = if ($Address -match ':\d+$') { $Address } else { "${Address}:5555" }

& $script:Adb connect $serial | Out-Host
Start-Sleep -Seconds 2

$state = (& $script:Adb -s $serial get-state) -join ''
switch ($state.Trim()) {
    'device' { }
    'unauthorized' { throw "The TV has not authorized this PC. Accept 'Allow USB debugging' on the TV (tick 'Always allow'), then re-run." }
    default { throw "Could not reach $serial (state: '$state'). Check the TV is awake, on the same network, and USB/Network debugging is on." }
}

$model = (Invoke-TvShell $serial 'getprop ro.product.model') -join ''
$sdk   = (Invoke-TvShell $serial 'getprop ro.build.version.sdk') -join ''
@{ serial = $serial } | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8

Write-Host "Connected: $model (API $sdk) at $serial" -ForegroundColor Green
