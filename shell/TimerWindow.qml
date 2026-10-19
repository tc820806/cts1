import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Timer window (Super+T): three countdowns (TimerSlot.qml). They keep running while closed and across a shell
// restart: timers.json stores the end time, tagged with the session; a new login gets names and times back, reset.
Scope {
    id: win

    property bool open: false
    readonly property var slots: [slot0, slot1, slot2]
    // For the taskbar icon: a rung timer, and the running/paused one closest to running out (null = none).
    readonly property bool ringing: slots.some(s => s.phase === "done")
    readonly property var soonest: {
        let best = null;
        for (const s of slots)
            if ((s.phase === "running" || s.phase === "paused") && (best === null || s.timeLeft < best.timeLeft))
                best = s;
        return best;
    }

    IpcHandler {
        target: "timer"
        function toggle(): void { win.open = !win.open; }
        function open(): void { win.open = true; }
        function close(): void { win.open = false; }
    }

    TimerSlot { id: slot0; index: 0 }
    TimerSlot { id: slot1; index: 1 }
    TimerSlot { id: slot2; index: 2 }
    Connections {
        target: slot0
        function onEdited() { win.save(); }
        function onOpenRequested() { win.open = true; }
    }
    Connections {
        target: slot1
        function onEdited() { win.save(); }
        function onOpenRequested() { win.open = true; }
    }
    Connections {
        target: slot2
        function onEdited() { win.save(); }
        function onOpenRequested() { win.open = true; }
    }

    Timer {
        interval: 250
        repeat: true
        running: win.slots.some(s => s.phase === "running")
        onTriggered: {
            const t = Date.now();
            for (const s of win.slots) {
                s.now = t;
                s.check(t);
            }
        }
    }

    readonly property string session: Quickshell.env("XDG_SESSION_ID") + "|" + Quickshell.env("SWAYSOCK")
    property bool restored: false

    FileView {
        id: store
        path: Config.stateDir + "/timers.json"
        printErrors: false      // no file until a timer is first used
        onLoaded: win.restore(text())
        onLoadFailed: win.restore("")
    }
    function restore(t: string): void {
        let saved = null;
        try {
            saved = JSON.parse(t);
        } catch (e) {}
        const list = saved && Array.isArray(saved.timers) ? saved.timers : [];
        const sameSession = saved && saved.session === win.session;
        const now = Date.now();
        for (let i = 0; i < slots.length && i < list.length; i++) {
            const s = slots[i], e = list[i] || {};
            s.label = typeof e.label === "string" ? e.label : "";
            s.duration = Number(e.duration) > 0 ? Number(e.duration) : 0;
            if (sameSession && (e.phase === "running" || e.phase === "paused" || e.phase === "done")) {
                s.endsAt = Number(e.endsAt) || 0;
                s.remaining = Number(e.remaining) || 0;
                s.phase = e.phase;
                s.now = now;
            }
        }
        restored = true;
        // A timer that ran out while the shell was restarting rings now.
        for (const s of slots)
            s.check(now);
    }
    function save(): void {
        if (!restored)
            return;
        store.setText(JSON.stringify({
            session: win.session,
            timers: slots.map(s => ({ label: s.label, duration: s.duration, phase: s.phase, endsAt: s.endsAt, remaining: s.remaining }))
        }, null, 2) + "\n");
    }

    PanelWindow {
        visible: win.open || panel.opacity > 0.01
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "cts1-timer"
        WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: win.open = false
        }
        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.open = false
        }
        // Opening gives the keys to the window, not to a field focused last time.
        Connections {
            target: win
            function onOpenChanged() {
                if (win.open)
                    keys.forceActiveFocus();
            }
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: 460
            height: content.implicitHeight + Theme.padding.large * 2
            radius: 6
            color: Theme.m3surface
            border.color: Theme.m3outlineVariant
            border.width: 1
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.95
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent    // clicks on the panel itself must not close it
                onClicked: keys.forceActiveFocus()
            }

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.padding.large
                spacing: Theme.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon {
                        text: "timer"
                        font.pixelSize: 22
                        color: Theme.m3primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Timers"
                        color: Theme.m3onSurface
                        font.pixelSize: Theme.fontSize.large
                        font.bold: true
                    }
                }
                StyledText {
                    text: "Name (optional), minutes and seconds, then start."
                    color: Theme.m3outline
                    font.pixelSize: Theme.fontSize.small
                }

                Repeater {
                    model: win.slots

                    Rectangle {
                        id: row
                        required property var modelData
                        readonly property var slot: modelData
                        readonly property bool editable: slot.phase === "idle"
                        readonly property bool done: slot.phase === "done"
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 56
                        radius: 6
                        color: done ? Theme.m3primaryContainer : Theme.m3surfaceContainer

                        function startFromFields() {
                            if (row.editable)
                                row.slot.duration = ((parseInt(minInput.text) || 0) * 60 + (parseInt(secInput.text) || 0)) * 1000;
                            row.slot.start();
                            keys.forceActiveFocus();
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 6
                                color: Theme.m3surfaceContainerHigh
                                border.width: nameInput.activeFocus ? 1 : 0
                                border.color: Theme.m3primary

                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: row.done ? Theme.m3onPrimaryContainer : Theme.m3onSurface
                                    selectionColor: Theme.m3primaryContainer
                                    font.family: Theme.sans
                                    font.pixelSize: Theme.fontSize.normal
                                    clip: true
                                    maximumLength: 40
                                    activeFocusOnTab: true
                                    text: row.slot.label
                                    onTextEdited: {
                                        row.slot.label = text;
                                        win.save();
                                    }
                                    Keys.onReturnPressed: row.startFromFields()
                                    Keys.onEnterPressed: row.startFromFields()
                                    Keys.onEscapePressed: win.open = false

                                    StyledText {
                                        visible: nameInput.text === "" && !nameInput.activeFocus
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Timer " + (row.slot.index + 1)
                                        color: Theme.m3outline
                                    }
                                }
                            }

                            Row {
                                visible: row.editable
                                spacing: 3
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    width: 44
                                    height: 34
                                    radius: 6
                                    color: Theme.m3surfaceContainerHigh
                                    border.width: minInput.activeFocus ? 1 : 0
                                    border.color: Theme.m3primary

                                    TextInput {
                                        id: minInput
                                        anchors.fill: parent
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.m3onSurface
                                        selectionColor: Theme.m3primaryContainer
                                        font.family: Theme.sans
                                        font.pixelSize: Theme.fontSize.larger
                                        validator: IntValidator { bottom: 0; top: 999 }
                                        text: String(Math.floor(row.slot.duration / 60000))
                                        selectByMouse: true
                                        activeFocusOnTab: true
                                        onActiveFocusChanged: if (activeFocus) selectAll()
                                        Keys.onReturnPressed: row.startFromFields()
                                        Keys.onEnterPressed: row.startFromFields()
                                        Keys.onEscapePressed: win.open = false
                                    }
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ":"
                                    color: Theme.m3outline
                                    font.pixelSize: Theme.fontSize.larger
                                }
                                Rectangle {
                                    width: 44
                                    height: 34
                                    radius: 6
                                    color: Theme.m3surfaceContainerHigh
                                    border.width: secInput.activeFocus ? 1 : 0
                                    border.color: Theme.m3primary

                                    TextInput {
                                        id: secInput
                                        anchors.fill: parent
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.m3onSurface
                                        selectionColor: Theme.m3primaryContainer
                                        font.family: Theme.sans
                                        font.pixelSize: Theme.fontSize.larger
                                        validator: IntValidator { bottom: 0; top: 59 }
                                        text: {
                                            const s = Math.floor(row.slot.duration / 1000) % 60;
                                            return (s < 10 ? "0" : "") + s;
                                        }
                                        selectByMouse: true
                                        activeFocusOnTab: true
                                        onActiveFocusChanged: if (activeFocus) selectAll()
                                        Keys.onReturnPressed: row.startFromFields()
                                        Keys.onEnterPressed: row.startFromFields()
                                        Keys.onEscapePressed: win.open = false
                                    }
                                }
                            }

                            StyledText {
                                visible: !row.editable
                                Layout.preferredWidth: 44 * 2 + 3 * 2 + 6
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: row.slot.format(row.slot.timeLeft)
                                color: row.done ? Theme.m3onPrimaryContainer : row.slot.phase === "paused" ? Theme.m3outline : Theme.m3primary
                                font.pixelSize: Theme.fontSize.large
                                font.bold: true
                                font.features: { "tnum": 1 }    // digits of equal width, so the clock doesn't jiggle
                            }

                            IconButton {
                                visible: !row.done
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 34
                                implicitHeight: 34
                                iconSize: 20
                                tonal: true
                                icon: row.slot.phase === "running" ? "pause" : "play_arrow"
                                onClicked: row.slot.phase === "running" ? row.slot.pause() : row.startFromFields()
                            }
                            // Reset; on a rung timer it is the stop button (bells off, notification gone).
                            IconButton {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 34
                                implicitHeight: 34
                                iconSize: 20
                                checked: row.done
                                disabled: row.editable
                                icon: row.done ? "alarm_off" : "restart_alt"
                                onClicked: {
                                    row.slot.reset();
                                    keys.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
