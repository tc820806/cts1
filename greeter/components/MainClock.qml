// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: 12-hour clock without a leading zero (like CTS1's lock screen), SDDM's `config` -> Config (Config.qml).
import QtQuick
import qs

Item {
    id: root

    property bool firstInput
    property real mainCardComponentsOpacity
    property bool ap

    property real centerScale: 1
    property date currentTime: new Date()

    readonly property var fontAxesHours: ({
            "wght": 500,
            "wdth": 50,
            "ROND": 25,
            "opsz": 224 * centerScale
        })
    readonly property var fontAxesMinutes: ({
            "wght": 500,
            "wdth": 50,
            "ROND": 25,
            "opsz": 224 * centerScale
        })

    FontLoader {
        id: googleSansFlex

        source: "../assets/google-sans-flex/GoogleSansFlex.ttf"
    }

    Row {
        id: clock
        anchors.centerIn: parent

        Text {
            id: hourText

            renderType: Text.NativeRendering
            font.family: googleSansFlex.name
            font.variableAxes: root.fontAxesHours
            font.pixelSize: Math.round(224 * root.centerScale)
            color: Qt.lighter(Config.primary, 1.6)
            text: {
                if (!root.ap)
                    return Qt.formatTime(root.currentTime, "hh");
                return String((root.currentTime.getHours() + 11) % 12 + 1);
            }
        }

        Item {
            width: 5
            height: 1
        }

        Text {
            id: minuteText

            renderType: Text.NativeRendering
            font.family: googleSansFlex.name
            font.variableAxes: root.fontAxesMinutes
            font.pixelSize: Math.round(224 * root.centerScale)
            color: Config.secondary
            text: Qt.formatTime(root.currentTime, "mm")
        }

        Text {
            id: amPmText

            visible: root.ap
            anchors.bottom: minuteText.bottom
            anchors.bottomMargin: Math.round(28 * root.centerScale)
            renderType: Text.NativeRendering
            font.family: googleSansFlex.name
            font.pixelSize: Math.max(14, Math.round(28 * root.centerScale))
            font.bold: true
            color: Config.secondary
            text: root.currentTime.getHours() >= 12 ? "PM" : "AM"
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
        }
    }
}
