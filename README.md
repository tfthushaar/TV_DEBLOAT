# TV_DEBLOAT

A small, reversible PowerShell toolkit I wrote to make my **Sanyo smart TV** feel faster. It swaps the stock Android TV launcher for [Projectivy Launcher](https://play.google.com/store/apps/details?id=com.spocky.projengmenu), turns off background services I don't use, and shortens the UI animations. It all runs over network ADB from a PC. Nothing is flashed or rooted, and everything can be undone.

My TV has only **1.5 GB of RAM**, which is why this matters: the stock launcher alone was holding about 75 MB, and a few Google services added another 130 MB or so.

## My TV

| | |
|---|---|
| Model | Sanyo ATV R1 (manufacturer string `SCBC`) |
| Android | 9 (API 28) |
| SoC | Realtek rtd284o, 32-bit ARM |
| RAM | 1.5 GB total, about 680 MB available before I changed anything |

If your TV is different, **don't copy my package list blindly.** See [Using this on another TV](#using-this-on-another-tv).

## What I changed

All changes use `pm disable-user --user 0`, so the apps stay on disk and come back with one command.

| Package | What it is | RAM held |
|---|---|---|
| `com.google.android.tvlauncher` | Stock Android TV home screen (replaced by Projectivy) | ~75 MB |
| `com.google.android.backdrop` | Ambient-mode screensaver | ~52 MB |
| `com.google.android.katniss` | Google Assistant / voice search | ~50 MB |
| `com.google.android.tvrecommendations` | Recommendation rows for the stock home | ~17 MB |
| `com.google.android.marvin.talkback` | TalkBack screen reader | ~15 MB |

That is about 209 MB of resident memory in total. Projectivy uses some of it back, so the real saving is smaller.

I also set the window, transition and animator animation scales to **0.5x**.

Things I deliberately left alone: Play services and the Play Store, Netflix, Prime Video and YouTube (the apps I use), Chromecast receiver (`mediashell`, so casting still works), the TV's OTA updaters (`com.apps.ota`, `com.apps.authota`), and the on-screen keyboard. Anything I couldn't identify, such as the `com.apps.*` vendor packages, I left untouched.

## Results

Measured with `scripts/Measure-Tv.ps1`:

| | Before | After |
|---|---|---|
| Available memory | 684 MB | 764 MB |
| Average time to show HOME | 623 ms | 192 ms |
| TV uptime when measured | 43 min | 2.7 min (fresh boot) |

Read the memory row with care: the "after" figure was taken right after a reboot, and a freshly booted TV always has more free memory. It is **not** a like-for-like comparison. The HOME launch time is the number I trust more, since both readings were taken with the launcher already running. I'll update this table once I have a reading at a matching uptime.

Some debloat guides promise a 300-500 MB gain. That isn't possible on this TV: everything I disabled held about 209 MB in total, and the launcher that replaced it needs memory too.

## How it works

| Script | What it does |
|---|---|
| `scripts/Connect-Tv.ps1` | Connects over ADB and remembers the TV in `.tvconfig.json` (git-ignored). |
| `scripts/Save-Snapshot.ps1` | Read-only capture of packages, home handlers, settings and memory into `snapshots/`. |
| `scripts/Invoke-Debloat.ps1` | Disables the packages in `packages.json`. **Dry run unless you pass `-Apply`.** |
| `scripts/Restore-Tv.ps1` | Re-enables what was disabled, from the change log or with `-All`. |
| `scripts/Set-Animations.ps1` | Sets the three animation scales; `-Reset` restores the originals. |
| `scripts/Measure-Tv.ps1` | Records free memory and HOME launch time. |
| `packages.json` | The packages, their tier, size and what disabling each one does. |

### Safety

- **Disable, don't uninstall.** Nothing is removed from the TV. A factory reset also clears the disabled state.
- **The launcher gate.** Disabling the stock launcher with no replacement can leave a TV without a usable home screen. Anything marked `requiresLauncher` is blocked unless the replacement is installed, registered as a HOME handler, and a fallback home activity still exists. Right after the stock launcher is disabled, the script confirms HOME now resolves to the replacement and re-enables the stock one if it doesn't.
- **Dry run by default**, and a snapshot is saved before any change.
- Only packages that exist on the TV and are currently enabled are touched.
- Every change is written to a log (`snapshots/<time>-pre-debloat/changes.json`) that `Restore-Tv.ps1` reads.

### Tiers

- **Tier 1** is applied by default: large memory users with a clear, low-risk effect.
- **Tier 2** needs `-IncludeOptional`: dormant or situational packages (old Google apps, streaming apps I don't use, the setup wizard). Read each `effect` first.
- **`neverTouch`** lists what the scripts should leave alone.

## Usage

**On the TV:** enable Developer options (Settings > Device Preferences > About, press *Build* seven times), then switch on **USB debugging**. My TV has no separate "Network debugging" toggle; USB debugging alone was enough for ADB to listen on port 5555. Install Projectivy Launcher from the Play Store.

**On the PC:** install adb (`winget install Google.PlatformTools`; open a new terminal afterwards so it's on PATH). The PC and TV must be on the same network.

```powershell
.\scripts\Connect-Tv.ps1 -Address 192.168.1.50      # tap "Always allow" on the TV
.\scripts\Measure-Tv.ps1 -Label before
.\scripts\Invoke-Debloat.ps1                         # dry run: read the table first
.\scripts\Invoke-Debloat.ps1 -Apply
.\scripts\Set-Animations.ps1 -Scale 0.5
# reboot the TV, wait a while, then
.\scripts\Measure-Tv.ps1 -Label after
```

If PowerShell blocks the scripts, prefix with `powershell -ExecutionPolicy Bypass -File`.

**To undo everything:**

```powershell
.\scripts\Restore-Tv.ps1
.\scripts\Set-Animations.ps1 -Reset
```

### Troubleshooting (things that bit me)

- **`adb connect` times out.** Check the TV's IP really is in your PC's subnet. My TV's static IP was in a different subnet from my PC, so it was unreachable. `arp -a` is a quick check: a live device shows up there.
- **The TV isn't at the address you set.** After I changed my TV's static IP it didn't end up there. I found it by checking which device on the network had port 5555 open. Reserve an address in your router instead of relying on the TV's static IP setting.
- **`unauthorized`.** The "Allow USB debugging?" prompt is on the TV screen; tick *Always allow*.
- **`adb` not found right after installing it.** Existing terminals don't see the new PATH. The scripts also look in the winget install folder.

## Using this on another TV

1. Connect and run `Save-Snapshot.ps1`. Open `snapshots/*/packages-all.txt` and `meminfo-dumpsys.txt`.
2. Pick packages by what actually uses memory on your TV, not by name. Package names differ between brands: for example the Google TV launcher and the `com.tcl.*` packages that many guides mention don't exist on my TV at all.
3. Edit `packages.json`. Put anything uncertain in tier 2.
4. Run `Invoke-Debloat.ps1` without `-Apply` and read the table before anything is changed.

## Things I chose not to do

- **"Background process limit: at most 2".** Many guides recommend it. On 1.5 GB of RAM it makes apps reload from scratch every time you switch away, so I skipped it.
- **Claiming telemetry is off.** Disabling a handful of packages doesn't achieve that, so I don't claim it.

## Repository layout

```
packages.json        what to disable, with tier, size and effect
scripts/             the PowerShell scripts (Common.ps1 holds shared helpers)
snapshots/           local device captures and change logs (git-ignored)
.tvconfig.json       your TV's address (git-ignored)
```

## Disclaimer

Disabling system packages can break features, and I've only tested this on one TV. Everything here is reversible, but use it at your own risk.
