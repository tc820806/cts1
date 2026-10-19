import QtQuick
import Quickshell
import qs

// Suspend / log out / reboot / shut down under the password field, no password (the power button can end the session
// anyway). All but suspend need a second press within a few seconds. The field keeps the keyboard and hands every
// key to handleKey() first: Tab enters the row, Esc/Shift+Tab leave it, a typing key goes back and is typed.
Row {
    id: root

    property real ui: 1
    property int kbIndex: -1            // button selected with the keyboard; -1 = typing goes to the password field
    property int armed: -1              // button waiting for its confirming second press
    readonly property string armedName: armed >= 0 ? buttons[armed].name : ""

    readonly property var buttons: [
        { icon: "bedtime", colour: Theme.m3primary, name: "suspend", confirm: false, cmd: ["systemctl", "suspend"] },
        { icon: "logout", colour: Theme.m3primary, name: "log out", confirm: true, cmd: ["swaymsg", "exit"] },
        { icon: "restart_alt", colour: Theme.m3primary, name: "restart", confirm: true, cmd: ["systemctl", "reboot"] },
        { icon: "power_settings_new", colour: Theme.m3error, name: "shut down", confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    function press(i: int): void {
        if (buttons[i].confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        armed = -1;
        Quickshell.execDetached(buttons[i].cmd);
    }

    function leave(): void {
        kbIndex = -1;
        armed = -1;
    }

    // True when the key was used here (the field then ignores it).
    function handleKey(event: KeyEvent): bool {
        const n = buttons.length;
        // Shift+Tab can arrive as Backtab or as Tab with Shift held.
        const back = event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier));
        if (kbIndex < 0) {
            if (event.key !== Qt.Key_Tab || back)
                return false;
            kbIndex = 0;
        } else if (event.key === Qt.Key_Escape || back) {
            leave();
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            kbIndex = (kbIndex + 1) % n;
        } else if (event.key === Qt.Key_Left) {
            kbIndex = (kbIndex + n - 1) % n;
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            press(kbIndex);
        } else if (event.text === "" && event.key !== Qt.Key_Backspace) {
            // Keys that type nothing (Shift, Ctrl, ...) are ignored, so the Shift of Shift+Tab can't send Enter to the field.
        } else {
            leave();
            return false;       // back to the password field, which types this key
        }
        event.accepted = true;
        return true;
    }

    spacing: 12 * ui

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = -1
    }

    Repeater {
        model: root.buttons

        Rectangle {
            id: item

            required property var modelData
            required property int index
            readonly property bool lit: area.containsMouse || root.kbIndex === index
            readonly property bool isArmed: root.armed === index

            width: 56 * root.ui
            height: width
            radius: 6 * root.ui
            color: isArmed ? Qt.alpha(modelData.colour, 0.25) : lit ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh
            border.width: 2 * root.ui
            border.color: lit || isArmed ? item.modelData.colour : "transparent"
            scale: lit ? 1.06 : 1

            Behavior on scale {
                NumberAnimation { duration: 120 }
            }
            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: item.isArmed ? "check" : item.modelData.icon
                font.pixelSize: 28 * root.ui
                color: item.modelData.colour
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.press(item.index)
            }
        }
    }
}
