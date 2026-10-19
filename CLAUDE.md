# CTS1: notes for Claude Code

Read README.md and CREDITS.md first. Keep machine-specific lines out of `sway-config/config` (they go in the user's
files listed in the README). Ask before switching a machine to the login screen.

- Restart the shell only with `shell/bin/shell-restart` (never `qs kill`), and never while the screen is locked.
- Quickshell hot-reloads on every file change: stage multi-file edits elsewhere, copy them in at once, then check
  `qs log -p <clone>/shell`. New QML files need a full restart.
- Test in a headless sway before the real session.
- Scripted text edits can split comments or add blank lines: diff every changed line afterward.
- Credit headers ("Partly based on ...", "Changed for CTS1: ...") stay: the GPL needs them.
