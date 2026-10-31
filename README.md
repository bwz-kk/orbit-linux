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

> **Security warning:** Set up Wi-Fi runs `adb tcpip 5555`, which leaves ADB listening on port 5555 of the headset's network until it reboots. Any device on the same network can attempt to connect. A new computer still has to be approved with the "Allow USB debugging" prompt inside the headset, so:
>
> - Only use wireless mode on networks you trust (your home network, not public or shared Wi-Fi).
> - Never accept a debugging prompt in the headset that you did not trigger yourself.
> - To close the port, reboot the headset, or run `adb usb` while it is connected.

## How it works

`bin/orbit-status` makes one `adb shell` call per poll and prints a single JSON line:

| Data | Source |
|------|--------|
| Headset battery, charging, temperature, plug | `dumpsys battery` |
| Controllers | `rstest info --json`, falling back to `dumpsys OVRRemoteService` |
| Worn / standby | `dumpsys vrpowermanager` |
| Model, serial, OS | `getprop` |

The last good reading is cached in `~/.cache/orbit-linux/last.json`. While the headset sleeps or is away, the card keeps showing it, dimmed, with "last seen N min ago".

Orbit checks the headset every 60 s (30 s when it is not connected), but background checks never reconnect over Wi-Fi: once the headset sleeps, Orbit leaves it alone. It reconnects only when you press the refresh button in the card header (or middle-click the bar icon), connect the Quest from the Bluetooth menu, or plug it in over USB. If the headset is fully asleep, the refresh button wakes it with a Bluetooth connect attempt (`orbit-status wake`); its Wi-Fi takes about 1 minute to come back, and it goes back to sleep on its own afterwards. This only works while the headset is in standby (on the charger or recently used): off the charger and fully asleep, it stops advertising over Bluetooth and cannot be reached from the PC. Press its power button or put it on the charger. `omarchy-shell bwzkk.orbit wake` does the same from a keybinding. Opening the card does not connect either. No extra daemon besides the adb server.

These `dumpsys` outputs are not documented by Meta and may change with Horizon OS updates.

## Development

```sh
test/run.sh                                   # parser tests against captured dumps
ORBIT_RAW=test/fixtures/remote.txt bin/orbit-status | jq
rsync -a --delete --exclude .git --exclude test ./ ~/.config/omarchy/plugins/bwzkk.orbit/   # hot-reloads the shell
```

Don't symlink the repo into `~/.config/omarchy/plugins/`: Quickshell caches files from symlinked plugin dirs and stops picking up edits.

MIT licensed, see [LICENSE](LICENSE). Not affiliated with Meta. "Meta Quest" is a trademark of Meta Platforms, Inc.
