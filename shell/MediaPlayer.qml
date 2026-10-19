// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): cover + progress-ring layout from modules/dashboard/dash/Media.qml.
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris

// Media card: cover (progress ring if the player reports a length, audio bars while playing), title, album,
// artist, previous / play-pause / next.
Rectangle {
    id: card
    color: Theme.m3surfaceContainer
    implicitWidth: Theme.dash.mediaWidth
    implicitHeight: controls.y + controls.height + Theme.padding.large
    radius: 6

    readonly property var player: Players.active
    // The audio bars (and cava) run only while the card is on screen.
    property bool visualizerActive: false
    readonly property real visualizerDepth: 12
    property real progress: player && player.length > 0 ? (player.position % player.length) / player.length : 0
    Behavior on progress {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    Timer {
        running: parent.player !== null && parent.player.isPlaying
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: parent.player.positionChanged()
    }

    CircularProgress {
        // Only with a track length (Firefox/YouTube reports none).
        visible: parent.player !== null && parent.player.lengthSupported && parent.player.length > 0
        anchors.centerIn: cover
        implicitSize: cover.width + Theme.spacing.extraSmall * 2 + Theme.dash.mediaProgressThickness * 2
        strokeWidth: Theme.dash.mediaProgressThickness
        startAngle: -90 - sweepAngle / 2
        sweepAngle: Theme.dash.mediaProgressSweep
        value: parent.progress
    }

    Visualizer {
        anchors.centerIn: cover
        width: height
        height: cover.width + (Theme.spacing.extraSmall + Theme.dash.mediaProgressThickness + 2 + card.visualizerDepth) * 2 + 4
        active: card.visualizerActive
        innerRadius: cover.width / 2 + Theme.spacing.extraSmall + Theme.dash.mediaProgressThickness + 2
        depth: card.visualizerDepth - 3
    }

    Rectangle {
        id: cover
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.padding.medium + Theme.spacing.extraSmall + Theme.dash.mediaProgressThickness + 2 + card.visualizerDepth
        height: width
        radius: width / 2
        color: Theme.m3surfaceContainerHigh
        clip: true

        Image {
            id: art
            anchors.fill: parent
            source: Players.getArtUrl(parent.parent.player)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // YouTube's 480x360 hqdefault has black bars: keep the 480x270 picture.
            sourceClipRect: source.toString().indexOf("hqdefault") >= 0 ? Qt.rect(0, 45, 480, 270) : Qt.rect(0, 0, 0, 0)
            // `clip` ignores rounded corners: mask to a circle.
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
            font.pixelSize: 56
            color: Theme.m3onSurfaceVariant
        }
    }

    StyledText {
        id: mTitle
        anchors.top: cover.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacing.small + Theme.spacing.extraSmall + Theme.dash.mediaProgressThickness + 2 + card.visualizerDepth
        width: parent.width - Theme.padding.extraLargeIncreased
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: parent.player ? (parent.player.trackTitle || "Unknown title") : "No media playing"
        color: Theme.m3primary
        font.pixelSize: Theme.fontSize.larger
        font.weight: Font.Medium
    }
    StyledText {
        id: mAlbum
        anchors.top: mTitle.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacing.small
        width: parent.width - Theme.padding.extraLargeIncreased
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: parent.player ? (parent.player.trackAlbum || "Unknown album") : ""
        color: Theme.m3outline
        font.pixelSize: Theme.fontSize.small
    }
    StyledText {
        id: mArtist
        anchors.top: mAlbum.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacing.small
        width: parent.width - Theme.padding.extraLargeIncreased
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: parent.player ? (parent.player.trackArtist || "Unknown artist") : ""
        color: Theme.m3secondary
    }

    Row {
        id: controls
        anchors.top: mArtist.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacing.medium
        spacing: Theme.spacing.extraSmall

        IconButton {
            tonal: true
            icon: "skip_previous"
            disabled: !(parent.parent.player && parent.parent.player.canGoPrevious)
            onClicked: parent.parent.player.previous()
        }
        IconButton {
            icon: parent.parent.player && parent.parent.player.isPlaying ? "pause" : "play_arrow"
            checked: parent.parent.player !== null && parent.parent.player.isPlaying
            implicitWidth: 64
            disabled: !(parent.parent.player && parent.parent.player.canTogglePlaying)
            onClicked: parent.parent.player.togglePlaying()
        }
        IconButton {
            tonal: true
            icon: "skip_next"
            disabled: !(parent.parent.player && parent.parent.player.canGoNext)
            onClicked: parent.parent.player.next()
        }
    }
}
