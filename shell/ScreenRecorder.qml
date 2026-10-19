import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Recorder popup content. Runs bin/record (gpu-screen-recorder); the taskbar button reads running/paused.
ColumnLayout {
    id: recorder

    width: 220
    spacing: 12

    property bool running: false
    property bool paused: false
    property real elapsed: 0

    function setRunning(r) {
        if (r !== recorder.running) {
            recorder.running = r;
            recorder.paused = false;
            recorder.elapsed = 0;
        }
    }

    // bin/record keeps the PID of its own recording here (any other gpu-screen-recorder doesn't count).
    FileView {
        id: pidFile
        path: Config.stateDir + "/recorder.pid"
        watchChanges: true
        printErrors: false      // no file while nothing is recording
        onFileChanged: reload()
        onLoaded: recorder.setRunning(text().trim() !== "")
        onLoadFailed: recorder.setRunning(false)
    }
    // A file in a missing folder isn't watched: make the folder, then load again.
    Process {
        running: true
        command: ["mkdir", "-p", Config.stateDir]
        onExited: pidFile.reload()
    }
    // While recording: the elapsed time, and a liveness check (`record --status` removes a stale file).
    Timer {
        interval: 1000
        running: recorder.running
        repeat: true
        onTriggered: {
            statusProc.running = true;
            if (!recorder.paused)
                recorder.elapsed += 1;
        }
    }
    Process {
        id: statusProc
        command: [Quickshell.shellPath("bin/record"), "--status"]
        onExited: code => {
            if (code !== 0)
                recorder.setRunning(false);
        }
    }
    Process {
        id: recordCmd
        onExited: pidFile.reload()
    }
    function run(args) {
        recordCmd.command = [Quickshell.shellPath("bin/record"), ...args];
        recordCmd.running = true;
    }

    StyledText {
        text: recorder.paused ? "Paused" : recorder.running ? "Recording..." : "Screen recorder"
        color: Theme.m3onSurfaceVariant
        font.pixelSize: Theme.fontSize.small
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !recorder.running
        spacing: 8

        Repeater {
            model: [
                { icon: "fullscreen", label: "Fullscreen", args: [] },
                { icon: "select_to_speak", label: "+ Sound", args: ["-s"] }
            ]

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 56
                radius: 6
                color: modeArea.containsMouse ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: parent.parent.modelData.icon; color: Theme.m3onSurfaceVariant }
                    StyledText { Layout.alignment: Qt.AlignHCenter; text: parent.parent.modelData.label; color: Theme.m3onSurfaceVariant; font.pixelSize: Theme.fontSize.small }
                }

                MouseArea {
                    id: modeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: recorder.run(parent.modelData.args)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: recorder.running
        spacing: 12

        Rectangle {
            implicitWidth: recText.implicitWidth + 20
            implicitHeight: recText.implicitHeight + 10
            radius: 6
            color: recorder.paused ? Theme.yellow : Theme.m3error
            StyledText {
                id: recText
                anchors.centerIn: parent
                text: recorder.paused ? "PAUSED" : "REC"
                color: "white"
                font.pixelSize: Theme.fontSize.small
                font.bold: true
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: {
                const h = Math.floor(recorder.elapsed / 3600);
                const m = Math.floor((recorder.elapsed % 3600) / 60);
                const s = Math.floor(recorder.elapsed % 60).toString().padStart(2, "0");
                return (h > 0 ? h + ":" + m.toString().padStart(2, "0") : m) + ":" + s;
            }
            color: Theme.m3onSurface
        }

        IconButton {
            icon: recorder.paused ? "play_arrow" : "pause"
            tonal: true
            // gpu-screen-recorder toggles on each SIGUSR2 and reports nothing, so the pause state is kept here.
            onClicked: {
                recorder.paused = !recorder.paused;
                recorder.run(["-p"]);
            }
        }
        IconButton {
            icon: "stop"
            checked: true
            onClicked: recorder.run([])
        }
    }
}
