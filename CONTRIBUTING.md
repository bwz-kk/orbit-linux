# Contributing to Orbit

Thanks for helping. Orbit is small on purpose, so the bar for new code is "does it need to exist?" Bug reports with real headset output are the most valuable contribution.

## Reporting a bug

Open an issue with:

- Headset model and Horizon OS build (`adb shell getprop ro.vros.build.version`).
- Omarchy version (`omarchy version`).
- Output of `bin/orbit-status | jq`.
- If values are wrong or missing, the raw dump the script reads (see [Capturing headset output](#capturing-headset-output)). **Redact serials first.**

## Development setup

```sh
omarchy pkg add android-tools jq
git clone https://github.com/bwz-kk/orbit-linux.git && cd orbit-linux
rsync -a --delete --exclude .git --exclude test ./ ~/.config/omarchy/plugins/bwzkk.orbit/
omarchy plugin enable bwzkk.orbit
```

- Copy the repo into the plugins folder as shown. Don't symlink it: Quickshell caches files from symlinked plugin dirs and ignores your edits.
- Changes to `bin/orbit-status` apply on the next poll.
- Changes to `.qml` files need `omarchy-restart-shell`, because the shell caches loaded components.
- Shell logs: `journalctl --user -f | grep -i orbit`.
- `omarchy-shell bwzkk.orbit open|close|toggle|wake` drives the card from a terminal.

## Project layout

| Path | What it does |
|------|--------------|
| `bin/orbit-status` | Talks to the headset over adb and prints one JSON line. All parsing is a single jq program. |
| `BarWidget.qml` | Bar icon and battery %. |
| `OrbitPanel.qml` | The card, polling, notifications, Bluetooth wake. |
| `test/run.sh` | The test suite. |
| `test/fixtures/` | Real (redacted) and hand-made adb dumps. |
| `test/fake-adb/adb` | adb stub for timeout, offline and reconnect cases. |

## Tests

```sh
test/run.sh
```

Every parser or `orbit-status` change needs a passing run. Adding support for a new headset or Horizon OS version means adding its captured dump as a fixture with an assertion in `test/run.sh`. The tests use a temporary cache and config dir and never touch a real headset.

## Capturing headset output

Run the exact script Orbit uses and save the result:

```sh
eval "$(sed -n "/^REMOTE_SCRIPT='/,/^'$/p" bin/orbit-status)"
adb shell "$REMOTE_SCRIPT" > test/fixtures/<model>-<build>.txt
```

Before committing a fixture, replace the following with fake values:

- the headset serial
- controller serials and IDs
- your Wi-Fi IP

Check with `grep -nE 'serial|"id"|Paired|src ' test/fixtures/<file>`.

## Guidelines

- **Stay light.** No new daemons and no faster polling. Nothing should wake or keep the headset awake unless the user asks (refresh button, Bluetooth menu, USB).
- **Theme colors only.** Use `Commons.Color` and `Style` tokens and never hardcode colors, so Orbit follows every Omarchy theme.
- **Few dependencies.** bash, jq, adb and the omarchy-shell QML modules. Ask in an issue before adding anything else.
- **Only documented or plain-adb data sources.** Orbit reads `dumpsys`, `getprop` and `rstest` over adb. Contributions that implement Meta's private companion Bluetooth protocol, or other reverse-engineered or authenticated Meta APIs, won't be merged. Meta's terms prohibit reverse engineering.
- **Naming.** Don't use Meta logos. Refer to the device as "Meta Quest" only to describe compatibility.

## Pull requests

- Keep each PR to one change, with a short description of what and why.
- Run `test/run.sh` and test on a real headset if you touched `bin/orbit-status` or the QML.
- For UI changes, include a screenshot of the card.
- Commit messages: a short imperative subject line, plus a body explaining why when it isn't obvious.

By contributing you agree your work is released under the [MIT License](LICENSE).
