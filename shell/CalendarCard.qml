// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): month grid from modules/dashboard/dash/Calendar.qml.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Month calendar: arrows / wheel change the month; the month name or a middle-click goes back to today.
Rectangle {
    id: card
    color: Theme.m3surfaceContainer
    implicitWidth: 344
    implicitHeight: calInner.implicitHeight + Theme.padding.large * 2

    property date calDate: new Date()
    // Starts on the current month each time it opens.
    onVisibleChanged: if (visible) calDate = new Date()

    radius: 6

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: card.calDate = new Date()
        onWheel: wheel => card.calDate = new Date(card.calDate.getFullYear(),
            card.calDate.getMonth() + (wheel.angleDelta.y > 0 ? -1 : 1), 1)
    }

    ColumnLayout {
        id: calInner
        anchors.fill: parent
        anchors.margins: Theme.padding.large
        spacing: Theme.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.extraSmall

            IconButton {
                icon: "chevron_left"
                implicitWidth: 36
                implicitHeight: 36
                onClicked: card.calDate = new Date(card.calDate.getFullYear(), card.calDate.getMonth() - 1, 1)
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: monthLabel.implicitHeight + Theme.padding.extraSmall * 2

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.m3primary
                    opacity: monthArea.containsMouse ? 0.1 : 0
                }
                StyledText {
                    id: monthLabel
                    anchors.centerIn: parent
                    text: Qt.formatDate(card.calDate, "MMMM yyyy")
                    color: Theme.m3primary
                    font.pixelSize: Theme.fontSize.larger
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: monthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.calDate = new Date()
                }
            }
            IconButton {
                icon: "chevron_right"
                implicitWidth: 36
                implicitHeight: 36
                onClicked: card.calDate = new Date(card.calDate.getFullYear(), card.calDate.getMonth() + 1, 1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: StyledText {
                required property var model
                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font.pixelSize: Theme.fontSize.smaller
                font.weight: Font.Medium
                color: (model.day === 0 || model.day === 6) ? Theme.m3tertiary : Theme.m3onSurface
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            month: card.calDate.getMonth()
            year: card.calDate.getFullYear()
            spacing: 3
            locale: Qt.locale()

            delegate: Item {
                id: dayItem
                required property var model
                implicitWidth: implicitHeight
                implicitHeight: dayText.implicitHeight + Theme.padding.small

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(dayText.implicitWidth, dayText.implicitHeight) + Theme.padding.small
                    height: width
                    radius: 6
                    color: Theme.m3primary
                    visible: dayItem.model.today
                }
                StyledText {
                    id: dayText
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: grid.locale.toString(dayItem.model.day)
                    font.pixelSize: Theme.fontSize.small
                    color: dayItem.model.today ? Theme.m3onPrimary
                         : (dayItem.model.date.getDay() === 0 || dayItem.model.date.getDay() === 6) ? Theme.m3tertiary
                         : Theme.m3onSurfaceVariant
                    opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                }
            }
        }
    }
}
