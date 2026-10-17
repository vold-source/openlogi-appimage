# OpenLogi AppImage

Unofficial AppImage builds of [OpenLogi](https://github.com/AprilNEA/OpenLogi), the open-source Logitech Options+ alternative.

The binaries are taken **unchanged** from each official OpenLogi release (`.deb`) and wrapped into an AppImage. Nothing is recompiled or patched. A GitHub Action checks for new OpenLogi releases daily and publishes a matching AppImage here.

Made for immutable distros (Bazzite, Bluefin, Silverblue, …) where layering an `.rpm` isn't ideal. x86_64 only.

## Install

1. Download the latest `OpenLogi-*-x86_64.AppImage` from [Releases](../../releases/latest).
2. Install it with **[AppManager](https://github.com/kem-a/AppManager)** (recommended): double-click the AppImage and drag it to install. AppManager moves it to `~/Applications/OpenLogi`, adds it to your app menu and installs new versions automatically from the update info embedded in the AppImage. [Gear Lever](https://github.com/mijorus/gearlever) works too (it uses `~/AppImages/`).
3. Run the one-time setup in a terminal. With AppManager:

   ```sh
   ~/Applications/OpenLogi setup
   ```

   With Gear Lever or a plain download, use the path of the AppImage file instead (`ls ~/AppImages` shows Gear Lever's).

   This does two things:
   - copies OpenLogi's device rules to `/etc/udev/rules.d/70-openlogi.rules`, so it can talk to your receiver and mouse (it asks for your password once);
   - adds a small autostart service in `~/.local/share/systemd/user/`, so OpenLogi's background agent runs every time you log in.

   Neither one layers packages or touches the read-only system image.

4. Open OpenLogi from your app menu.

Close Solaar (and turn off its autostart), so the two don't fight over the receiver.

If you **move or rename** the AppImage, run `setup` again so the autostart points to the new location. Updates through AppManager or Gear Lever keep the same path, so updating needs nothing.

## Commands

| Command | What it does |
|---|---|
| `~/Applications/OpenLogi` | open the OpenLogi window |
| `~/Applications/OpenLogi setup` | one-time setup (device rules + agent autostart) |
| `~/Applications/OpenLogi remove` | undo the setup |
| `~/Applications/OpenLogi agent` | run the background agent by hand |
| `~/Applications/OpenLogi cli …` | OpenLogi's command-line tool, e.g. `cli list` |

## Notes

- The window needs `libxkbcommon`, `libxkbcommon-x11` and `libxcb`, which every normal desktop already has.
- After an update, the agent keeps running the old version until you log out and back in (or run `systemctl --user restart openlogi-agent`).
- Bugs in OpenLogi itself belong [upstream](https://github.com/AprilNEA/OpenLogi/issues). Packaging problems belong here.

## Building locally

```sh
./build.sh v0.8.14   # → out/OpenLogi-0.8.14-x86_64.AppImage
```

Needs `curl` and `dpkg-deb`.

The packaging scripts in this repo are MIT licensed (see LICENSE). OpenLogi itself is MIT / Apache-2.0, and its licence files are included in the AppImage.

If your AppImage manager offers a sandbox for apps, leave it off for OpenLogi: it needs direct access to your devices.
