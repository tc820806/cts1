pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Levels for the media visualizer: cava (assets/cava.conf) runs only while one is on screen and a player plays.
Singleton {
    id: root

    property int users: 0
    // 0-1, low to high; empty while cava isn't running.
    property var values: []

    Process {
        running: root.users > 0 && Players.active !== null && Players.active.isPlaying
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
        stdout: SplitParser {
            onRead: data => root.values = data.split(";").filter(s => s !== "").map(s => parseInt(s) / 100)
        }
        onRunningChanged: if (!running) root.values = []
    }
}
