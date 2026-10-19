import QtQuick
import QtQuick.Layouts

// Performance popup cards: CPU, GPU, network, memory side by side.
Item {
    id: root

    // Heavier polling (temps, GPU, network) only while true.
    property bool active: false
    property bool _counted: false
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (_counted)
            SysStats.perfRefs--;
    }
    function sync() {
        if (active && !_counted) {
            SysStats.perfRefs++;
            _counted = true;
        } else if (!active && _counted) {
            SysStats.perfRefs--;
            _counted = false;
        }
    }

    function pct(v) {
        return isNaN(v) ? "..." : (v * 100).toFixed(1) + "%";
    }

    component Card: Rectangle {
        clip: true
        color: Theme.m3surfaceContainer
        radius: 6
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 100
        Layout.preferredHeight: 100
    }

    component StatRow: RowLayout {
        property string icon
        property string label
        property string value
        property color colour
        Layout.fillWidth: true
        spacing: Theme.spacing.small

        MaterialIcon {
            text: parent.icon
            font.pixelSize: 18
            color: parent.colour
        }
        StyledText {
            text: parent.label
            font.pixelSize: Theme.fontSize.small
            color: Theme.m3onSurfaceVariant
        }
        Item { Layout.fillWidth: true }
        StyledText {
            text: parent.value
            font.pixelSize: Theme.fontSize.smaller
            font.weight: Font.Medium
            color: parent.colour
        }
    }

    component HeroCard: Card {
        id: hero
        property string icon
        property string label
        property string subLabel
        property color accent
        property real usage
        property real temperature

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding.medium
            spacing: Theme.spacing.medium

            CircularProgress {
                fgColour: hero.accent
                strokeWidth: Theme.padding.extraSmall
                implicitSize: 64
                value: isNaN(hero.usage) ? 0 : hero.usage
                Behavior on value {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
                StyledText {
                    anchors.centerIn: parent
                    text: isNaN(hero.temperature) ? "--°" : Math.round(hero.temperature) + "°"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: hero.temperature > 90 ? Theme.m3error : hero.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: hero.label
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Font.Medium
                    color: hero.accent
                }
                StyledText {
                    Layout.fillWidth: true
                    text: hero.subLabel
                    font.pixelSize: Theme.fontSize.small
                    color: Theme.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
                StyledText {
                    text: root.pct(hero.usage) + " usage"
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Font.Medium
                    color: hero.accent
                }
            }
        }
    }

    component MemoryCard: Card {
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding.medium
            spacing: Theme.spacing.medium

            CircularProgress {
                implicitSize: 64
                strokeWidth: 8
                startAngle: -225
                sweepAngle: 270
                fgColour: Theme.m3tertiary
                value: SysStats.memory
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "memory_alt"
                    font.pixelSize: 22
                    color: Theme.m3tertiary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    text: "Memory"
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Font.Medium
                }
                StyledText {
                    text: root.pct(SysStats.memory) + " used"
                    font.pixelSize: Theme.fontSize.small
                    color: Theme.m3tertiary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: SysStats.formatKibUsage(SysStats.memUsedKib, SysStats.memTotalKib)
                    font.pixelSize: Theme.fontSize.smaller
                    color: Theme.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    component NetworkCard: Card {
        id: net

        property real targetMax: Math.max(1024, Math.max.apply(null, SysStats.downHist.concat(SysStats.upHist).concat([0])))
        property real smoothMax: targetMax
        Behavior on smoothMax {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding.medium
            spacing: Theme.spacing.extraSmall

            RowLayout {
                spacing: Theme.spacing.small
                MaterialIcon {
                    text: "swap_vert"
                    font.pixelSize: 22
                    color: Theme.m3primary
                }
                StyledText {
                    text: "Network"
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Font.Medium
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Sparkline {
                    anchors.fill: parent
                    line1: SysStats.upHist
                    line2: SysStats.downHist
                    line1Color: Theme.m3secondary
                    line2Color: Theme.m3tertiary
                    maxValue: net.smoothMax
                    historyLength: SysStats.historyLength
                }
                StyledText {
                    anchors.centerIn: parent
                    text: "Collecting data..."
                    font.pixelSize: Theme.fontSize.small
                    color: Theme.m3outline
                    visible: SysStats.downHist.length < 2
                }
            }

            StatRow { icon: "download"; label: "Down"; value: SysStats.formatBytes(SysStats.downSpeed, true); colour: Theme.m3tertiary }
            StatRow { icon: "upload"; label: "Up"; value: SysStats.formatBytes(SysStats.upSpeed, true); colour: Theme.m3secondary }
        }
    }

    component StorageCard: Card {
        id: stor
        readonly property var primary: SysStats.primaryDisk

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding.medium
            spacing: Theme.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacing.medium

                CircularProgress {
                    implicitSize: 56
                    strokeWidth: 7
                    startAngle: -225
                    sweepAngle: 270
                    fgColour: Theme.m3secondary
                    value: stor.primary ? stor.primary.perc : 0
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "hard_drive"
                        font.pixelSize: 18
                        color: Theme.m3secondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        text: "Storage"
                        font.pixelSize: Theme.fontSize.large
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: stor.primary ? root.pct(stor.primary.perc) + " used" : "No disks"
                        font.pixelSize: Theme.fontSize.small
                        color: Theme.m3secondary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: stor.primary ? SysStats.formatKibUsage(stor.primary.usedKib, stor.primary.totalKib) : ""
                        font.pixelSize: Theme.fontSize.smaller
                        color: Theme.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            // One pill per mounted disk: click to show that disk.
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacing.extraSmall
                visible: SysStats.disks.length > 1

                Repeater {
                    model: SysStats.disks

                    Rectangle {
                        id: diskChip
                        required property var modelData
                        readonly property bool active: stor.primary && modelData.mount === stor.primary.mount
                        implicitWidth: diskLabel.implicitWidth + Theme.padding.medium
                        implicitHeight: diskLabel.implicitHeight + Theme.padding.extraSmall
                        radius: 6
                        color: active ? Theme.m3secondary : (diskArea.containsMouse ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh)

                        StyledText {
                            id: diskLabel
                            anchors.centerIn: parent
                            text: diskChip.modelData.mount === "/" ? "os" : diskChip.modelData.mount.split("/").pop()
                            font.pixelSize: Theme.fontSize.small
                            color: diskChip.active ? Theme.m3onSecondary : Theme.m3onSurfaceVariant
                        }
                        MouseArea {
                            id: diskArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SysStats.manualPrimaryMount = diskChip.modelData.mount
                        }
                    }
                }
            }
        }
    }

    readonly property real cardRowHeight: 125
    implicitHeight: cardRowHeight * 2 + Theme.spacing.medium

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.cardRowHeight
            spacing: Theme.spacing.medium

            HeroCard {
                icon: "memory"
                label: "CPU"
                subLabel: SysStats.cpuName
                usage: SysStats.cpu
                temperature: SysStats.cpuTemp
                accent: Theme.m3primary
            }
            HeroCard {
                icon: "desktop_windows"
                label: "GPU"
                subLabel: SysStats.gpuName || (SysStats.gpuSupported ? "Detecting GPU..." : "GPU stats not supported")
                usage: SysStats.gpuUsage
                temperature: SysStats.gpuTemp
                accent: Theme.m3secondary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.cardRowHeight
            spacing: Theme.spacing.medium

            StorageCard {}
            NetworkCard {}
            MemoryCard {}
        }
    }
}
