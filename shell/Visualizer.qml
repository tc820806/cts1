import QtQuick

// Radial bars around the media cover: low frequencies at the top, mirrored left/right, growing out from innerRadius
// by up to depth. Size it to innerRadius + depth + barWidth around its center.
Item {
    id: vis

    // cava only runs while an active, visible one exists.
    property bool active: true
    property real innerRadius: 50
    property real depth: 12
    property real barWidth: 3
    property color colour: Theme.m3primary

    property bool counted: false
    function sync() {
        const want = active && visible;
        if (want !== counted) {
            Cava.users += want ? 1 : -1;
            counted = want;
        }
    }
    onActiveChanged: sync()
    onVisibleChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Cava.users -= 1

    Connections {
        target: Cava
        function onValuesChanged() { canvas.requestPaint() }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const values = Cava.values;
            const n = values.length;
            if (n === 0)
                return;
            const cx = width / 2, cy = height / 2;
            const r0 = vis.innerRadius + vis.barWidth / 2;
            ctx.lineWidth = vis.barWidth;
            ctx.lineCap = "round";
            ctx.strokeStyle = vis.colour;
            ctx.beginPath();
            for (let i = 0; i < n; i++) {
                const len = Math.max(0, Math.min(1, values[i])) * vis.depth;
                if (len < 0.5)
                    continue;
                // Half a step off the top so the two sides meet without overlapping
                const step = Math.PI / n * (i + 0.5);
                for (const a of [-Math.PI / 2 + step, -Math.PI / 2 - step]) {
                    const c = Math.cos(a), s = Math.sin(a);
                    ctx.moveTo(cx + c * r0, cy + s * r0);
                    ctx.lineTo(cx + c * (r0 + len), cy + s * (r0 + len));
                }
            }
            ctx.stroke();
        }
    }
}
