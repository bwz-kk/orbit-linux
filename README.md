# Orbit

Meta Quest monitor for the Omarchy bar (omarchy-shell). A bar icon shows the headset battery; clicking it opens a small card with:

- headset battery, charging state, temperature, power source, worn/standby state
- left and right controller battery and status
- connection (USB or Wi-Fi) and last sync time
- connect / disconnect notifications

Everything is read over ADB from the headset. Colors follow the active Omarchy theme.

## Requirements

1. `sudo pacman -S android-tools`
2. Developer Mode on the headset (Meta Horizon phone app → Devices → Developer Mode; needs a Meta developer account).
3. Plug the headset in over USB and accept **Allow USB debugging** (tick "Always allow from this computer").

USB permissions work out of the box on Omarchy (systemd `uaccess` covers ADB interfaces).

## Install

```sh
omarchy plugin add https://github.com/bwz-kk/orbit-linux.git --enable
```

## Wireless

While the headset is on USB, open the card and press **Set up Wi-Fi** (or run `bin/orbit-status wifi`). The address is saved to `~/.config/orbit-linux/wifi`, and Orbit reconnects to it automatically when the headset is not attached. Wireless ADB stops after the headset reboots; plug it in and press **Set up Wi-Fi** again.

## How it works

`bin/orbit-status` makes one `adb shell` call per poll and prints a single JSON line:

| Data | Source |
|------|--------|
| Headset battery, charging, temperature, plug | `dumpsys battery` |
| Controllers | `rstest info --json`, falling back to `dumpsys OVRRemoteService` |
| Worn / standby | `dumpsys vrpowermanager` |
| Model, serial, OS | `getprop` |

Polling is every 60 s while the card is closed (30 s with no headset, where only `adb devices` runs) and every 5 s while it is open. No extra daemon besides the adb server.

These `dumpsys` outputs are not documented by Meta and may change with Horizon OS updates.

## Development

```sh
test/run.sh                                   # parser tests against captured dumps
ORBIT_RAW=test/fixtures/remote.txt bin/orbit-status | jq
rsync -a --delete --exclude .git --exclude test ./ ~/.config/omarchy/plugins/bwzkk.orbit/   # hot-reloads the shell
```

Don't symlink the repo into `~/.config/omarchy/plugins/`: Quickshell caches files from symlinked plugin dirs and stops picking up edits.

Not affiliated with Meta. "Meta Quest" is a trademark of Meta Platforms, Inc.
