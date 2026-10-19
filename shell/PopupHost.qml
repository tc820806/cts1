// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): one-window popup design modeled on modules/drawers/ContentWindow.qml.
import QtQuick
import Quickshell
import Quickshell.Wayland

// Like Caelestia's ContentWindow.qml: ONE full-screen transparent window that never resizes; only the box inside
// does (a PopupWindow that changes height while open freezes and gets clipped). Clicks pass through outside the box.
// One popup at a time (`current` = its HostPopup name); closes 250 ms after the pointer left the button and the box.
PanelWindow {
    id: host

    property string current: ""
    // The taskbar button: its position and containsMouse.
    property Item button: null
    readonly property bool open: current !== ""
    property real barWidth: 44
    // Set while a popup needs typing (wifi password): the host takes the keyboard and stays open.
    property bool wantsKeyboard: false
    default property alias popups: stack.data

    function toggle(name: string, buttonArea: Item): void {
        if (current === name) {
            close();
            return;
        }
        button = buttonArea;
        centerY = buttonArea.mapToItem(null, 0, buttonArea.height / 2).y;
        current = name;
    }
    // No toggling: for the hover popups (volume, notifications).
    function show(name: string, buttonArea: Item): void {
        if (current === name)
            return;
        button = buttonArea;
        centerY = buttonArea.mapToItem(null, 0, buttonArea.height / 2).y;
        current = name;
    }
    function close(): void {
        current = "";
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open && wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        x: box.x
        y: box.y
        width: host.open ? box.width : 0
        height: host.open ? box.height : 0
    }

    property real centerY: 0

    // Kept after closing so the box fades out at its last size.
    property Item shown: null
    onCurrentChanged: {
        if (current === "")
            return;
        for (const p of stack.children) {
            // Compare names, not p.visible: an item reads as invisible while the box is hidden.
            const isCurrent = p.name === current;
            p.visible = isCurrent;
            if (isCurrent)
                shown = p;
        }
    }

    readonly property bool hovered: open && (wantsKeyboard || (button && button.containsMouse) || boxHover.hovered)
    onHoveredChanged: hovered ? closeTimer.stop() : closeTimer.restart()
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: host.close()
    }

    Rectangle {
        id: box

        readonly property real margin: 7
        readonly property real targetW: host.shown ? host.shown.implicitWidth + 28 : 0
        readonly property real targetH: host.shown ? host.shown.implicitHeight + 28 : 0

        x: host.barWidth + 4
        y: Math.max(margin, Math.min(host.height - height - margin, host.centerY - height / 2))
        width: targetW
        height: targetH
        radius: 12
        color: Theme.m3surface
        border.color: Theme.m3outlineVariant
        border.width: 1
        clip: true
        opacity: host.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        Behavior on width {
            enabled: host.open && box.opacity > 0.99
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: host.open && box.opacity > 0.99
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: host.open && box.opacity > 0.99
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        HoverHandler { id: boxHover }

        Item {
            id: stack
            x: 14
            y: 14
            width: box.width - 28
            height: box.height - 28
        }
    }
}
