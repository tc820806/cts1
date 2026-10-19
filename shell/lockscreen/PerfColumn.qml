import QtQuick
import QtQuick.Layouts
import qs

// Lock screen hardware monitor: PerfRow's cards stacked (CPU, GPU, RAM, storage, network), sizes scaled by `ui`.
Item {
    id: root

    property real ui: 1

    readonly property var spacing: ({ extraSmall: 4 * ui, small: 8 * ui, medium: 12 * ui })
    readonly property var fontSize: ({ small: 11 * ui, smaller: 12 * ui, normal: 13 * ui, large: 18 * ui })
    readonly property string sans: Theme.sans
    readonly property string icons: Theme.icons

    // Temperatures, GPU and network are sampled only while shown; the lock screen always shows them.
    Component.onCompleted: SysStats.perfRefs += 1
    Component.onDestruction: SysStats.perfRefs -= 1

    function pct(v) {
        return isNaN(v) ? "..." : (v * 100).toFixed(1) + "%";
    }

    component Label: Text {
        color: Theme.m3onSurface
        font.family: root.sans
        font.pixelSize: root.fontSize.normal
        renderType: Text.NativeRendering
    }

    component Icon: Text {
        font.family: root.icons
        font.pixelSize: 24 * root.ui
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component Card: Rectangle {
        clip: true
        color: Theme.m3surfaceContainer
        radius: 6 * root.ui
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 125 * root.ui
    }

    component StatRow: RowLayout {
        property string icon
        property string label
        property string value
        property color colour
        Layout.fillWidth: true
        spacing: root.spacing.small

        Icon {
            text: parent.icon
            font.pixelSize: 18 * root.ui
            color: parent.colour
        }
        Label {
            text: parent.label
            font.pixelSize: root.fontSize.small
            color: Theme.m3onSurfaceVariant
        }
        Item { Layout.fillWidth: true }
        Label {
            text: parent.value
            font.pixelSize: root.fontSize.smaller
            font.weight: Font.Medium
            color: parent.colour
        }
    }

    component HeroCard: Card {
        id: hero
        property string label
        property string subLabel
        property color accent
        property real usage
        property real temperature

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.spacing.medium
            spacing: root.spacing.medium

            CircularProgress {
                fgColour: hero.accent
                strokeWidth: root.spacing.extraSmall
                implicitSize: 64 * root.ui
                value: isNaN(hero.usage) ? 0 : hero.usage
                Behavior on value {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
                Label {
                    anchors.centerIn: parent
                    text: isNaN(hero.temperature) ? "--°" : Math.round(hero.temperature) + "°"
                    font.pixelSize: 18 * root.ui
                    font.weight: Font.Medium
                    color: hero.temperature > 90 ? Theme.m3error : hero.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.ui

                Label {
                    text: hero.label
                    font.pixelSize: root.fontSize.large
                    font.weight: Font.Medium
                    color: hero.accent
                }
                Label {
                    Layout.fillWidth: true
                    text: hero.subLabel
                    font.pixelSize: root.fontSize.small
                    color: Theme.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
                Label {
                    text: root.pct(hero.usage) + " usage"
                    font.pixelSize: root.fontSize.large
                    font.weight: Font.Medium
                    color: hero.accent
                }
            }
        }
    }

    component MemoryCard: Card {
        RowLayout {
            anchors.fill: parent
            anchors.margins: root.spacing.medium
            spacing: root.spacing.medium

            CircularProgress {
                implicitSize: 64 * root.ui
                strokeWidth: 8 * root.ui
                startAngle: -225
                sweepAngle: 270
                fgColour: Theme.m3tertiary
                value: SysStats.memory
                Icon {
                    anchors.centerIn: parent
                    text: "memory_alt"
                    font.pixelSize: 22 * root.ui
                    color: Theme.m3tertiary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.ui
                Label {
                    text: "Memory"
                    font.pixelSize: root.fontSize.large
                    font.weight: Font.Medium
                }
                Label {
                    text: root.pct(SysStats.memory) + " used"
                    font.pixelSize: root.fontSize.small
                    color: Theme.m3tertiary
                }
                Label {
                    Layout.fillWidth: true
                    text: SysStats.formatKibUsage(SysStats.memUsedKib, SysStats.memTotalKib)
                    font.pixelSize: root.fontSize.smaller
                    color: Theme.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    component StorageCard: Card {
        id: stor
        readonly property var primary: SysStats.primaryDisk

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.spacing.medium
            spacing: root.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.spacing.medium

                CircularProgress {
                    implicitSize: 56 * root.ui
                    strokeWidth: 7 * root.ui
                    startAngle: -225
                    sweepAngle: 270
                    fgColour: Theme.m3secondary
                    value: stor.primary ? stor.primary.perc : 0
                    Icon {
                        anchors.centerIn: parent
                        text: "hard_drive"
                        font.pixelSize: 18 * root.ui
                        color: Theme.m3secondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2 * root.ui
                    Label {
                        text: "Storage"
                        font.pixelSize: root.fontSize.large
                        font.weight: Font.Medium
                    }
                    Label {
                        text: stor.primary ? root.pct(stor.primary.perc) + " used" : "No disks"
                        font.pixelSize: root.fontSize.small
                        color: Theme.m3secondary
                    }
                    Label {
                        Layout.fillWidth: true
                        text: stor.primary ? SysStats.formatKibUsage(stor.primary.usedKib, stor.primary.totalKib) : ""
                        font.pixelSize: root.fontSize.smaller
                        color: Theme.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.spacing.extraSmall
                visible: SysStats.disks.length > 1

                Repeater {
                    model: SysStats.disks

                    Rectangle {
                        id: diskChip
                        required property var modelData
                        readonly property bool active: stor.primary && modelData.mount === stor.primary.mount
                        implicitWidth: diskLabel.implicitWidth + root.spacing.medium
                        implicitHeight: diskLabel.implicitHeight + root.spacing.extraSmall
                        radius: 6 * root.ui
                        color: active ? Theme.m3secondary : (diskArea.containsMouse ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh)

                        Label {
                            id: diskLabel
                            anchors.centerIn: parent
                            text: diskChip.modelData.mount === "/" ? "os" : diskChip.modelData.mount.split("/").pop()
                            font.pixelSize: root.fontSize.small
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

    component NetworkCard: Card {
        id: net

        property real targetMax: Math.max(1024, Math.max.apply(null, SysStats.downHist.concat(SysStats.upHist).concat([0])))
        property real smoothMax: targetMax
        Behavior on smoothMax {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.spacing.medium
            spacing: root.spacing.extraSmall

            RowLayout {
                spacing: root.spacing.small
                Icon {
                    text: "swap_vert"
                    font.pixelSize: 22 * root.ui
                    color: Theme.m3primary
                }
                Label {
                    text: "Network"
                    font.pixelSize: root.fontSize.large
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
                Label {
                    anchors.centerIn: parent
                    text: "Collecting data..."
                    font.pixelSize: root.fontSize.small
                    color: Theme.m3outline
                    visible: SysStats.downHist.length < 2
                }
            }

            StatRow { icon: "download"; label: "Down"; value: SysStats.formatBytes(SysStats.downSpeed, true); colour: Theme.m3tertiary }
            StatRow { icon: "upload"; label: "Up"; value: SysStats.formatBytes(SysStats.upSpeed, true); colour: Theme.m3secondary }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.spacing.medium

        HeroCard {
            label: "CPU"
            subLabel: SysStats.cpuName
            usage: SysStats.cpu
            temperature: SysStats.cpuTemp
            accent: Theme.m3primary
        }
        HeroCard {
            label: "GPU"
            subLabel: SysStats.gpuName || (SysStats.gpuSupported ? "Detecting GPU..." : "GPU stats not supported")
            usage: SysStats.gpuUsage
            temperature: SysStats.gpuTemp
            accent: Theme.m3secondary
        }
        MemoryCard {}
        StorageCard {}
        NetworkCard {
            Layout.preferredHeight: 160 * root.ui
        }
    }
}
