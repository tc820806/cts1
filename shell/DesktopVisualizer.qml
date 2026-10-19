// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): desktop visualiser (bar layout,
// colours, smoothing) from modules/background/Visualiser.qml, as ported to CTS2's KDE version.
import QtQuick

// Desktop audio bars: two mirrored halves rising from the bottom, bass in the middle (Caelestia leaves a gap there),
// up to 40% of the height. Fades out (and stops cava) while `covered`.
Item {
    id: root

    property bool covered: false
    property real spacing: 4
    property real rounding: 12
    // Caelestia: tau = animation duration / 3
    property real smoothingMs: 400 / 3

    readonly property bool shouldBeActive: !covered

    readonly property int count: DesktopCava.barCount
    property var displayValues: Array(count).fill(0)
    property bool settled: true

    readonly property real maxBarHeight: height * 0.4
    readonly property real sideWidth: width * 0.5
    readonly property real slotWidth: sideWidth / count
    readonly property real barWidth: Math.max(0, slotWidth - spacing)

    // Caelestia's roles: the accent and the accent 45% of the way to black, both at 70%
    readonly property color primaryColour: Qt.rgba(Theme.m3primary.r, Theme.m3primary.g, Theme.m3primary.b, 0.7)
    readonly property color secondaryColour: Qt.rgba(Theme.m3primary.r * 0.55, Theme.m3primary.g * 0.55,
                                                    Theme.m3primary.b * 0.55, 0.7)

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    opacity: shouldBeActive ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: 140; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1] }
    }

    Binding {
        target: DesktopCava
        property: "active"
        value: root.shouldBeActive
    }

    Connections {
        target: DesktopCava
        function onValuesChanged() { root.settled = false; }
    }

    FrameAnimation {
        running: root.visible && !root.settled
        onTriggered: {
            const target = DesktopCava.values;
            const alpha = 1 - Math.exp(-frameTime * 1000 / root.smoothingMs);
            const next = root.displayValues.slice();
            let allSettled = true;
            for (let i = 0; i < root.count; i++) {
                const goal = target[i] ?? 0;
                const diff = goal - next[i];
                if (Math.abs(diff) > 0.001) {
                    next[i] += diff * alpha;
                    allSettled = false;
                } else {
                    next[i] = goal;
                }
            }
            root.displayValues = next;
            root.settled = allSettled;
        }
    }

    // Caelestia paints one gradient over the bottom 40%; here each bar gets its slice, so its top color follows its height.
    Item {
        id: drawArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.maxBarHeight

        Repeater {
            model: root.count * 2

            delegate: Rectangle {
                required property int index
                readonly property bool rightSide: index >= root.count
                readonly property int slot: rightSide ? index - root.count : index
                readonly property int valueIndex: rightSide ? slot : root.count - slot - 1
                readonly property real value: Math.max(0, Math.min(1, root.displayValues[valueIndex] ?? 0))
                readonly property real barHeight: value * root.maxBarHeight

                x: slot * root.slotWidth + (rightSide ? root.width - root.sideWidth : 0)
                y: drawArea.height - barHeight
                width: root.barWidth
                height: barHeight
                visible: barHeight > 0.5
                topLeftRadius: Math.min(root.rounding, width / 2, barHeight)
                topRightRadius: topLeftRadius
                antialiasing: true

                gradient: Gradient {
                    GradientStop { position: 0; color: root.mix(root.secondaryColour, root.primaryColour, value) }
                    GradientStop { position: 1; color: root.secondaryColour }
                }
            }
        }
    }
}
