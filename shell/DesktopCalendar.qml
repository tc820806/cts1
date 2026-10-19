import QtQuick
import QtQuick.Effects

// Desktop month calendar in the desktop clock's style: no background, soft shadow; today in a dot.
Item {
    id: root

    property real calendarScale: 1
    property date today: new Date()
    readonly property var weekdays: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property real cellWidth: 36 * calendarScale
    readonly property real cellHeight: 30 * calendarScale
    // Readable on bright wallpapers: a thin dark outline round every glyph plus a strong shadow.
    readonly property color outlineColour: Qt.rgba(0, 0, 0, 0.85)

    readonly property var days: {
        const year = today.getFullYear(), month = today.getMonth();
        const firstWeekday = new Date(year, month, 1).getDay();
        const previousMonthDays = new Date(year, month, 0).getDate();
        const monthDays = new Date(year, month + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const offset = i - firstWeekday + 1;
            if (offset <= 0)
                cells.push({ dayNumber: previousMonthDays + offset, currentMonth: false, today: false });
            else if (offset > monthDays)
                cells.push({ dayNumber: offset - monthDays, currentMonth: false, today: false });
            else
                cells.push({ dayNumber: offset, currentMonth: true, today: offset === today.getDate() });
        }
        return cells;
    }

    implicitWidth: cellWidth * 7
    implicitHeight: content.implicitHeight

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            if (now.toDateString() !== root.today.toDateString())
                root.today = now;
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: 8 * root.calendarScale

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 1
            shadowBlur: 0.6
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.calendarScale

            Text {
                text: Qt.formatDate(root.today, "MMMM").toUpperCase()
                color: Theme.m3secondary
                font.family: Theme.sans
                style: Text.Outline
                styleColor: root.outlineColour
                font.pointSize: 16 * root.calendarScale
                font.letterSpacing: 4
                font.weight: Font.Bold
            }
            Text {
                text: Qt.formatDate(root.today, "yyyy")
                color: Theme.m3primary
                font.family: Theme.sans
                style: Text.Outline
                styleColor: root.outlineColour
                font.pointSize: 16 * root.calendarScale
                font.letterSpacing: 2
                font.weight: Font.Medium
            }
        }

        Grid {
            columns: 7

            Repeater {
                model: root.weekdays

                delegate: Text {
                    required property string modelData
                    width: root.cellWidth
                    height: root.cellHeight * 0.8
                    text: modelData
                    color: Theme.m3secondary
                    opacity: 0.7
                    font.family: Theme.sans
                    style: Text.Outline
                    styleColor: root.outlineColour
                    font.pointSize: 11 * root.calendarScale
                    font.letterSpacing: 1
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Repeater {
                model: root.days

                delegate: Item {
                    required property var modelData
                    width: root.cellWidth
                    height: root.cellHeight

                    Text {
                        id: dayText
                        anchors.centerIn: parent
                        text: parent.modelData.dayNumber
                        color: Theme.m3secondary
                        opacity: parent.modelData.currentMonth || parent.modelData.today ? 1 : 0.35
                        font.family: Theme.sans
                        style: Text.Outline
                        styleColor: root.outlineColour
                        font.pointSize: 12 * root.calendarScale
                        font.weight: parent.modelData.today ? Font.Bold : Font.Medium
                    }
                    // Centered on the digits' own shape (a lone "4" is lopsided in its box), outlined so it shows on any wallpaper.
                    Rectangle {
                        visible: parent.modelData.today
                        width: 6 * root.calendarScale
                        height: width
                        radius: width / 2
                        x: dayText.x + dayShape.tightBoundingRect.x + dayShape.tightBoundingRect.width / 2 - width / 2
                        y: dayText.y + dayText.baselineOffset + 4 * root.calendarScale
                        color: Theme.m3primary
                        border.width: 1
                        border.color: root.outlineColour
                    }
                    TextMetrics {
                        id: dayShape
                        font: dayText.font
                        text: dayText.text
                    }
                }
            }
        }
    }
}
