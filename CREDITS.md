# Credits

## Caelestia

CTS1 is based on the design of [Caelestia](https://github.com/caelestia-dots/shell) (GPL-3.0-only; Copyright (C) soramanew and the Caelestia contributors), and parts of its code come from Caelestia. Code or design taken from it, file by file (each file also says so at the top, except the unchanged copies and `qtengine.json`, which can't hold a comment):

| CTS1 file | Based on |
| --- | --- |
| `shell/Theme.qml` | The color palette (a Caelestia-format scheme; the fixed fallback is a Caelestia-generated one) and design tokens |
| `shell/shell.qml` | Bluetooth popup (`modules/bar/popouts/Bluetooth.qml`), Bluetooth status and device icons |
| `shell/PopupHost.qml` | The one-window popup design (`modules/drawers/ContentWindow.qml`) |
| `shell/CalendarCard.qml` | The month grid (`modules/dashboard/dash/Calendar.qml`) |
| `shell/WeatherTab.qml` | The weather layout (`modules/dashboard/WeatherTab.qml`) |
| `shell/MediaPlayer.qml` | Cover + progress-ring layout (`modules/dashboard/dash/Media.qml`) |
| `shell/Players.qml` | The cover-art fallback (`services/Players.qml`) |
| `shell/DesktopVisualizer.qml` | The desktop visualizer (`modules/background/Visualiser.qml`) |
| `shell/DesktopClock.qml` | The desktop clock (`modules/background/DesktopClock.qml`) |
| `shell/Notifs.qml` | The notification server setup (`services/Notifs.qml`) |
| `shell/lockscreen/Auth.qml` | PAM handling (`modules/lock/Pam.qml`) |
| `shell/lockscreen/pam.d/passwd` | The PAM stack (`assets/pam.d/passwd`), unchanged |
| `shell/lockscreen/LockView.qml`, `shell/lockscreen/Clock.qml` | The lock screen's layout and clock style |
| `shell/lockscreen/WeatherCard.qml` | The weather layout (`modules/dashboard/WeatherTab.qml`), through `shell/WeatherTab.qml` |
| `shell/lockscreen/MediaCompact.qml` | Cover + progress-ring layout (`modules/dashboard/dash/Media.qml`), through `shell/MediaPlayer.qml` |
| `greeter/components/CalendarCard.qml` | The month grid (`modules/dashboard/dash/Calendar.qml`), through `shell/CalendarCard.qml` |
| `shell/bin/record` | The `caelestia record` command from [Caelestia's CLI](https://github.com/caelestia-dots/cli) (GPL-3.0-only) |
| `shell/bin/scheme-gen` | The dynamic color scheme from Caelestia's CLI (`utils/material/`, `utils/colourfulness.py`, `utils/wallpaper.py`) |
| `shell/templates/` | The fuzzel, GTK, Thunar and Qt color templates from Caelestia's CLI (`data/templates/`); fuzzel and Qt unchanged, GTK and Thunar changed (`sway.conf` is CTS1's own) |
| `shell/darkmode/qtengine.json` | The qtengine template from Caelestia's CLI (`data/templates/qtengine.json`), with a fixed dark icon theme and the Fusion style |
| `shell/assets/cava-desktop.conf` | The visualizer's cava settings (`plugin/src/Caelestia/Services/cavaprovider.cpp`) |

## Login screen

The login screen (`greeter/`) is a port of aroa's Caelestia SDDM theme ("Caelestia SDDM Full") from ladybug-me's [caelestia-kde](https://github.com/ladybug-me/caelestia-kde) (`src/sddm`, GPL-3.0-or-later), itself modeled on Caelestia, changed by Claude to run under greetd with Quickshell. caelestia-kde is Copyright (C) 2026 ladybug-me and the Caelestia contributors. Each file taken from it says so at the top, with what was changed.

- **Shape morphs** (`greeter/Shapes.qml`): generated once with [rounded-polygon-qmljs](https://github.com/end-4/rounded-polygon-qmljs) by end-4 (Apache-2.0), a port of Knugel's [rounded-polygon-ts](https://github.com/Knugel/rounded-polygon-ts) and Android's shape library.
- **Font:** Google Sans Flex by Google (SIL Open Font License 1.1).

Their licenses are next to those files.

## Wallpaper picker

The wallpaper picker (`shell/WallpaperPicker.qml`) follows the design of the wallpaper picker in [JAQC-shell](https://github.com/MystiaFin/JAQC-shell) by MystiaFin: a band across the middle of the screen over the blurred wallpaper, with the pictures as a carousel. JAQC-shell has no license, so no code was taken from it; the file was written by Claude for CTS1.

## Installer

`package/install.sh` follows the idea in ladybug-me's caelestia-kde of one script that installs every dependency and applies everything; the script itself was written by Claude for CTS1.

## Everything else

Written by Claude for CTS1: the popup host's implementation, the network popup, the taskbar layout and settings window, the Performance popup, the notification UI, the lock screen's password and power parts, weather and hardware detection, the hardware monitor on the lock and login screens, the login screen's greetd login, session list, color sync and install scripts, the audio bars around the media cover, the desktop layer and its calendar, the timer and notes windows, and the helper scripts.
