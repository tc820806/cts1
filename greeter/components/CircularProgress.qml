import QtQuick
import qs

// Copy of shell/CircularProgress.qml, colors from Config. Degrees, clockwise from 3 o'clock.
Item {
    id: p

    property real value: 0
    property real strokeWidth: 6
    property real implicitSize: 48
    property real startAngle: -90
    property real sweepAngle: 360
    property color fgColour: Config.m3primary
    property color bgColour: Config.secondaryContainer

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    onValueChanged: canvas.requestPaint()
    onFgColourChanged: canvas.requestPaint()
    onBgColourChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2;
            const r = (Math.min(width, height) - p.strokeWidth) / 2;
            if (r <= 0)
                return;
            const rad = d => d * Math.PI / 180;
            const start = rad(p.startAngle);
            ctx.lineWidth = p.strokeWidth;
            ctx.lineCap = "round";
            ctx.strokeStyle = p.bgColour;
            ctx.beginPath();
            ctx.arc(cx, cy, r, start, start + rad(p.sweepAngle));
            ctx.stroke();
            const v = Math.max(0, Math.min(1, p.value));
            if (v > 0) {
                ctx.strokeStyle = p.fgColour;
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, start + rad(p.sweepAngle * v));
                ctx.stroke();
            }
        }
    }
}
