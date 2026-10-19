// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): month grid from modules/dashboard/dash/Calendar.qml.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs

// Copy of shell/CalendarCard.qml with colors from Config. Takes no keyboard focus (typing stays in the password
// field); the card behind it is Main.qml's.
Item {
    id: card

    property date calDate: new Date()

    readonly property string sans: "Rubik"
    readonly property string icons: "Material Symbols Rounded"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: card.calDate = new Date()
        onWheel: wheel => card.calDate = new Date(card.calDate.getFullYear(),
            card.calDate.getMonth() + (wheel.angleDelta.y > 0 ? -1 : 1), 1)
    }

    component Label: Text {
        color: Config.text
        font.family: card.sans
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    component ArrowButton: Rectangle {
        id: btn
        property string icon
        signal clicked

        implicitWidth: 36
        implicitHeight: 36
        radius: 6
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Config.text
            opacity: mouse.pressed ? 0.12 : mouse.containsMouse ? 0.08 : 0
        }
        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: card.icons
            font.pixelSize: 22
            color: Config.textOnSurfaceVariant
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            ArrowButton {
                icon: "chevron_left"
                onClicked: card.calDate = new Date(card.calDate.getFullYear(), card.calDate.getMonth() - 1, 1)
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: monthLabel.implicitHeight + 8

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Config.m3primary
                    opacity: monthArea.containsMouse ? 0.1 : 0
                }
                Label {
                    id: monthLabel
                    anchors.centerIn: parent
                    text: Qt.formatDate(card.calDate, "MMMM yyyy")
                    color: Config.m3primary
                    font.pixelSize: 15
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
            ArrowButton {
                icon: "chevron_right"
                onClicked: card.calDate = new Date(card.calDate.getFullYear(), card.calDate.getMonth() + 1, 1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: Label {
                required property var model
                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font.pixelSize: 12
                font.weight: Font.Medium
                color: (model.day === 0 || model.day === 6) ? Config.tertiary : Config.text
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            month: card.calDate.getMonth()
            year: card.calDate.getFullYear()
            spacing: 3
            locale: Qt.locale()

            delegate: Item {
                id: dayItem
                required property var model
                implicitWidth: implicitHeight
                implicitHeight: dayText.implicitHeight + 8

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(dayText.implicitWidth, dayText.implicitHeight) + 8
                    height: width
                    radius: 6
                    color: Config.m3primary
                    visible: dayItem.model.today
                }
                Label {
                    id: dayText
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: grid.locale.toString(dayItem.model.day)
                    font.pixelSize: 11
                    color: dayItem.model.today ? Config.textOnPrimary
                         : (dayItem.model.date.getDay() === 0 || dayItem.model.date.getDay() === 6) ? Config.tertiary
                         : Config.textOnSurfaceVariant
                    opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                }
            }
        }
    }
}
