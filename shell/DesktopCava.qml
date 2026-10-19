pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The desktop visualizer's own cava: 60 bars at 60 fps (assets/cava-desktop.conf), runs while it shows.
Singleton {
    id: root

    // = cava-desktop.conf's `bars`
    readonly property int barCount: 60
    property var values: Array(barCount).fill(0)
    property bool active: false

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellPath("assets/cava-desktop.conf")]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(";");
                const next = Array(root.barCount);
                let changed = false;
                for (let i = 0; i < root.barCount; i++) {
                    const value = Number(parts[i]);
                    next[i] = isNaN(value) ? 0 : Math.max(0, Math.min(1, value / 1000));
                    if (next[i] !== root.values[i])
                        changed = true;
                }
                // Silence repeats the same frame: skip it so the visualizer can idle.
                if (changed)
                    root.values = next;
            }
        }
        onExited: if (root.active) restartTimer.restart()
    }

    onActiveChanged: {
        cava.running = active;
        if (!active) {
            restartTimer.stop();
            values = Array(barCount).fill(0);
        }
    }

    // cava died while wanted (e.g. PipeWire restarted): try again.
    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: if (root.active) cava.running = true
    }
}
