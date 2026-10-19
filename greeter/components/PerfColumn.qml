import QtQuick
import QtQuick.Layouts
import qs

// Greeter hardware monitor: PerfRow's cards stacked (CPU, GPU, RAM, storage, network), colors from Config.
Item {
    id: root

    readonly property var spacing: ({ extraSmall: 4, small: 8, medium: 12 })
    readonly property var fontSize: ({ small: 11, smaller: 12, normal: 13, large: 18 })
    readonly property string sans: "Rubik"
    readonly property string icons: "Material Symbols Rounded"

    // Temperatures, GPU and network are sampled only while shown; the greeter always shows them.
    Component.onCompleted: SysStats.perfRefs += 1
    Component.onDestruction: SysStats.perfRefs -= 1

    function pct(v) {
        return isNaN(v) ? "..." : (v * 100).toFixed(1) + "%";
    }

    component Label: Text {
        color: Config.text
        font.family: root.sans
        font.pixelSize: root.fontSize.normal
        renderType: Text.NativeRendering
    }

    component Icon: Text {
        font.family: root.icons
        font.pixelSize: 24
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component Card: Rectangle {
        clip: true
        color: Config.subComponents
        radius: 6
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 125
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
            font.pixelSize: 18
            color: parent.colour
        }
        Label {
            text: parent.label
            font.pixelSize: root.fontSize.small
            color: Config.textOnSurfaceVariant
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
                implicitSize: 64
                value: isNaN(hero.usage) ? 0 : hero.usage
                Behavior on value {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
                Label {
                    anchors.centerIn: parent
                    text: isNaN(hero.temperature) ? "--°" : Math.round(hero.temperature) + "°"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: hero.temperature > 90 ? Config.error : hero.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

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
                    color: Config.textOnSurfaceVariant
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
                implicitSize: 64
                strokeWidth: 8
                startAngle: -225
                sweepAngle: 270
                fgColour: Config.tertiary
                value: SysStats.memory
                Icon {
                    anchors.centerIn: parent
                    text: "memory_alt"
                    font.pixelSize: 22
                    color: Config.tertiary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: "Memory"
                    font.pixelSize: root.fontSize.large
                    font.weight: Font.Medium
                }
                Label {
                    text: root.pct(SysStats.memory) + " used"
                    font.pixelSize: root.fontSize.small
                    color: Config.tertiary
                }
                Label {
                    Layout.fillWidth: true
                    text: SysStats.formatKibUsage(SysStats.memUsedKib, SysStats.memTotalKib)
                    font.pixelSize: root.fontSize.smaller
                    color: Config.textOnSurfaceVariant
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
                    implicitSize: 56
                    strokeWidth: 7
                    startAngle: -225
                    sweepAngle: 270
                    fgColour: Config.secondary
                    value: stor.primary ? stor.primary.perc : 0
                    Icon {
                        anchors.centerIn: parent
                        text: "hard_drive"
                        font.pixelSize: 18
                        color: Config.secondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: "Storage"
                        font.pixelSize: root.fontSize.large
                        font.weight: Font.Medium
                    }
                    Label {
                        text: stor.primary ? root.pct(stor.primary.perc) + " used" : "No disks"
                        font.pixelSize: root.fontSize.small
                        color: Config.secondary
                    }
                    Label {
                        Layout.fillWidth: true
                        text: stor.primary ? SysStats.formatKibUsage(stor.primary.usedKib, stor.primary.totalKib) : ""
                        font.pixelSize: root.fontSize.smaller
                        color: Config.textOnSurfaceVariant
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
                        radius: 6
                        color: active ? Config.secondary : (diskArea.containsMouse ? Config.surfaceContainerHighest : Config.surfaceContainerHigh)

                        Label {
                            id: diskLabel
                            anchors.centerIn: parent
                            text: diskChip.modelData.mount === "/" ? "os" : diskChip.modelData.mount.split("/").pop()
                            font.pixelSize: root.fontSize.small
                            color: diskChip.active ? Config.textOnSecondary : Config.textOnSurfaceVariant
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
                    font.pixelSize: 22
                    color: Config.m3primary
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
                    line1Color: Config.secondary
                    line2Color: Config.tertiary
                    maxValue: net.smoothMax
                    historyLength: SysStats.historyLength
                }
                Label {
                    anchors.centerIn: parent
                    text: "Collecting data..."
                    font.pixelSize: root.fontSize.small
                    color: Config.outline
                    visible: SysStats.downHist.length < 2
                }
            }

            StatRow { icon: "download"; label: "Down"; value: SysStats.formatBytes(SysStats.downSpeed, true); colour: Config.tertiary }
            StatRow { icon: "upload"; label: "Up"; value: SysStats.formatBytes(SysStats.upSpeed, true); colour: Config.secondary }
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
            accent: Config.m3primary
        }
        HeroCard {
            label: "GPU"
            subLabel: SysStats.gpuName || (SysStats.gpuSupported ? "Detecting GPU..." : "GPU stats not supported")
            usage: SysStats.gpuUsage
            temperature: SysStats.gpuTemp
            accent: Config.secondary
        }
        MemoryCard {}
        StorageCard {}
        NetworkCard {
            Layout.preferredHeight: 160
        }
    }
}
