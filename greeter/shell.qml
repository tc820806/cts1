// CTS1 greeter: aroa's Caelestia SDDM theme (Main.qml and the rest) run by Quickshell as a greetd greeter, inside
// cage; without greetd (no GREETD_SOCK) an ordinary window for design work. The canvas is always 1200 lines tall
// (SDDM's look at QT_SCALE_FACTOR 1.8 on 2160 lines), so it looks the same at any resolution.
import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        id: win

        title: "cts1-greeter"
        color: "black"
        implicitWidth: 1920
        implicitHeight: 1080

        Main {
            readonly property real factor: win.height / 1200

            transformOrigin: Item.TopLeft
            scale: factor
            width: win.width / factor
            height: win.height / factor
        }
    }
}
