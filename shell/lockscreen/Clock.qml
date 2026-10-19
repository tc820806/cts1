// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): styled after its lock screen clock.
import QtQuick
import Quickshell
import qs

// Big clock like Caelestia's lock: hours in the primary color, minutes in the secondary, AM/PM chip beside them.
Item {
    id: root

    property real ui: 1

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        spacing: 10 * root.ui

        StyledText {
            text: String((clock.date.getHours() + 11) % 12 + 1)
            color: Theme.m3primary
            font.pixelSize: 150 * root.ui
            font.weight: Font.DemiBold
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.ui

            StyledText {
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.m3secondary
                font.pixelSize: 78 * root.ui
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: ampm.implicitWidth + 24 * root.ui
                height: ampm.implicitHeight + 8 * root.ui
                radius: 6 * root.ui
                color: Theme.m3surfaceContainerHigh

                StyledText {
                    id: ampm
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "AP")
                    font.pixelSize: Theme.fontSize.larger * root.ui
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
