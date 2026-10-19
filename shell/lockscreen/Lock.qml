pragma ComponentBehavior: Bound
// The lock screen: a real session lock (ext-session-lock-v1) in the shell's process, started by `ipc call lock lock`
// (bin/lock). If the shell dies while locked, sway stays locked. A reload while locked kills the shell (Quickshell
// 0.3.2 makes a second lock surface: protocol error), so shell.qml stops watching files and holds its reload.
// `ipc call lock preview` shows it in an ordinary window instead, for design work.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: root

    // While locked sway draws only the lock, so the lock draws the volume/brightness indicator itself (Osd.qml).
    property bool osdShown: false
    property string osdKind: "volume"
    property real osdLevel: 0
    property bool osdMuted: false

    // Set here: Quickshell 0.3.2 never signals WlSessionLock.locked going false on unlock.
    property bool locked: false
    property bool previewShown: false

    function lock(): void {
        locked = true;
    }

    WlSessionLock {
        id: sessionLock

        locked: root.locked

        WlSessionLockSurface {
            color: "black"

            LockView {
                anchors.fill: parent
                auth: lockAuth
                onUnlocked: root.locked = false
            }
            Osd {
                shown: root.osdShown
                kind: root.osdKind
                rawLevel: root.osdLevel
                rawMuted: root.osdMuted
            }
        }
    }

    Auth {
        id: lockAuth
    }

    Connections {
        target: sessionLock

        function onSecureChanged() {
            if (sessionLock.secure)
                lockAuth.reset();
        }
    }

    // A monitor back from suspend (NVIDIA DP) gets a new lock window, and sway 1.12 can leave the keyboard focused on
    // nothing. Focusing the output makes sway re-apply the lock's keyboard focus (seat.c, seat_set_focus); after a moment,
    // so the new window exists.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.locked)
                refocusTimer.restart();
        }
    }

    Timer {
        id: refocusTimer
        interval: 1500
        onTriggered: {
            const screen = Quickshell.screens.find(s => s.name !== "");
            if (!root.locked || !screen)
                return;
            console.info("Screens changed while locked: focusing output", screen.name);
            Quickshell.execDetached(["swaymsg", "focus output " + screen.name]);
        }
    }

    LazyLoader {
        active: root.previewShown

        FloatingWindow {
            title: "lock-preview"
            implicitWidth: 1600
            implicitHeight: 900
            color: "black"
            onClosed: root.previewShown = false

            Auth {
                id: previewAuth
            }

            LockView {
                anchors.fill: parent
                auth: previewAuth
                onUnlocked: root.previewShown = false
            }
            Osd {
                shown: root.osdShown
                kind: root.osdKind
                rawLevel: root.osdLevel
                rawMuted: root.osdMuted
            }
        }
    }
}
