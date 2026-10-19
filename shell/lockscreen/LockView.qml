pragma ComponentBehavior: Bound
// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): layout modeled on its lock screen (modules/lock).
// The lock screen for one screen: blurred wallpaper (a gradient without one), one panel with three columns: weather,
// calendar, media | clock, avatar, password, power row | hardware monitor (PerfColumn).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

Item {
    id: root

    required property var auth
    readonly property real ui: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real cm: 27.5 * ui     // 1 cm on this monitor (697 mm wide, 1920 logical px)
    readonly property bool capsLock: capsLeds.instances.some(f => f.on)

    signal unlocked    // the fade-out finished: the caller can now release the session lock

    function unlock(): void {
        unlockAnim.start();
    }

    Connections {
        target: root.auth
        function onSuccess() {
            root.unlock();
        }
    }

    // Caps lock has no Wayland event for clients: read the keyboard LEDs (files found once, then only re-read).
    property var capsLedPaths: []
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/leds/*::capslock; do [ -r \"$d/brightness\" ] && echo \"$d/brightness\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLedPaths = text.split("\n").filter(l => l !== "")
        }
    }
    Variants {
        id: capsLeds
        model: root.capsLedPaths
        FileView {
            required property string modelData
            property bool on: false
            path: modelData
            onLoaded: on = Number(text().trim()) > 0
        }
    }
    Timer {
        interval: 400
        running: root.capsLedPaths.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: capsLeds.instances.forEach(f => f.reload())
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    property string wallpaper: ""
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/cts1/wallpaper"
        printErrors: false      // no file until a wallpaper is first picked: the gradient stays
        onLoaded: root.wallpaper = text().trim()
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.m3surfaceContainerHighest }
                GradientStop { position: 1; color: Theme.m3surfaceContainer }
            }
        }
        Item {
            anchors.fill: parent
            visible: wallImage.status === Image.Ready

            layer.enabled: visible
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
            }

            Image {
                id: wallImage
                anchors.fill: parent
                source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.width, root.height)
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: wallImage.status === Image.Ready ? 0.4 : 0
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        // Left column, 1 cm, main column, 1 cm, hardware monitor; 1 cm margin all round.
        width: leftBox.Layout.preferredWidth + powerRow.implicitWidth + perfColumn.Layout.preferredWidth + 4 * root.cm
        height: Math.min(root.height - 96 * root.ui, centerCol.implicitHeight + 2 * root.cm)
        radius: 6 * root.ui
        color: Qt.alpha(Theme.m3surface, 0.9)
        opacity: 0
        scale: 0.94

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: root.cm
            spacing: 0

            // Laid out at taskbar size (320 px wide) and scaled with the rest.
            Item {
                id: leftBox
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 320 * root.ui
                Layout.preferredHeight: leftContent.implicitHeight * root.ui
                Layout.rightMargin: root.cm

                ColumnLayout {
                    id: leftContent
                    width: 320
                    scale: root.ui
                    transformOrigin: Item.TopLeft
                    spacing: Theme.spacing.medium

                    WeatherCard { Layout.fillWidth: true }
                    CalendarCard { Layout.fillWidth: true }
                    MediaCompact { Layout.fillWidth: true }
                }
            }

            ColumnLayout {
                id: centerCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 14 * root.ui

                Clock {
                    Layout.alignment: Qt.AlignHCenter
                    ui: root.ui
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockDate.date, "dddd • d MMM").toUpperCase()
                    font.pixelSize: Theme.fontSize.large * root.ui
                    font.weight: Font.DemiBold

                    SystemClock {
                        id: clockDate
                        precision: SystemClock.Minutes
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14 * root.ui
                    Layout.bottomMargin: 10 * root.ui
                    implicitWidth: 150 * root.ui
                    implicitHeight: 150 * root.ui

                    Rectangle {
                        anchors.fill: parent
                        radius: 6 * root.ui
                        color: Theme.m3surfaceContainerHighest
                        clip: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "person"
                            font.pixelSize: 72 * root.ui
                            color: Theme.m3onSurfaceVariant
                        }
                        Image {
                            id: face
                            anchors.fill: parent
                            source: "file://" + Quickshell.env("HOME") + "/.face"
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(300, 300)
                            cache: false
                            visible: status === Image.Ready
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: faceMask
                            }
                        }
                        Rectangle {
                            id: faceMask
                            anchors.fill: parent
                            radius: 6 * root.ui
                            visible: false
                            layer.enabled: true
                        }
                    }
                }

                PasswordField {
                    Layout.fillWidth: true
                    auth: root.auth
                    ui: root.ui
                    keyFilter: event => powerRow.handleKey(event)
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22 * root.ui
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignTop
                    wrapMode: Text.WordWrap
                    text: {
                        if (powerRow.armed >= 0)
                            return "Press again to " + powerRow.armedName;
                        if (root.auth.lockMessage)
                            return root.auth.lockMessage;
                        if (root.auth.state === Auth.MaxTries)
                            return "Too many attempts. Try again later.";
                        if (root.auth.state === Auth.Failed)
                            return "Incorrect password";
                        if (root.auth.state === Auth.Error)
                            return "Authentication error";
                        if (root.capsLock)
                            return "Caps lock is ON";
                        return "";
                    }
                    color: powerRow.armed >= 0 || (root.auth.state === Auth.None && !root.auth.lockMessage) ? Theme.m3tertiary : Theme.m3error
                    font.pixelSize: Theme.fontSize.larger * root.ui
                }

                PowerRow {
                    id: powerRow
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6 * root.ui
                    ui: root.ui
                }
            }

            // Shrunk evenly until its full height (4 x 125 + 160 + 4 x 12) matches the middle column.
            PerfColumn {
                id: perfColumn
                readonly property real fit: Math.min(1, centerCol.implicitHeight / (708 * root.ui))
                Layout.preferredWidth: 390 * root.ui * fit
                Layout.fillHeight: true
                Layout.leftMargin: root.cm
                ui: root.ui * fit
            }
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        NumberAnimation { target: background; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            ParallelAnimation {
                NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
        }
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: panel; property: "scale"; to: 0.95; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: background; property: "opacity"; to: 0; duration: 320; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.unlocked() }
    }
}
