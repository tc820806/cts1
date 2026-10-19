import QtQuick
import qs

// Copy of shell/Sparkline.qml, colors from Config.
Canvas {
    id: c

    property var line1: []
    property var line2: []
    property color line1Color: Config.secondary
    property color line2Color: Config.tertiary
    property real maxValue: 1024
    property int historyLength: 60

    onLine1Changed: requestPaint()
    onLine2Changed: requestPaint()
    onMaxValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function draw(ctx, data, colour, fillAlpha) {
        if (data.length < 2)
            return;
        const step = width / (historyLength - 1);
        const x0 = width - (data.length - 1) * step;
        const y = v => height - Math.min(1, v / maxValue) * (height - 4) - 2;
        ctx.beginPath();
        ctx.moveTo(x0, y(data[0]));
        for (let i = 1; i < data.length; i++)
            ctx.lineTo(x0 + i * step, y(data[i]));
        ctx.strokeStyle = colour;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.stroke();
        ctx.lineTo(width, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        ctx.globalAlpha = fillAlpha;
        ctx.fillStyle = colour;
        ctx.fill();
        ctx.globalAlpha = 1;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        draw(ctx, line1, line1Color, 0.15);
        draw(ctx, line2, line2Color, 0.2);
    }
}
