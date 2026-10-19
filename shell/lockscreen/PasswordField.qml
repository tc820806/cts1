import QtQuick
import QtQuick.Layouts
import qs

FocusScope {
    id: root

    required property var auth
    property real ui: 1
    property bool busy: root.auth.passwd.active
    property var keyFilter: null        // gets every key first; returns true if it used it (the power row's keyboard use)

    implicitHeight: 60 * ui
    // `focus: true` isn't enough (its layouts aren't focus scopes): claim the keyboard at once and whenever it is lost
    // (the lock surface may not be active yet at creation).
    focus: true
    Component.onCompleted: forceActiveFocus()
    onActiveFocusChanged: {
        if (!activeFocus)
            forceActiveFocus();
    }

    Timer {
        running: !root.activeFocus
        interval: 150
        repeat: true
        onTriggered: root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (!(root.keyFilter && root.keyFilter(event)))
            root.auth.handleKey(event);
    }

    Connections {
        target: root.auth
        function onFlashMsg() {
            shake.restart();
        }
    }

    Rectangle {
        id: pill

        width: root.width
        height: root.height
        radius: 6 * root.ui
        color: Theme.m3surfaceContainerHigh
        border.width: 2 * root.ui
        border.color: root.auth.state === Auth.Failed || root.auth.state === Auth.MaxTries || root.auth.state === Auth.Error
                      ? Theme.m3error : (root.auth.buffer.length > 0 ? Theme.m3primary : "transparent")

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: pill; property: "x"; to: -14 * root.ui; duration: 50 }
            NumberAnimation { target: pill; property: "x"; to: 14 * root.ui; duration: 90 }
            NumberAnimation { target: pill; property: "x"; to: -8 * root.ui; duration: 80 }
            NumberAnimation { target: pill; property: "x"; to: 0; duration: 60 }
        }

        MaterialIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 18 * root.ui
            anchors.verticalCenter: parent.verticalCenter
            text: "lock"
            font.pixelSize: 26 * root.ui
            color: Theme.m3onSurfaceVariant
        }

        Item {
            id: field
            anchors.left: icon.right
            anchors.leftMargin: 14 * root.ui
            anchors.right: enter.left
            anchors.rightMargin: 14 * root.ui
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            clip: true

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.auth.buffer.length === 0
                text: root.busy ? "Checking…" : "Enter password"
                color: Theme.m3outline
                font.pixelSize: Theme.fontSize.larger * root.ui
            }

            Row {
                id: dots
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(0, field.width - width)
                spacing: 8 * root.ui

                Repeater {
                    model: root.auth.buffer.length

                    Rectangle {
                        width: 12 * root.ui
                        height: width
                        radius: width / 2
                        color: Theme.m3onSurface
                    }
                }
            }
        }

        Rectangle {
            id: enter
            anchors.right: parent.right
            anchors.rightMargin: 8 * root.ui
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 16 * root.ui
            height: width
            radius: 6 * root.ui
            color: root.auth.buffer.length > 0 ? Theme.m3primary : Theme.m3surfaceContainerHighest

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.busy ? "hourglass_top" : "arrow_forward"
                font.pixelSize: 24 * root.ui
                color: root.auth.buffer.length > 0 ? Theme.m3onPrimary : Theme.m3onSurfaceVariant
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.auth.buffer.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.auth.submit()
            }
        }
    }
}
