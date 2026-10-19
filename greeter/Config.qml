pragma Singleton
// Replaces SDDM's `config` (theme.conf): same keys and string values ("true", "0.9", "#rrggbb"), so the theme's code
// works as `Config.x`. Read from $CTS1_GREETER_CONFIG, else /var/lib/cts1-greeter/config.json (sync.sh). Read-only.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string path: Quickshell.env("CTS1_GREETER_CONFIG") || "/var/lib/cts1-greeter/config.json"

    readonly property alias os: adapter.os
    readonly property alias ap: adapter.ap
    readonly property alias enableWelcomeMessage: adapter.enableWelcomeMessage
    readonly property alias welcomeBgBlurAmount: adapter.welcomeBgBlurAmount
    readonly property alias welcomeColorOpacity: adapter.welcomeColorOpacity
    readonly property alias mainCardBlurAmount: adapter.mainCardBlurAmount
    readonly property alias mainCardColorOpacity: adapter.mainCardColorOpacity
    readonly property alias mainCardComponentsOpacity: adapter.mainCardComponentsOpacity
    readonly property alias welcomeBgBlur: adapter.welcomeBgBlur
    readonly property alias mainCardBgBlur: adapter.mainCardBgBlur
    readonly property alias sessionPicker: adapter.sessionPicker
    // Absolute path; empty = the fallback color.
    readonly property alias wallpaper: adapter.wallpaper
    readonly property url wallpaperUrl: adapter.wallpaper !== "" ? "file://" + adapter.wallpaper : ""

    readonly property alias background: adapter.background
    readonly property alias mainCard: adapter.mainCard
    readonly property alias subComponents: adapter.subComponents
    readonly property alias text: adapter.text
    readonly property alias primary: adapter.primary
    readonly property alias textOnPrimary: adapter.textOnPrimary
    readonly property alias secondary: adapter.secondary
    readonly property alias textOnSecondary: adapter.textOnSecondary
    readonly property alias tertiary: adapter.tertiary
    readonly property alias inverseOnSurface: adapter.inverseOnSurface
    readonly property alias surfaceContainerHigh: adapter.surfaceContainerHigh
    readonly property alias outline: adapter.outline
    readonly property alias error: adapter.error
    // For PerfColumn.
    readonly property alias m3primary: adapter.m3primary
    readonly property alias secondaryContainer: adapter.secondaryContainer
    readonly property alias textOnSurfaceVariant: adapter.textOnSurfaceVariant
    readonly property alias surfaceContainerHighest: adapter.surfaceContainerHighest

    FileView {
        path: root.path
        // Read before the first frame, so the defaults never flash.
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("greeter config: can't read", path, "- using the defaults");
        }

        JsonAdapter {
            id: adapter

            property string os: ""      // empty = os-release NAME
            property string ap: "true"      // 12-hour clock
            property string enableWelcomeMessage: "false"
            property string welcomeBgBlurAmount: "0.7"
            property string welcomeColorOpacity: "0.7"
            property string mainCardBlurAmount: "0.9"
            property string mainCardColorOpacity: "0.9"
            property string mainCardComponentsOpacity: "0.9"
            property string welcomeBgBlur: "true"
            property string mainCardBgBlur: "true"
            property string sessionPicker: "true"
            property string wallpaper: ""

            // Caelestia's dark scheme (as in CTS1's Theme.qml).
            property string background: "#0d0e12"
            property string mainCard: "#0d0e12"
            property string subComponents: "#18191f"
            property string text: "#e4e5f0"
            property string primary: "#69769a"
            property string textOnPrimary: "#323f61"
            property string secondary: "#c0c6dc"
            property string textOnSecondary: "#3a4052"
            property string tertiary: "#f1deff"
            property string inverseOnSurface: "#545559"
            property string surfaceContainerHigh: "#1d1f26"
            property string outline: "#73757f"
            property string error: "#fa746f"
            property string m3primary: "#b9c6ee"
            property string secondaryContainer: "#353b4d"
            property string textOnSurfaceVariant: "#a9aab5"
            property string surfaceContainerHighest: "#23262e"
        }
    }
}
