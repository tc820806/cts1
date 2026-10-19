import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Desktop layer (above the wallpaper, below windows, click-through): visualizer along the bottom, calendar top
// right, clock bottom right. The visualizer hides (and stops cava) while the visible workspace has a fullscreen window.
PanelWindow {
    id: desktop

    readonly property real widgetInset: 32
    property bool covered: false

    color: "transparent"
    mask: Region {}
    // Normal, not Ignore: beside the taskbar, not under it.
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "cts1-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    DesktopVisualizer {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        covered: desktop.covered
    }

    DesktopCalendar {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: desktop.widgetInset
        // Right edge in line with the clock's text below (the clock has 32 px of padding)
        anchors.rightMargin: desktop.widgetInset + 16 * 2
        // Wider than at scale 1 (252 -> 307 px), for easier reading.
        calendarScale: 1.22
        width: implicitWidth
        height: implicitHeight
    }
    DesktopClock {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: desktop.widgetInset
        anchors.bottomMargin: desktop.widgetInset
        width: implicitWidth
        height: implicitHeight
    }

    // Covered? Re-read sway's tree on every window / workspace / output change.
    Process {
        id: events
        running: true
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"window\", \"workspace\", \"output\"]"]
        stdout: SplitParser {
            onRead: treeDelay.restart()
        }
        // swaymsg exits when sway reloads: subscribe again.
        onExited: resubscribe.restart()
        onStarted: treeDelay.restart()
    }
    Timer {
        id: resubscribe
        interval: 2000
        onTriggered: events.running = true
    }
    // A burst of events needs one read.
    Timer {
        id: treeDelay
        interval: 50
        onTriggered: tree.running = true
    }
    Process {
        id: tree
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    desktop.covered = desktop.coveredIn(JSON.parse(text));
                } catch (e) {
                    desktop.covered = false;
                }
            }
        }
    }

    function coveredIn(root) {
        const outputName = desktop.screen ? desktop.screen.name : "";
        const output = root.nodes.find(o => o.type === "output" && o.name === outputName);
        if (!output)
            return false;
        const ws = output.nodes.find(w => w.name === output.current_workspace);
        if (!ws)
            return false;
        const hasFullscreen = node => (node.fullscreen_mode ?? 0) > 0
            || node.nodes.some(hasFullscreen) || (node.floating_nodes ?? []).some(hasFullscreen);
        return ws.nodes.some(hasFullscreen) || (ws.floating_nodes ?? []).some(hasFullscreen);
    }
}
