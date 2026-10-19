pragma Singleton
// Settings: $XDG_CONFIG_HOME/cts1/config.json ($CTS1_CONFIG_DIR replaces the folder, for a test copy); layout.json
// is in the same folder. Missing -> defaults written out; hand edits are picked up live. Every default is "off".
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("CTS1_CONFIG_DIR")
        || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cts1"
    readonly property alias weather: adapter.weather
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias appearance: adapter.appearance
    readonly property string wallpaperFolder: {
        const f = adapter.wallpaper.folder.trim();
        const home = Quickshell.env("HOME");
        return f === "" ? home + "/Pictures/Wallpapers" : f.startsWith("~") ? home + f.substring(1) : f;
    }
    readonly property string notesFolder: Quickshell.env("HOME") + "/Documents/notes"
    // State, not settings (e.g. the current wallpaper).
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/cts1"
    // False until the file was read (or found missing): anything acting on settings (weather) waits for it.
    property bool ready: false

    FileView {
        id: file
        path: root.dir + "/config.json"
        watchChanges: true
        printErrors: false      // a missing file on first start is normal; real read errors are reported below
        onFileChanged: reload()
        // A change made here wins even mid-load (writing cancels the load, so loaded/loadFailed never arrive).
        onAdapterUpdated: {
            root.ready = true;
            writeAdapter();
        }
        onLoaded: root.ready = true
        onLoadFailed: err => {
            root.ready = true;
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
            else
                console.warn("config: can't read", path, "- using the defaults");
        }

        JsonAdapter {
            id: adapter
            property JsonObject weather: JsonObject {
                // "off" (no requests), "city", or "auto" (location from the IP via ipinfo.io); see Weather.qml.
                property string mode: "off"
                property string city: ""
                property bool celsius: true
            }
            property JsonObject appearance: JsonObject {
                // "dark" / "light" (the settings switch) or "auto" (light for a bright wallpaper); read by bin/scheme-gen.
                property string mode: "auto"
            }
            property JsonObject wallpaper: JsonObject {
                // Empty = ~/Pictures/Wallpapers.
                property string folder: ""
            }
        }
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        // Writing a new file doesn't watch it; reload() does.
        onExited: {
            file.writeAdapter();
            file.reload();
        }
    }
}
