# Shared helpers for the TV_DEBLOAT scripts. Dot-source this from the other scripts.
Set-StrictMode -Version 2

$script:RepoRoot     = Split-Path -Parent $PSScriptRoot
$script:ConfigPath   = Join-Path $script:RepoRoot '.tvconfig.json'
$script:SnapshotRoot = Join-Path $script:RepoRoot 'snapshots'
$script:HomeArgs     = '-a android.intent.action.MAIN -c android.intent.category.HOME'

function Get-AdbPath {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # A fresh winget install is not on PATH until the terminal is restarted.
    $pkgs = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $hit = Get-ChildItem $pkgs -Recurse -Filter adb.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    throw 'adb not found. Install it with: winget install Google.PlatformTools'
}
$script:Adb = Get-AdbPath

function Get-TvSerial {
    param([string]$Serial)
    if ($Serial) { return $Serial }
    if (Test-Path $script:ConfigPath) {
        $cfg = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        if ($cfg.serial) { return $cfg.serial }
    }
    throw 'No TV configured. Run scripts\Connect-Tv.ps1 -Address <ip> first, or pass -Serial.'
}

function Invoke-TvShell {
    param([Parameter(Mandatory)][string]$Serial, [Parameter(Mandatory)][string]$Command)
    @(& $script:Adb -s $Serial shell $Command | ForEach-Object { "$_".TrimEnd("`r") })
}

# Package names, optionally filtered by `pm list packages` flags (-d disabled, -3 third-party, ...).
function Get-PackageSet {
    param([Parameter(Mandatory)][string]$Serial, [string]$Flags = '')
    @(Invoke-TvShell $Serial "pm list packages $Flags") |
        ForEach-Object { $_ -replace '^package:', '' } | Where-Object { $_ }
}

# Component names (pkg/.Activity) that can currently act as the home screen.
function Get-HomeHandlers {
    param([Parameter(Mandatory)][string]$Serial)
    @(Invoke-TvShell $Serial "cmd package query-activities --brief $script:HomeArgs") |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[\w.]+/[\w.$]+$' }
}

# The component Android would launch right now when HOME is pressed.
function Get-ActiveHome {
    param([Parameter(Mandatory)][string]$Serial)
    @(Invoke-TvShell $Serial "cmd package resolve-activity --brief $script:HomeArgs") |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[\w.]+/[\w.$]+$' } |
        Select-Object -Last 1
}

function Write-TextFile {
    param([Parameter(Mandatory)][string]$Path, [AllowEmptyCollection()][string[]]$Lines)
    [IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
}

# Read-only capture of the TV's state. Returns the snapshot directory.
function Save-TvSnapshot {
    param([Parameter(Mandatory)][string]$Serial, [string]$Label = 'snapshot')
    $dir = Join-Path $script:SnapshotRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $Label)
    New-Item -ItemType Directory -Force $dir | Out-Null
    $captures = [ordered]@{
        'getprop.txt'             = 'getprop'
        'packages-all.txt'        = 'pm list packages -f -u'
        'packages-disabled.txt'   = 'pm list packages -d'
        'packages-thirdparty.txt' = 'pm list packages -3'
        'home-handlers.txt'       = "cmd package query-activities --brief $script:HomeArgs"
        'home-active.txt'         = "cmd package resolve-activity --brief $script:HomeArgs"
        'animation-settings.txt'  = 'for k in window_animation_scale transition_animation_scale animator_duration_scale; do echo $k=$(settings get global $k); done'
        'meminfo.txt'             = 'cat /proc/meminfo'
        'meminfo-dumpsys.txt'     = 'dumpsys meminfo'
    }
    foreach ($name in $captures.Keys) {
        Write-TextFile (Join-Path $dir $name) (Invoke-TvShell $Serial $captures[$name])
    }
    $dir
}
