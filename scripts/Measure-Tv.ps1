<#
.SYNOPSIS
  Record memory and HOME-launch time so before/after claims are measured, not guessed.
.EXAMPLE
  .\Measure-Tv.ps1 -Label before
  .\Measure-Tv.ps1 -Label after
#>
[CmdletBinding()]
param([string]$Serial, [string]$Label = 'measure', [int]$Runs = 5)

. "$PSScriptRoot\Common.ps1"

$Serial = Get-TvSerial $Serial

function Get-MemKB([string[]]$Lines, [string]$Key) {
    $m = $Lines | Select-String "^${Key}:\s+(\d+)" | Select-Object -First 1
    if ($m) { [int]$m.Matches[0].Groups[1].Value }
}

$mem = Invoke-TvShell $Serial 'cat /proc/meminfo'
$uptimeMin = [math]::Round([double](((Invoke-TvShell $Serial 'cat /proc/uptime') -join '').Split(' ')[0]) / 60, 1)

# Cold-ish HOME launch: go to a different screen first so HOME has real work to do.
$times = @()
for ($i = 0; $i -lt $Runs; $i++) {
    Invoke-TvShell $Serial 'am start -W -a android.settings.SETTINGS' | Out-Null
    Start-Sleep -Seconds 2
    $out = Invoke-TvShell $Serial 'am start -W -a android.intent.action.MAIN -c android.intent.category.HOME'
    $t = $out | Select-String 'TotalTime:\s*(\d+)' | Select-Object -First 1
    if ($t) { $times += [int]$t.Matches[0].Groups[1].Value }
    Start-Sleep -Seconds 2
}

$result = [ordered]@{
    label           = $Label
    takenAt         = (Get-Date).ToString('s')
    uptimeMinutes   = $uptimeMin
    memTotalKB      = Get-MemKB $mem 'MemTotal'
    memFreeKB       = Get-MemKB $mem 'MemFree'
    memAvailableKB  = Get-MemKB $mem 'MemAvailable'
    activeHome      = Get-ActiveHome $Serial
    homeLaunchMs    = $times
    homeLaunchAvgMs = if ($times) { [math]::Round(($times | Measure-Object -Average).Average, 0) } else { $null }
}

New-Item -ItemType Directory -Force $script:SnapshotRoot | Out-Null
$file = Join-Path $script:SnapshotRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + "-measure-$Label.json")
$result | ConvertTo-Json | Set-Content $file -Encoding UTF8
[pscustomobject]$result | Format-List | Out-Host
Write-Host "Saved: $file"
Write-Host 'Compare like with like: measure right after a reboot, with the same apps open.'
