// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: sessions from Login.qml (the .desktop files) instead of SDDM's sessionModel, SDDM's `config` -> Config (Config.qml).
pragma ComponentBehavior: Bound
import QtQuick
import qs

Item {
    id: root

    property bool expanded: false
    // Login fills its list after start-up.
    readonly property int count: Login.sessions.count
    readonly property var items: {
        const arr = [];
        for (let i = 0; i < Login.sessions.count; i++)
            arr.push(Login.sessions.get(i).name);
        return arr;
    }
    property int selectedIndex: 0
    readonly property string currentText: selectedIndex >= 0 && selectedIndex < items.length ? items[selectedIndex] : ""

    width: labelRect.width + expandBtn.width
    height: 40
    opacity: root.count > 0 ? 1 : 0
    enabled: root.count > 0

    Rectangle {
        id: labelRect

        radius: 6
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Config.subComponents

        width: 210

        Row {
            id: labelRow

            anchors.verticalCenter: labelRect.verticalCenter
            anchors.left: labelRect.left
            anchors.leftMargin: 15
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "Material Symbols Rounded"
                font.pointSize: 16
                text: "widgets"
                color: Config.primary
            }

            Text {
                id: labelText

                anchors.verticalCenter: parent.verticalCenter
                text: root.currentText
                color: Config.text
                font.pixelSize: 14
                font.family: "Rubik"
                elide: Text.ElideRight
            }
        }

        LayerState {
            anchors.fill: parent
            parentWidth: labelRect.width
            parentHeight: labelRect.height
            parentRadius: labelRect.radius
            disabled: true
        }
    }

    Rectangle {
        id: expandBtn

        radius: 6
        anchors.left: labelRect.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Config.primary

        width: height

        Text {
            id: expandIcon

            anchors.centerIn: expandBtn
            anchors.horizontalCenterOffset: root.expanded ? 0 : -2
            font.family: "Material Symbols Rounded"
            font.pointSize: 18
            text: "expand_more"
            color: Config.textOnPrimary
            rotation: root.expanded ? 180 : 0

            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutCubic
                }
            }

            Behavior on rotation {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutCubic
                }
            }
        }

        LayerState {
            anchors.fill: parent
            parentWidth: expandBtn.width
            parentHeight: expandBtn.height
            parentRadius: expandBtn.radius
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        id: menuRect

        visible: root.expanded
        color: Config.subComponents
        radius: 6
        border.color: Config.outline
        border.width: 1

        anchors.top: labelRect.bottom
        anchors.topMargin: 4
        anchors.left: labelRect.left
        anchors.leftMargin: -10
        width: 260
        height: Math.min(200, root.count * 36)

        clip: true

        opacity: root.expanded ? 1 : 0
        transform: Translate {
            y: root.expanded ? 0 : -10
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutCubic
            }
        }

        ListView {
            id: sessionList

            anchors.fill: parent
            anchors.margins: 4
            model: root.items
            currentIndex: root.selectedIndex
            clip: true
            boundsBehavior: ListView.StopAtBounds
            contentHeight: root.count * 32
            implicitHeight: contentHeight

            delegate: Rectangle {
                id: delegateItem

                required property int index

                width: parent.width
                height: 32
                radius: 6
                color: index === ListView.view.currentIndex ? Config.primary : "transparent"
                opacity: index === ListView.view.currentIndex ? 0.2 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedIndex = delegateItem.index;
                        root.expanded = false;
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.items[delegateItem.index]
                    color: Config.text
                    font.pixelSize: 13
                    font.family: "Rubik"
                    elide: Text.ElideRight
                    leftPadding: 4
                    rightPadding: 4
                }
            }
        }
    }

    MouseArea {
        id: dismissArea

        anchors.fill: root
        z: -1
        enabled: root.expanded
        onClicked: root.expanded = false
    }
}
