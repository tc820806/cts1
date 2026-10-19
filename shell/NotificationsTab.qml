import QtQuick
import QtQuick.Layouts

// Notification history for the bell's popup (data in Notifs.qml).
Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Notifs.notClosed.length > 0
                    ? Notifs.notClosed.length + (Notifs.notClosed.length === 1 ? " notification" : " notifications")
                    : "Notifications"
                color: Theme.m3onSurface
                font.pixelSize: Theme.fontSize.large
                font.bold: true
            }

            Rectangle {
                visible: Notifs.list.length > 0
                implicitWidth: clearRow.implicitWidth + 16
                implicitHeight: 28
                radius: 6
                color: clearArea.containsMouse ? Theme.m3surfaceContainerHighest : "transparent"

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon { text: "clear_all"; color: Theme.m3outline; font.pixelSize: 16 }
                    StyledText { text: "Clear"; color: Theme.m3outline; font.pixelSize: Theme.fontSize.small }
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Notifs.clearHistory()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.m3outlineVariant
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 8

                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 40
                    implicitHeight: emptyCol.implicitHeight
                    visible: Notifs.list.length === 0

                    ColumnLayout {
                        id: emptyCol
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "notifications_off"
                            font.pixelSize: 40
                            color: Theme.m3outlineVariant
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "All up to date!"
                            color: Theme.m3outlineVariant
                        }
                    }
                }

                Repeater {
                    model: Notifs.list

                    NotificationPopup {
                        Layout.fillWidth: true
                        autoDismiss: false
                        onDismissed: Notifs.remove(modelData._key)
                    }
                }
            }
        }
    }
}
