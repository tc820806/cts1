import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Performance popup (Super+P): user card + PerfRow. Overlay layer so it shows above fullscreen games, not dimmed;
// it takes the keyboard (for Escape), so a game gets no keys while it is open.
Scope {
    id: perf

    property bool open: false

    IpcHandler {
        target: "perf"
        function toggle(): void { perf.open = !perf.open; }
        function open(): void { perf.open = true; }
        function close(): void { perf.open = false; }
    }

    PanelWindow {
        visible: perf.open || panel.opacity > 0.01
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: perf.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: perf.open = false
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: perf.open = false
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: content.implicitWidth + Theme.padding.large * 2
            height: content.implicitHeight + Theme.padding.large * 2
            radius: 6
            color: Theme.m3surface
            border.color: Theme.m3outlineVariant
            border.width: 1
            opacity: perf.open ? 1 : 0
            scale: perf.open ? 1 : 0.95
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent    // clicks on the panel itself must not close it
            }

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: Theme.spacing.medium

                UserCard {
                    Layout.fillWidth: true
                    radius: 6
                    onPickerOpened: perf.open = false
                }
                PerfRow {
                    implicitWidth: 899
                    active: perf.open
                }
            }
        }
    }
}
