import QtQuick
import Quickshell
import Quickshell.Io

// Printer toasts. While a print job waits, asks CUPS every 10 s for the printers' alerts (printer-state-reasons) and
// sends a toast for each new one: errors stay until dismissed, warnings and reports time out. CUPS's own reasons
// (cups-*, paused) and the normal connecting step are skipped. An alert toasts again once it clears and comes back.
Scope {
    id: watch

    property var shown: ({})        // "printer reason" -> true for the alerts already toasted

    // Readable names for common alerts; any other shows as its keyword ("door-open" -> "Door open").
    readonly property var names: ({
            "media-empty": "Out of paper",
            "media-needed": "Out of paper",
            "media-low": "Paper low",
            "media-jam": "Paper jam",
            "marker-supply-empty": "Out of ink",
            "marker-supply-low": "Ink low",
            "offline": "Printer offline",
            "timed-out": "Printer not responding"
        })

    function label(reason) {
        const r = reason.replace(/-(error|warning|report)$/, "");
        const name = names[r] ?? r.replace(/-/g, " ");
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // `lpstat -l -p` output: a "printer NAME ..." line, then its tab-indented details with "Alerts: a b c".
    function update(out) {
        const seen = {};
        let printer = "";
        for (const line of out.split("\n")) {
            const p = line.match(/^printer (\S+)/);
            if (p)
                printer = p[1];
            const a = line.match(/^\tAlerts: (.+)/);
            if (!a)
                continue;
            for (const reason of a[1].trim().split(/\s+/)) {
                if (reason === "none" || reason === "paused" || reason === "connecting-to-device" || reason.startsWith("cups-"))
                    continue;
                const key = printer + " " + reason;
                seen[key] = true;
                if (!shown[key])
                    Quickshell.execDetached(["notify-send", "-a", "Printer", "-i", "printer",
                        "-u", reason.endsWith("-error") ? "critical" : "normal", printer, label(reason)]);
            }
        }
        shown = seen;
    }

    // Prints nothing while the queue is empty: alerts only count while a job waits.
    Process {
        id: check
        command: ["sh", "-c", "[ -n \"$(lpstat -o 2>/dev/null)\" ] && LC_ALL=C lpstat -l -p 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: watch.update(text)
        }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: check.running = true
    }
}
