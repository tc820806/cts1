// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: power off / reboot through Login.qml (systemctl) instead of sddm.powerOff/reboot, a third button
// that reboots into the firmware setup (BIOS), icons centred, keyboard selection (kbIndex, driven by Main's key handler),
// SDDM's `config` -> Config (Config.qml).
pragma ComponentBehavior: Bound
import "../components"
import qs
import QtQuick

Item {
    id: root

    property real rectHeight
    property real rectWidth
    property real rectRadius

    readonly property real spacing: 12
    property int kbIndex: -1            // button selected with the keyboard (Tab, then Left/Right); -1 = none
    readonly property var buttons: [
        {
            icon: "", // power_settings_new
            act: () => Login.powerOff()
        },
        {
            icon: "", // autorenew
            act: () => Login.reboot()
        },
        {
            icon: "", // developer_board
            act: () => Login.rebootToFirmware()
        }
    ]

    function press(i: int): void {
        buttons[i].act();
    }

    anchors.fill: parent

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.buttons

            delegate: Rectangle {
                id: btn

                required property var modelData
                required property int index

                height: root.height
                width: (root.width - root.spacing * (root.buttons.length - 1)) / root.buttons.length
                radius: root.rectRadius
                color: Config.subComponents
                border.width: root.kbIndex === btn.index ? 3 : 0
                border.color: Config.primary
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: btn.modelData.icon
                    color: Config.secondary
                    font.family: "Material Symbols Rounded"
                    font.pointSize: 56
                }

                LayerState {
                    anchors.fill: parent
                    parentWidth: btn.width
                    parentHeight: btn.height
                    parentRadius: btn.radius
                    onClicked: btn.modelData.act()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }
    }
}
