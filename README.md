# OpenLogi AppImage

[![Latest release](https://img.shields.io/github/v/release/vold-source/openlogi-appimage?label=AppImage)](https://github.com/vold-source/openlogi-appimage/releases/latest)
[![Build](https://github.com/vold-source/openlogi-appimage/actions/workflows/build.yml/badge.svg)](https://github.com/vold-source/openlogi-appimage/actions/workflows/build.yml)

> **Personal project.** I made this for my own use and share it as is. I don't offer support or take feature requests, but you're welcome to use it or fork it.

Unofficial AppImage of [OpenLogi](https://github.com/AprilNEA/OpenLogi), the open-source alternative to Logitech Options+.

- **Unchanged:** the program files come straight from each official OpenLogi release. Nothing is recompiled or patched.
- **Always current:** a daily check publishes every new OpenLogi version here, and your AppImage manager picks it up.
- **Made for immutable distros** such as Bazzite, Bluefin and Silverblue, where layering packages isn't ideal.

x86_64 only.

> **Temporary by design.** This repo only exists because OpenLogi doesn't publish an AppImage itself. If it starts doing so, this repo will be archived with a pointer to the official builds, so switch to those when that happens.

## Install

1. Download the latest `OpenLogi-*-x86_64.AppImage` from [Releases](https://github.com/vold-source/openlogi-appimage/releases/latest).
2. Install it with **[AppManager](https://github.com/kem-a/AppManager)** (recommended): double-click the AppImage and drag it to install. It ends up at `~/Applications/OpenLogi` and appears in your app menu.
3. Run the one-time setup in a terminal:

   ```sh
   ~/Applications/OpenLogi setup
   ```

4. Open OpenLogi from your app menu.

[Gear Lever](https://github.com/mijorus/gearlever) works as well; use the path it shows (usually in `~/AppImages/`) instead of `~/Applications/OpenLogi`.

### What setup does

- Copies OpenLogi's device rules to `/etc/udev/rules.d/70-openlogi.rules`, so OpenLogi can talk to your receiver and read and remap mouse buttons. It asks for your password once.
- Adds an autostart service in `~/.local/share/systemd/user/`, so OpenLogi's background agent runs whenever you log in.

Neither one layers packages or changes the read-only system image. `~/Applications/OpenLogi remove` undoes both.

Setup and remove never replace or delete a file they didn't create. If a different file is already at one of those places, setup stops without changing anything and tells you which file it is, and remove leaves it alone.

Run `setup` again if you move or rename the AppImage. Updates keep the same path, so they need nothing.

## Updates

AppManager (or Gear Lever) checks this repository and installs new versions for you. The background agent switches to the new version the next time you log in.

OpenLogi's own **Settings → Updates** page doesn't apply to the AppImage:

- **Check for Updates** fails with *"no release asset matched the current platform"*, because OpenLogi doesn't publish a self-updating Linux build. Ignore it; your AppImage manager handles updates.
- **Installation source: Not identified** is expected. OpenLogi only recognises its own deb, rpm, Arch and Nix packages.
- **Update source** links to the upstream OpenLogi release that's inside this AppImage, which is correct.

Versions match OpenLogi's (e.g. `0.8.14`). A fourth number (e.g. `0.8.14.1`) means a packaging fix with the same OpenLogi inside.

## Commands

| Command | What it does |
|---|---|
| `~/Applications/OpenLogi` | Open the OpenLogi window |
| `~/Applications/OpenLogi setup` | One-time setup (device rules + agent autostart) |
| `~/Applications/OpenLogi remove` | Undo the setup |
| `~/Applications/OpenLogi agent` | Run the background agent by hand |
| `~/Applications/OpenLogi cli …` | OpenLogi's command-line tool, e.g. `cli list` |

## Troubleshooting

- **Is the agent running?** `systemctl --user status openlogi-agent` should say *active (running)*.
- **Sandbox:** if your AppImage manager offers to sandbox apps, leave it off for OpenLogi, which needs direct access to your devices.
- **Missing libraries:** the window needs `libxkbcommon`, `libxkbcommon-x11` and `libxcb`, which every normal desktop already has.
- Problems with OpenLogi itself belong [upstream](https://github.com/AprilNEA/OpenLogi/issues), and packaging problems belong [here](https://github.com/vold-source/openlogi-appimage/issues).

## How it's built

| File | What it does | Origin |
|---|---|---|
| [`build.sh`](build.sh) | Downloads OpenLogi's official `.deb`, unpacks it, adds the two scripts below, and packs it all into an AppImage with [appimagetool](https://github.com/AppImage/appimagetool). | Written for this repo |
| [`appimage/AppRun`](appimage/AppRun) | The AppImage's front door: decides whether to open the window, run the agent, run the command-line tool, or run setup/remove. | Written for this repo |
| [`appimage/openlogi-appimage-setup`](appimage/openlogi-appimage-setup) | The one-time `setup` and `remove`. | Written for this repo; the rules file and `udevadm` commands are OpenLogi's own, and the service mirrors OpenLogi's |
| [`.github/workflows/build.yml`](.github/workflows/build.yml) | Runs daily on GitHub, builds new OpenLogi versions and publishes them as Releases. | Written for this repo |

Every file is commented in plain language, so you can read it top to bottom.

To build locally (needs `curl` and `dpkg-deb`):

```sh
./build.sh v0.8.14   # → out/OpenLogi-0.8.14-x86_64.AppImage
```

## License 

The packaging in this repository is [MIT](LICENSE). OpenLogi itself is MIT / Apache-2.0, and its licence files are included in every AppImage.
