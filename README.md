# CTS1

A Quickshell shell for sway: left taskbar with popups, notification server, lock screen, and a greetd login screen.
Written by Claude Code, based on Caelestia's design and partly its code ([CREDITS.md](CREDITS.md)). GPL-3.0-only
([LICENSE](LICENSE)); the login screen also has GPL-3.0-or-later code (aroa's theme), Apache-2.0 shape data
(`greeter/Shapes.LICENSE`) and an OFL-1.1 font (`greeter/assets/google-sans-flex/OFL.txt`). Keys: `sway-config/config`.

## Layout

| Path | What |
| --- | --- |
| `shell/` | The shell (`shell.qml` = taskbar + popups), lock screen in `lockscreen/`, scripts in `bin/`, color templates in `templates/` (from Caelestia's CLI, see CREDITS.md), dark-mode files in `darkmode/`, cava settings in `assets/` |
| `greeter/` | Login screen; `greeter/install.sh` (root) copies it to `/usr/local/share/cts1-greeter` |
| `sway-config/` | Sway config, session wrapper `bin/sway`, swayidle, session entry, Kitty and fastfetch |
| `package/` | `install.sh` and per-distro package lists (`packages.sh`, also what Fedora/Debian don't package) |

## Files outside the repo

| File | What |
| --- | --- |
| `~/.config/sway/config.d/*` | The user's own sway lines (outputs, inputs, apps), included last |
| `~/.config/cts1/session.env` | `export` lines read before sway starts (input method, GPU, renderer) |
| `~/.config/sway/resume.d/*` | Executables run after every wake |
| `~/.config/cts1/config.json`, `layout.json` | Settings and taskbar layout (settings window, Super+I); `$CTS1_CONFIG_DIR` replaces the folder for a test copy |
| `~/.local/state/cts1/` | `scheme.json` (colors), `wallpaper`, `sway.conf` (focused border), `timers.json`, `recorder.pid`, `logs/` (sway, newest 5) |
| `~/Documents/notes/*.txt` | Notes window, one file per note |
| Written by `scheme-gen` | `~/.config/fuzzel/fuzzel.ini`, `~/.config/gtk-3.0/gtk.css` + `thunar.css`, `~/.config/gtk-4.0/gtk.css`, `~/.config/qtengine/caelestia.colors` (always dark; own fuzzel settings go in `shell/templates/fuzzel.ini`) |

## Install

Clone to a path without spaces (the session runs from the clone), then as the user, never root:
`package/install.sh --check` (read-only), `package/install.sh` (or named steps; `--list`). Steps check first and skip
when done. Exit 2 = the user must act (no AUR helper, unpackaged items), then run again. It never updates the system,
never makes backups, never switches the display manager; it asks once before replacing Kitty, fastfetch, GTK or Qt
settings. Arch: build `paru` (not `paru-bin`) first. Debian: apt asks for the default display manager (greetd is one):
keep the current one. Fedora/Debian: rerun `install.sh session` after a sway update brings sway's entry back (Arch
has `NoExtract`). Fonts must be system-wide: the greeter runs as greetd's user. Then log out and pick "Sway".
Update: `git pull`, `package/install.sh`, Super+Shift+R.

## Login screen (manual switch)

greetd's user: `greeter` (Arch), `greetd` (Fedora), `_greetd` (Debian). `install.sh` does 1-3.
1. `sudo greeter/install.sh` (again after every greeter change).
2. `sudo install -d -o GREETER -g GREETER -m 750 /var/lib/greetd && sudo usermod -d /var/lib/greetd GREETER`
3. `sudo systemctl enable --now cts1-greeter-sync@USER.path` (colors + wallpaper; assumes `/home/USER`).
4. `/etc/greetd/config.toml`: `[terminal] vt = N` (the getty greetd replaces: `systemctl cat greetd | grep Conflicts`;
   Arch 1, Debian 7) and `[default_session] command = "/usr/local/share/cts1-greeter/start.sh"`, `user = "GREETER"`;
   disable the old display manager, enable greetd, reboot.
5. Keyring (optional): `cp /etc/pam.d/greetd /etc/pam.d/greetd-greeter`, then in `/etc/pam.d/greetd` add
   `-auth optional pam_gnome_keyring.so` after `auth include` and `-session optional pam_gnome_keyring.so auto_start`
   after `session include`.

Limits: no visible user list (Left/Right), PAM messages not shown (only the shake), log: `journalctl -t cts1-greeter`.

## Gotchas

- Restart only with Super+Shift+R / `shell/bin/shell-restart` (never `qs kill`), never while locked.
- Crash while locked: sway stays locked. From a TTY: `WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u) ~/cts1/shell/bin/lock`.
- Logs: sway `~/.local/state/cts1/logs/`, shell `qs log -p <clone>/shell`, session start `journalctl -t cts1-session`.
- Apps come up light: restart them after a color change; else check the `darkmode` step and log in again.
- A tray icon waiting for a logged-in user (VPN) missing: `bin/sway` writes the login record with sessreg (utmp group, next login); `who` should list the user.
- Privacy: only weather goes online, and only when switched on (see `Weather.qml`'s header).
- Limits: sway only; one monitor for the taskbar and popups; no Bluetooth pairing agent (pair once with `bluetoothctl`);
  brightness = backlight or the first DDC monitor; GPU stats NVIDIA/AMD only; popups need ~1000 px width.
