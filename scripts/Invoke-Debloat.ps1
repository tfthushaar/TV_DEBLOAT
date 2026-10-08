<#
.SYNOPSIS
  Disable the packages listed in packages.json. Dry run unless -Apply is given.

.DESCRIPTION
  Only touches packages that exist on the TV and are currently enabled. Uses
  `pm disable-user --user 0`, which is fully reversible with Restore-Tv.ps1.
  Packages marked requiresLauncher are blocked unless the replacement launcher is
  installed, registered as a HOME handler, and a fallback home still exists.
  After the stock launcher is disabled the active HOME is re-checked, and the
  launcher is re-enabled immediately if the replacement did not take over.

.EXAMPLE
  .\Invoke-Debloat.ps1                      # dry run, tier 1
  .\Invoke-Debloat.ps1 -Apply               # apply tier 1
  .\Invoke-Debloat.ps1 -Apply -IncludeOptional
#>
[CmdletBinding()]
param([string]$Serial, [switch]$Apply, [switch]$IncludeOptional)

. "$PSScriptRoot\Common.ps1"

$Serial   = Get-TvSerial $Serial
$cfg      = Get-Content (Join-Path $script:RepoRoot 'packages.json') -Raw | ConvertFrom-Json
$launcher = $cfg.replacementLauncher.package
$stock    = 'com.google.android.tvlauncher'

$installed = Get-PackageSet $Serial ''
$disabled  = Get-PackageSet $Serial '-d'
$handlers  = Get-HomeHandlers $Serial

# --- launcher safety gate -------------------------------------------------
$gateProblem = $null
if ($installed -notcontains $launcher)                          { $gateProblem = "$launcher is not installed" }
elseif ($disabled -contains $launcher)                          { $gateProblem = "$launcher is disabled" }
elseif (-not ($handlers | Where-Object { $_ -like "$launcher/*" })) { $gateProblem = "$launcher is not registered as a HOME handler" }
elseif (-not ($handlers | Where-Object { $_ -notlike "$launcher/*" -and $_ -notlike "$stock/*" })) { $gateProblem = 'no fallback HOME activity exists' }

# --- build the plan -------------------------------------------------------
$maxTier = if ($IncludeOptional) { 2 } else { 1 }
$plan = foreach ($p in $cfg.packages | Where-Object { $_.tier -le $maxTier }) {
    $status = 'DISABLE'
    if     ($installed -notcontains $p.name)       { $status = 'skip: not on this TV' }
    elseif ($disabled  -contains $p.name)          { $status = 'skip: already disabled' }
    elseif ($p.requiresLauncher -and $gateProblem) { $status = "BLOCKED: $gateProblem" }
    [pscustomobject]@{ Package = $p.name; Status = $status; PssMB = if ($p.pssKB) { [math]::Round($p.pssKB / 1024, 1) } else { $null }; Effect = $p.effect }
}

$plan | Format-Table Package, Status, PssMB -AutoSize | Out-Host
$todo = @($plan | Where-Object { $_.Status -eq 'DISABLE' })
$mb   = ($todo | Measure-Object PssMB -Sum).Sum
Write-Host ("{0} package(s) to disable, about {1} MB of resident memory." -f $todo.Count, [math]::Round([double]$mb, 0))
if ($gateProblem) { Write-Host "Launcher gate: $gateProblem" -ForegroundColor Yellow }

if (-not $Apply) {
    Write-Host 'Dry run only. Nothing was changed. Re-run with -Apply to proceed.' -ForegroundColor Cyan
    return
}
if (-not $todo) { Write-Host 'Nothing to do.'; return }

# --- apply ----------------------------------------------------------------
$snap = Save-TvSnapshot -Serial $Serial -Label 'pre-debloat'
Write-Host "Pre-change snapshot: $snap"

$changes = @()
foreach ($item in $todo) {
    $out = (Invoke-TvShell $Serial "pm disable-user --user 0 $($item.Package)") -join ' '
    if ($out -notmatch 'disabled') { Write-Warning "$($item.Package): unexpected output '$out'"; continue }
    $changes += $item.Package
    Write-Host "  disabled $($item.Package)"
    # Persist after every step so a crash mid-run still leaves a usable restore log.
    $changes | ConvertTo-Json | Set-Content (Join-Path $snap 'changes.json') -Encoding UTF8

    if ($item.Package -eq $stock) {
        $activeHome = Get-ActiveHome $Serial
        if (-not $activeHome -or $activeHome -notlike "$launcher/*") {
            Write-Warning "Active HOME is '$activeHome', not $launcher. Re-enabling $stock and stopping."
            Invoke-TvShell $Serial "pm enable --user 0 $stock" | Out-Null
            throw 'Replacement launcher did not take over HOME; stock launcher restored.'
        }
        Write-Host "  HOME now resolves to $activeHome" -ForegroundColor Green
    }
}

# Verify against the device, not against our own bookkeeping.
$nowDisabled = Get-PackageSet $Serial '-d'
$missing = $changes | Where-Object { $nowDisabled -notcontains $_ }
if ($missing) { Write-Warning "Not reported as disabled: $($missing -join ', ')" }

@{ log = (Join-Path $snap 'changes.json') } | ConvertTo-Json | Set-Content (Join-Path $script:SnapshotRoot 'latest-changes.json') -Encoding UTF8
Write-Host "Done. Restore log: $(Join-Path $snap 'changes.json')" -ForegroundColor Green
Write-Host 'Reboot the TV, then run Measure-Tv.ps1 to compare against your baseline.'
