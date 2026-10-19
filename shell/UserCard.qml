import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Avatar + clock + WM/USER/OS/HOST card at the top of the Performance popup (a clock reachable in games).
Rectangle {
    id: root
    color: Theme.m3surfaceContainer
    implicitWidth: 687
    implicitHeight: 110

    // The Performance popup must close for the file chooser: its Overlay layer + keyboard would cover it.
    signal pickerOpened()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    property string osName: ""
    property string hostName: ""
    FileView {
        path: "/etc/os-release"
        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m);
            if (m)
                root.osName = m[1];
        }
    }
    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.hostName = text().trim()
    }

    radius: 6

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding.large
        spacing: Theme.spacing.large

        // ~/.face, else a person icon; click picks another (copied to ~/.face).
        Rectangle {
            id: pfpShape
            Layout.preferredWidth: height
            Layout.fillHeight: true
            radius: width * 0.3     // rounded-off corners, like the lock screen's avatar
            color: Theme.m3surfaceContainerHighest
            clip: true

            // Bumped after a new picture is copied in, to reload the file.
            property int revision: 0

            Image {
                id: pfp
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.face?" + pfpShape.revision
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // `clip` ignores rounded corners: mask the picture instead.
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: pfpMask
                }
            }
            Rectangle {
                id: pfpMask
                anchors.fill: parent
                radius: pfpShape.radius
                visible: false
                layer.enabled: true
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: pfp.status !== Image.Ready
                text: "person"
                font.pixelSize: 44
                color: Theme.m3onSurfaceVariant
            }
            Rectangle {
                anchors.fill: parent
                radius: pfpShape.radius
                color: Theme.m3onSurface
                opacity: pfpArea.containsMouse ? 0.12 : 0
            }
            MouseArea {
                id: pfpArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // A chooser is already open (maybe elsewhere): bring it forward.
                    if (pfpPicker.running)
                        Quickshell.execDetached(["swaymsg", "[app_id=\"xdg-desktop-portal-gtk\" title=\"^Choose a profile picture$\"] focus"]);
                    else
                        pfpPicker.running = true;
                    root.pickerOpened();
                }
            }
            Process {
                id: pfpPicker
                // zenity 4 opens the chooser through the portal as a parentless window: sway-config floats it.
                command: ["sh", "-c", "f=$(zenity --file-selection --title='Choose a profile picture' "
                    + "--file-filter='Images | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG' "
                    + "--filename=\"$(xdg-user-dir PICTURES 2>/dev/null || echo $HOME)/\") && cp -f -- \"$f\" \"$HOME/.face\""]
                onExited: code => {
                    if (code === 0)
                        pfpShape.revision++;
                }
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: Theme.spacing.small

            StyledText {
                Layout.alignment: Qt.AlignBaseline
                text: ((clock.date.getHours() + 11) % 12 + 1) + Qt.formatDateTime(clock.date, ":mm")
                color: Theme.m3secondary
                font.pixelSize: 56
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.alignment: Qt.AlignBaseline
                text: Qt.formatDateTime(clock.date, "AP")
                color: Theme.m3primary
                font.pixelSize: Theme.fontSize.large
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 64
            color: Theme.m3outlineVariant
        }

        RowLayout {
            spacing: Theme.spacing.medium

            ColumnLayout {
                spacing: 3
                Repeater {
                    model: ["WM", "USER", "OS", "HOST"]
                    StyledText {
                        required property string modelData
                        text: modelData
                        color: Theme.m3onSurfaceVariant
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: Font.Medium
                    }
                }
            }
            ColumnLayout {
                spacing: 3
                Repeater {
                    model: [SysStats.wm, SysStats.user, root.osName, root.hostName]
                    StyledText {
                        required property string modelData
                        text: modelData
                        color: Theme.m3onSurface
                        font.pixelSize: Theme.fontSize.smaller
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
