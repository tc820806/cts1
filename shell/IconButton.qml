import QtQuick

// Round icon button. `tonal` = secondary-container fill; `checked` = primary fill.
Rectangle {
    id: btn

    property string icon: ""
    property bool tonal: false
    property bool checked: false
    property bool danger: false     // red fill, for a destructive action waiting for confirmation
    property bool disabled: false
    property int iconSize: 22
    signal clicked()

    implicitWidth: 44
    implicitHeight: 44
    radius: 6
    opacity: disabled ? 0.4 : 1
    color: danger ? Theme.m3error : checked ? Theme.m3primary : tonal ? Theme.m3secondaryContainer : "transparent"

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.m3onSurface
        opacity: mouse.pressed ? 0.12 : mouse.containsMouse ? 0.08 : 0
    }
    MaterialIcon {
        anchors.centerIn: parent
        text: btn.icon
        font.pixelSize: btn.iconSize
        color: btn.danger ? Theme.m3onError : btn.checked ? Theme.m3onPrimary : btn.tonal ? Theme.m3onSecondaryContainer : Theme.m3onSurfaceVariant
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !btn.disabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
