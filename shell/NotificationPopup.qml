// One notification card: a toast (top right) or, full width, an entry in the bell's history (NotificationsTab).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Rectangle {
    id: root

    required property var modelData
    // Off in the history list: there an entry stays until cleared by hand.
    property bool autoDismiss: true
    signal dismissed

    // The "default" action is a click on the card, not a button (kitty sends it with a blank label).
    readonly property var buttonActions: (modelData.actions || []).filter(a => a.identifier !== "default")

    // Quickshell passes the icon through `image` as "image://icon/<path or theme name>" (appIcon stays empty); an inline
    // content image (a photo) comes without that prefix.
    readonly property string iconImagePrefix: "image://icon/"
    readonly property bool hasContentImage: modelData.image && modelData.image.length > 0
                                             && !modelData.image.startsWith(iconImagePrefix)
    readonly property string rawIconRef: modelData.image && modelData.image.startsWith(iconImagePrefix)
        ? modelData.image.substring(iconImagePrefix.length) : (modelData.appIcon || "")

    // image://icon/ serves a checkerboard for an unknown name (status stays Ready), so a bare name is looked up on disk
    // first (bin/find-icon: hicolor, then pixmaps, then any theme).
    property string appIconSource: rawIconRef.startsWith("/") ? "file://" + rawIconRef
                                   : rawIconRef.startsWith("file://") || rawIconRef.startsWith("http") ? rawIconRef
                                   : ""
    readonly property string iconNameToResolve:
        rawIconRef && !rawIconRef.startsWith("/") && !rawIconRef.startsWith("file://") && !rawIconRef.startsWith("http")
            ? rawIconRef : ""

    Process {
        id: iconLookup
        command: root.iconNameToResolve.length > 0
            ? [Quickshell.shellPath("bin/find-icon"), root.iconNameToResolve]
            : []
        running: command.length > 0
        stdout: StdioCollector {
            onStreamFinished: {
                const hit = text.trim().split("\n")[0];
                if (hit)
                    root.appIconSource = "file://" + hit;
            }
        }
    }

    implicitWidth: 340
    implicitHeight: content.implicitHeight + 24
    radius: 6
    color: modelData.urgency === NotificationUrgency.Critical ? Qt.darker(Theme.m3error, 1.6) : Theme.m3surfaceContainerHigh
    border.width: modelData.urgency === NotificationUrgency.Critical ? 1 : 0
    border.color: Theme.m3error

    // Notifs.qml keeps the toast's time (this card is rebuilt when the list changes); the card only reports the pointer.
    HoverHandler {
        id: hover       // a handler, not a MouseArea: stays hovered over the close / action buttons too
        onHoveredChanged: if (root.autoDismiss) Notifs.holdToast(root.modelData._key, hovered)
    }
    Component.onDestruction: if (autoDismiss && hover.hovered) Notifs.holdToast(modelData._key, false)

    // Click: the default action. A toast then closes; a history card stays (dismissing it would delete it).
    readonly property var defaultAction: (modelData.actions || []).find(a => a.identifier === "default") || null
    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction || root.autoDismiss ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            const popup = root;     // invoking can make the sender close the notification, removing this card
            if (popup.defaultAction)
                popup.defaultAction.invoke();
            if (popup && popup.autoDismiss)
                popup.dismissed();
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 6
                color: Theme.m3secondaryContainer
                clip: true

                // Inline image, else the app icon, else a bell.
                Image {
                    anchors.fill: parent
                    visible: root.hasContentImage
                    source: root.hasContentImage ? Qt.resolvedUrl(root.modelData.image) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: !root.hasContentImage && root.appIconSource.length > 0
                    source: root.appIconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !root.hasContentImage && root.appIconSource.length === 0
                    text: "notifications"
                    color: Theme.m3onSecondaryContainer
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.modelData.summary
                color: root.modelData.urgency === NotificationUrgency.Critical ? "white" : Theme.m3onSurface
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize.normal
                font.bold: true
            }

            StyledText {
                text: root.modelData.appName
                color: root.modelData.urgency === NotificationUrgency.Critical ? "white" : Theme.m3outline
                font.pixelSize: Theme.fontSize.small
            }

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 6
                color: closeArea.containsMouse ? Theme.m3outlineVariant : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 14
                    color: root.modelData.urgency === NotificationUrgency.Critical ? "white" : Theme.m3outline
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.dismissed()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.modelData.body && root.modelData.body.length > 0
            text: root.modelData.body
            color: root.modelData.urgency === NotificationUrgency.Critical ? "white" : Theme.m3onSurfaceVariant
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSize.smaller
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.buttonActions.length > 0
            spacing: 6

            Repeater {
                model: root.buttonActions

                Rectangle {
                    required property var modelData

                    implicitWidth: actionText.implicitWidth + 20
                    implicitHeight: 26
                    radius: 6
                    color: actionArea.containsMouse ? Theme.m3primaryContainer : Theme.m3surfaceContainerHighest

                    StyledText {
                        id: actionText
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        color: Theme.m3onPrimaryContainer
                        font.pixelSize: Theme.fontSize.small
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            // Invoking can make the sender close it, removing this card: keep a reference.
                            const popup = root;
                            parent.modelData.invoke();
                            if (popup)
                                popup.dismissed();
                        }
                    }
                }
            }
        }
    }
}
