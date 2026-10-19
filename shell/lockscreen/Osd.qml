// The shell's volume/brightness indicator on the lock screen (sway draws nothing else while locked); never takes clicks.
import QtQuick
import qs

Item {
    id: root

    required property bool shown
    required property string kind       // "volume" / "brightness"
    required property real rawLevel
    required property bool rawMuted

    readonly property real level: Math.max(0, Math.min(1, rawLevel))
    readonly property bool muted: kind === "volume" && rawMuted

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 64
    width: 320
    height: 64
    visible: opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.m3surface
        border.color: Theme.m3outlineVariant
        border.width: 1

        MaterialIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: root.kind === "brightness"
                ? (root.level < 0.34 ? "brightness_low" : root.level < 0.67 ? "brightness_medium" : "brightness_high")
                : root.muted || root.level <= 0 ? "volume_off" : root.level < 0.34 ? "volume_mute"
                : root.level < 0.67 ? "volume_down" : "volume_up"
            font.pixelSize: 26
            color: root.muted ? Theme.red : Theme.m3primary
        }

        Rectangle {
            anchors.left: icon.right
            anchors.leftMargin: 14
            anchors.right: percent.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 10
            radius: 5
            color: Theme.m3surfaceContainer

            Rectangle {
                anchors.left: parent.left
                height: parent.height
                width: parent.width * root.level
                radius: 5
                color: root.muted ? Theme.m3outline : Theme.m3primary
                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            id: percent
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.level * 100) + "%"
            font.pixelSize: 17
            font.bold: true
            color: root.muted ? Theme.m3outline : Theme.m3onSurface
        }
    }
}
