import QtQuick
import Quickshell
import Quickshell.Io

// One timer (no visuals). Phases: idle, running, paused, done. Done = a critical notification (a click opens the
// window) + the bell pattern 5x; reset or a new start stops both.
Item {
    id: slot

    property int index: 0
    property string label: ""
    property int duration: 0            // ms, set while idle
    property string phase: "idle"
    property real endsAt: 0             // epoch ms, while running
    property int remaining: 0           // ms, while paused
    property real now: Date.now()       // ticked by the window while something runs
    property int notifId: 0

    signal openRequested()
    signal edited()

    readonly property int timeLeft: phase === "running" ? Math.max(0, endsAt - now) : phase === "paused" ? remaining
        : phase === "done" ? 0 : duration
    readonly property string name: label.trim() !== "" ? label.trim() : "Timer " + (index + 1)

    function start(): void {
        if (phase === "running" || duration <= 0 && phase === "idle")
            return;
        stopRinging();
        const ms = phase === "paused" ? remaining : duration;
        endsAt = Date.now() + ms;
        phase = "running";
        edited();
    }
    function pause(): void {
        if (phase !== "running")
            return;
        remaining = Math.max(0, endsAt - Date.now());
        phase = "paused";
        edited();
    }
    function reset(): void {
        stopRinging();
        phase = "idle";
        endsAt = 0;
        remaining = 0;
        edited();
    }
    // Called by the window's tick (and after a restore): rings once the time is up.
    function check(t: real): void {
        if (phase === "running" && t >= endsAt)
            ring();
    }
    function ring(): void {
        phase = "done";
        edited();
        bells.running = true;
        notify.running = true;
    }
    function stopRinging(): void {
        bells.running = false;
        if (notify.running && notifId > 0)
            Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                "--object-path", "/org/freedesktop/Notifications", "--method",
                "org.freedesktop.Notifications.CloseNotification", String(notifId)]);
        notifId = 0;
    }

    // mm:ss, or h:mm:ss from an hour up (rounded up, so 0:00 shows only when it has run out).
    function format(ms: int): string {
        const total = Math.ceil(ms / 1000);
        const h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, s = total % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : pad(Math.floor(total / 60)) + ":" + pad(s);
    }

    // A pause is the bell played silently. Each pw-play runs in the background and is waited for, so stopping
    // (SIGTERM to sh) also stops the bell that is playing.
    Process {
        id: bells
        command: ["sh", "-c", "trap 'kill $p 2>/dev/null; exit' TERM; b=/usr/share/sounds/freedesktop/stereo/bell.oga; "
            + "play() { pw-play \"$@\" $b & p=$!; wait $p; }; "
            + "for i in 1 2 3 4 5; do play; play --volume 0; play; play --volume 0; play --volume 0; done"]
    }

    // notify-send prints the notification's id, then "default" when the notification is clicked.
    Process {
        id: notify
        command: ["notify-send", "-a", "Timer", "-i", "alarm", "-u", "critical", "-p", "-A", "default=Open timer",
            slot.name + " is done", "Set for " + slot.format(slot.duration)]
        stdout: SplitParser {
            onRead: line => {
                if (line === "default")
                    slot.openRequested();
                else if (/^\d+$/.test(line))
                    slot.notifId = parseInt(line);
            }
        }
        onExited: slot.notifId = 0
    }
}
