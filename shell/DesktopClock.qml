// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): desktop clock design from
// modules/background/DesktopClock.qml, as ported to CTS2's KDE version.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    property date now: new Date()
    property real clockScale: 1

    implicitWidth: layout.implicitWidth + 16 * 4 * clockScale
    implicitHeight: layout.implicitHeight + 32 * clockScale

    Item {
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.7
            shadowBlur: 0.4
        }

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 16 * root.clockScale

            RowLayout {
                spacing: 8

                Text {
                    // 12-hour, no leading zero, like the lock screen (3:17 -> "3" "17" "PM").
                    text: String((root.now.getHours() + 11) % 12 + 1)
                    color: Theme.m3primary
                    font.family: Theme.sans
                    font.pointSize: 28 * 3 * root.clockScale
                    font.weight: Font.Bold
                }
                Text {
                    text: ":"
                    color: Theme.m3tertiary
                    opacity: 0.8
                    font.family: Theme.sans
                    font.pointSize: 28 * 3 * root.clockScale
                    Layout.topMargin: -16 * 1.5 * root.clockScale
                }
                Text {
                    text: Qt.formatTime(root.now, "mm")
                    color: Theme.m3secondary
                    font.family: Theme.sans
                    font.pointSize: 28 * 3 * root.clockScale
                    font.weight: Font.Bold
                }
                Text {
                    text: root.now.getHours() >= 12 ? "PM" : "AM"
                    color: Theme.m3secondary
                    font.family: Theme.sans
                    font.pointSize: 28 * root.clockScale
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignBaseline
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 4 * root.clockScale
                Layout.topMargin: 16 * root.clockScale
                Layout.bottomMargin: 16 * root.clockScale
                radius: width / 2
                color: Theme.m3primary
                opacity: 0.8
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: Qt.formatDate(root.now, "MMMM").toUpperCase()
                    color: Theme.m3secondary
                    font.family: Theme.sans
                    font.pointSize: 16 * root.clockScale
                    font.letterSpacing: 4
                    font.weight: Font.Bold
                }
                Text {
                    text: Qt.formatDate(root.now, "dd")
                    color: Theme.m3primary
                    font.family: Theme.sans
                    font.pointSize: 28 * root.clockScale
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                Text {
                    text: Qt.formatDate(root.now, "dddd")
                    color: Theme.m3secondary
                    font.family: Theme.sans
                    font.pointSize: 16 * root.clockScale
                    font.letterSpacing: 2
                }
            }
        }
    }

    // Wakes on each minute's turn rather than polling.
    function refreshTime() {
        now = new Date();
        const intoMinute = now.getSeconds() * 1000 + now.getMilliseconds();
        minuteTimer.interval = Math.max(1000, 60000 - intoMinute);
        minuteTimer.restart();
    }
    Timer {
        id: minuteTimer
        onTriggered: root.refreshTime()
    }
    Component.onCompleted: refreshTime()
}
