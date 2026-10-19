// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): cover + progress-ring layout from modules/dashboard/dash/Media.qml.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs

// Lock screen version of MediaPlayer.qml, laid out sideways (about 130 px tall).
Rectangle {
    id: card
    color: Theme.m3surfaceContainer
    implicitWidth: 320
    implicitHeight: row.implicitHeight + Theme.padding.medium * 2
    radius: 6

    readonly property var player: Players.active
    property real progress: player && player.length > 0 ? (player.position % player.length) / player.length : 0
    Behavior on progress {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    Timer {
        running: card.player !== null && card.player.isPlaying
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: card.player.positionChanged()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Theme.padding.medium
        spacing: Theme.spacing.medium

        Item {
            implicitWidth: 104
            implicitHeight: 104

            // Outside the ring: bars from radius 40 grow by up to 9 px (plus round caps) within the 104 px box
            Visualizer {
                anchors.fill: parent
                innerRadius: 40
                depth: 9
                barWidth: 2
            }

            CircularProgress {
                visible: card.player !== null && card.player.lengthSupported && card.player.length > 0
                anchors.centerIn: parent
                width: 76
                height: 76
                strokeWidth: 4
                startAngle: -90
                sweepAngle: 360
                value: card.progress
            }

            Rectangle {
                id: cover
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: width / 2
                color: Theme.m3surfaceContainerHigh
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: Players.getArtUrl(card.player)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceClipRect: source.toString().indexOf("hqdefault") >= 0 ? Qt.rect(0, 45, 480, 270) : Qt.rect(0, 0, 0, 0)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artMask
                    }
                }
                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "art_track"
                    font.pixelSize: 32
                    color: Theme.m3onSurfaceVariant
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: card.player ? (card.player.trackTitle || "Unknown title") : "No media playing"
                color: Theme.m3primary
                font.pixelSize: Theme.fontSize.larger
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                visible: card.player !== null
                text: card.player ? (card.player.trackArtist || "Unknown artist") : ""
                color: Theme.m3secondary
                font.pixelSize: Theme.fontSize.small
            }
            Row {
                Layout.topMargin: Theme.spacing.extraSmall
                spacing: Theme.spacing.extraSmall

                IconButton {
                    tonal: true
                    icon: "skip_previous"
                    implicitWidth: 36
                    implicitHeight: 36
                    iconSize: 20
                    disabled: !(card.player && card.player.canGoPrevious)
                    onClicked: card.player.previous()
                }
                IconButton {
                    icon: card.player && card.player.isPlaying ? "pause" : "play_arrow"
                    checked: card.player !== null && card.player.isPlaying
                    implicitWidth: 52
                    implicitHeight: 36
                    iconSize: 20
                    disabled: !(card.player && card.player.canTogglePlaying)
                    onClicked: card.player.togglePlaying()
                }
                IconButton {
                    tonal: true
                    icon: "skip_next"
                    implicitWidth: 36
                    implicitHeight: 36
                    iconSize: 20
                    disabled: !(card.player && card.player.canGoNext)
                    onClicked: card.player.next()
                }
            }
        }
    }
}
