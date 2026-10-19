pragma Singleton
// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): color palette (a Caelestia-format scheme) and design tokens.
// Material 3 palette from $XDG_STATE_HOME/cts1/scheme.json (bin/scheme-gen, from the wallpaper), live. Missing colors
// keep the fixed Caelestia-generated values below. Tokens are Caelestia's (Config/tokens.hpp).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // scheme.json: "colours" = name -> "rrggbb" (no #), plus its mode.
    property var scheme: ({})
    property bool light: false
    function colour(name, fallback) {
        const c = root.scheme[name];
        return typeof c === "string" && /^[0-9a-fA-F]{6}$/.test(c) ? "#" + c : fallback;
    }

    readonly property color m3surface: colour("surface", "#0d0e12")
    readonly property color m3surfaceContainer: colour("surfaceContainer", "#18191f")
    readonly property color m3surfaceContainerHigh: colour("surfaceContainerHigh", "#1d1f26")
    readonly property color m3surfaceContainerHighest: colour("surfaceContainerHighest", "#23262e")
    readonly property color m3onSurface: colour("onSurface", "#e4e5f0")
    readonly property color m3onSurfaceVariant: colour("onSurfaceVariant", "#a9aab5")
    readonly property color m3outline: colour("outline", "#73757f")
    readonly property color m3outlineVariant: colour("outlineVariant", "#454850")
    readonly property color m3primary: colour("primary", "#b9c6ee")
    readonly property color m3onPrimary: colour("onPrimary", "#323f61")
    readonly property color m3primaryContainer: colour("primaryContainer", "#455274")
    readonly property color m3onPrimaryContainer: colour("onPrimaryContainer", "#dbe2ff")
    readonly property color m3secondary: colour("secondary", "#c0c6dc")
    readonly property color m3onSecondary: colour("onSecondary", "#3a4052")
    readonly property color m3secondaryContainer: colour("secondaryContainer", "#353b4d")
    readonly property color m3onSecondaryContainer: colour("onSecondaryContainer", "#b9bfd5")
    readonly property color m3tertiary: colour("tertiary", "#f1deff")
    readonly property color m3error: colour("error", "#fa746f")
    readonly property color m3onError: colour("onError", "#490006")
    // Catppuccin Mocha colors nudged up to 15 degrees towards the wallpaper's hue (scheme-gen), for things that need
    // a recognizable color (brightness slider, muted volume, errors).
    readonly property color yellow: colour("harmonizedYellow", "#f9e2af")
    readonly property color red: colour("harmonizedRed", "#f38ba8")

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/cts1"

    FileView {
        id: schemeFile
        path: root.stateDir + "/scheme.json"
        watchChanges: true
        printErrors: false      // no file until a wallpaper is first picked: the fixed colors are used
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.scheme = s.colours ?? {};
                root.light = s.mode === "light";
            } catch (e) {
                console.warn("theme: can't parse", path, "-", e, "- keeping the current colors");
            }
        }
    }
    // A file in a missing folder isn't watched: make the folder, then load again.
    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: schemeFile.reload()
    }

    // Light-mode switch: save the mode and remake the scheme; Theme.light follows when scheme.json is rewritten.
    function toggleMode() {
        const mode = root.light ? "dark" : "light";
        Config.appearance.mode = mode;
        schemeProc.command = ["sh", "-c", 'w=$(cat "$1" 2>/dev/null) && [ -f "$w" ] && exec "$2" --mode "$3" "$w"',
                              "sh", root.stateDir + "/wallpaper",
                              Quickshell.shellPath("bin/scheme-gen"), mode];
        schemeProc.running = true;
    }
    Process {
        id: schemeProc
    }

    readonly property var rounding: ({ extraSmall: 4, small: 8, medium: 12, large: 16, largeIncreased: 20,
                                       extraLarge: 28, extraLargeIncreased: 32, extraExtraLarge: 48, full: 9999 })
    readonly property var spacing: ({ extraSmall: 4, small: 8, medium: 12, large: 16, largeIncreased: 20,
                                      extraLarge: 28, extraLargeIncreased: 32, extraExtraLarge: 48 })
    readonly property var padding: spacing

    // Font sizes in logical pixels (Caelestia's sizes are points; these match at 96 dpi).
    readonly property var fontSize: ({ small: 11, smaller: 12, normal: 13, larger: 15, large: 18, extraLarge: 28 })
    readonly property string sans: "Rubik"
    readonly property string icons: "Material Symbols Rounded"

    readonly property var dash: ({ userWidth: 400, weatherWidth: 275, dateTimeWidth: 110, mediaWidth: 224,
                                   mediaProgressSweep: 180, mediaProgressThickness: 6,
                                   resourceProgressThickness: 6, logoSize: 30, uptimeSize: 30,
                                   tabIndicatorSpacing: 5 })
}
