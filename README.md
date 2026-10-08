# TV_DEBLOAT

A small, reversible toolkit for speeding up a low-RAM Android TV over network ADB: swap the stock launcher for [Projectivy](https://play.google.com/store/apps/details?id=com.spocky.projengmenu), disable background services you don't use, and trim animations. Nothing is flashed or rooted, and a factory reset puts everything back.

Built and tested on a **Sanyo ATV R1** (Android 9, Realtek rtd284o, 1.5 GB RAM). Other Android TVs will have different packages, so read the dry-run output before applying anything.

## How it works

Every script is PowerShell (Windows PowerShell 5.1 or `pwsh`) and talks to the TV through `adb`.

| Script | What it does |
|---|---|
| `scripts/Connect-Tv.ps1` | Connects to the TV and remembers it in `.tvconfig.json` (git-ignored). |
| `scripts/Save-Snapshot.ps1` | Read-only capture of packages, home handlers, settings and memory into `snapshots/`. |
| `scripts/Invoke-Debloat.ps1` | Disables the packages in `packages.json`. **Dry run unless `-Apply`.** |
| `scripts/Restore-Tv.ps1` | Re-enables what was disabled (from the change log, or `-All`). |
| `scripts/Set-Animations.ps1` | Sets the three animation scales, or `-Reset` to the original values. |
| `scripts/Measure-Tv.ps1` | Records free memory and HOME launch time, for real before/after numbers. |

## Quick start

1. **On the TV:** enable Developer options (Settings > Device Preferences > About > press *Build* 7 times), then turn on **USB debugging** (and *Network debugging* / *Wireless debugging* if your TV has it). Install **Projectivy Launcher** from the Play Store.
2. **On the PC:** install adb (`winget install Google.PlatformTools`). The TV and PC must be on the same subnet. If connecting times out, check the TV's IP actually matches your network.
3. Run from this folder (add `-ExecutionPolicy Bypass` if scripts are blocked):

```powershell
.\scripts\Connect-Tv.ps1 -Address 192.168.1.50      # accept "Always allow" on the TV
.\scripts\Measure-Tv.ps1 -Label before
.\scripts\Invoke-Debloat.ps1                         # dry run, read the table
.\scripts\Invoke-Debloat.ps1 -Apply                  # apply tier 1
.\scripts\Set-Animations.ps1 -Scale 0.5
# reboot the TV, then:
.\scripts\Measure-Tv.ps1 -Label after
```

To undo: `.\scripts\Restore-Tv.ps1` (and `.\scripts\Set-Animations.ps1 -Reset`).

## Safety

- **Disable, don't uninstall.** `pm disable-user --user 0` leaves the app on disk and is undone with `pm enable`. Settings live in `/data`, so a factory reset also clears them.
- **Launcher gate.** Packages marked `requiresLauncher` are blocked unless the replacement launcher is installed, registered as a HOME handler, and a fallback home activity still exists. After the stock launcher is disabled, the script confirms HOME resolves to the replacement and re-enables the stock one if it doesn't.
- **Dry run by default**, and a snapshot is saved before any change.
- Only packages that exist and are currently enabled are touched.

## Package tiers (`packages.json`)

- **Tier 1**: applied by default. Large resident-memory users with a clear, low-risk effect.
- **Tier 2**: applied with `-IncludeOptional`. Dormant or situational packages; check each `effect` first.
- **`neverTouch`**: core system, Play services, the updaters, and apps the owner uses.

The package list comes from this TV's own `pm list packages`, with the memory figure from `dumpsys meminfo`. Run `Save-Snapshot.ps1` on your TV and compare before adding anything.

## Differences from the original brief

- The brief's `com.google.android.apps.tv.launcherx` (Google TV) and `com.tcl.*` packages don't exist on this TV, so they aren't in the list.
- Packages are *disabled* rather than uninstalled, so rollback is one command and covers every change (the brief's rollback re-enabled a single package).
- "At most 2 background processes" is not applied: on 1.5 GB of RAM it forces apps to reload from scratch.
- Gains are measured with `Measure-Tv.ps1` rather than promised. "Telemetry completely disabled" is not claimed; disabling a few packages doesn't achieve that.

## Disclaimer

Disabling system packages can break features. Everything here is reversible, but use it at your own risk and keep the TV's original behaviour in mind.
