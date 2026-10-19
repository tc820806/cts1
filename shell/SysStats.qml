pragma Singleton
// System stats from /proc, hwmon, df, nvidia-smi and amdgpu sysfs. Polls only while something shows them (perfRefs > 0).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0
    property real memory: 0
    property real memUsedKib: 0
    property real memTotalKib: 0

    // Real disks only (df -T, whitelisted fs types: no bind mounts, tmpfs or psd overlays).
    property var disks: []                 // [{mount, usedKib, totalKib, freeKib, perc}, ...]
    property string manualPrimaryMount: ""  // "" = auto (root); else a mount from `disks` picked via the card's toggle
    readonly property var primaryDisk: {
        if (disks.length === 0)
            return null;
        if (manualPrimaryMount) {
            const m = disks.find(d => d.mount === manualPrimaryMount);
            if (m)
                return m;
        }
        return disks.find(d => d.mount === "/") || disks[0];
    }

    property int perfRefs: 0
    // Forget the last CPU/network samples while hidden, so the first values after reopening are real readings.
    onPerfRefsChanged: if (perfRefs === 0) {
        _prev = null;
        _prevNet = null;
    }
    property string cpuName: ""
    property real cpuTemp: NaN
    property string gpuName: ""
    property real gpuUsage: NaN      // 0..1
    property real gpuTemp: NaN
    property bool gpuSupported: true     // false once no NVIDIA (nvidia-smi) or AMD (sysfs) GPU was found
    property real downSpeed: 0       // bytes/s
    property real upSpeed: 0
    property var downHist: []
    property var upHist: []
    readonly property int historyLength: 60

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string wm: (Quickshell.env("XDG_CURRENT_DESKTOP") || "wm").toLowerCase()

    function formatKib(kib) {
        const g = kib / 1048576;
        return g >= 1 ? g.toFixed(1) + " GiB" : (kib / 1024).toFixed(0) + " MiB";
    }
    function formatKibUsage(used, total) {
        return formatKib(used) + " / " + formatKib(total);
    }
    function formatBytes(b, perSecond) {
        const u = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0, v = b;
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + u[i] + (perSecond ? "/s" : "");
    }

    property var _prev: null
    property var _prevNet: null

    Timer {
        interval: 2000
        running: root.perfRefs > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
        }
    }
    Timer {
        interval: 30000
        running: root.perfRefs > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: dfProc.running = true
    }

    Timer {
        interval: 1000
        running: root.perfRefs > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netFile.reload();
            if (!tempProc.running)
                tempProc.running = true;
            if (root.gpuSupported && !gpuProc.running)
                gpuProc.running = true;
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = p[3] + (p[4] || 0);
            const total = p.slice(0, 8).reduce((a, b) => a + b, 0);
            if (root._prev) {
                const dt = total - root._prev.total, di = idle - root._prev.idle;
                if (dt > 0)
                    root.cpu = 1 - di / dt;
            }
            root._prev = { total: total, idle: idle };
        }
    }
    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const total = Number((t.match(/MemTotal:\s+(\d+)/) || [])[1]);
            const avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [])[1]);
            if (total > 0) {
                root.memTotalKib = total;
                root.memUsedKib = total - avail;
                root.memory = 1 - avail / total;
            }
        }
    }
    FileView {
        id: cpuInfo
        path: "/proc/cpuinfo"
        onLoaded: {
            const m = text().match(/model name\s*:\s*(.+)/);
            if (m)
                root.cpuName = m[1].trim();
        }
    }
    Component.onCompleted: cpuInfo.reload()

    Process {
        id: dfProc
        command: ["df", "-P", "-k", "-T"]
        stdout: StdioCollector {
            onStreamFinished: {
                const realFs = /^(ext[234]|xfs|btrfs|vfat|exfat|ntfs3?|f2fs|zfs)$/;
                // /boot is real but not a drive to offer.
                const skipMount = /^\/boot(\/|$)/;
                const lines = text.trim().split("\n").slice(1);
                const list = [];
                for (const line of lines) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 7 || !realFs.test(f[1]) || skipMount.test(f[6]))
                        continue;
                    const totalKib = Number(f[2]), usedKib = Number(f[3]);
                    if (!(totalKib > 0))
                        continue;
                    list.push({ mount: f[6], totalKib: totalKib, usedKib: usedKib, freeKib: Number(f[4]), perc: usedKib / totalKib });
                }
                root.disks = list;
            }
        }
    }

    // CPU package temperature: first hwmon named k10temp (AMD) or coretemp (Intel).
    Process {
        id: tempProc
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); if [ \"$n\" = k10temp ] || [ \"$n\" = coretemp ]; then cat $d/temp1_input; break; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Number(text.trim());
                root.cpuTemp = isNaN(v) || text.trim() === "" ? NaN : v / 1000;
            }
        }
    }

    // NVIDIA through nvidia-smi, else the first AMD GPU through sysfs. Anything else (Intel has no root-free usage
    // counter) -> "none": gpuSupported goes false and polling stops.
    Process {
        id: gpuProc
        command: ["sh", "-c",
            "if out=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null) "
            + "&& [ -n \"$out\" ]; then echo \"$out\" | head -n 1; exit; fi; "
            + "for d in /sys/class/drm/card[0-9]*/device; do "
            + "[ -r \"$d/gpu_busy_percent\" ] || continue; "
            + "t=$(cat \"$d\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1); "
            + "echo \"AMD GPU, $(cat \"$d/gpu_busy_percent\"), ${t:+$((t / 1000))}\"; exit; done; "
            + "echo none"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "none") {
                    root.gpuSupported = false;
                    return;
                }
                const p = text.trim().split("\n")[0].split(",").map(s => s.trim());
                if (p.length >= 3) {
                    root.gpuName = p[0];
                    root.gpuUsage = Number(p[1]) / 100;
                    root.gpuTemp = p[2] === "" ? NaN : Number(p[2]);
                }
            }
        }
    }

    // Physical interfaces only (tunnels would double count).
    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            const lines = text().split("\n").slice(2);
            for (const line of lines) {
                const parts = line.split(":");
                if (parts.length < 2)
                    continue;
                const name = parts[0].trim();
                if (name === "lo" || /^(nordlynx|tun|tap|wg|docker|veth|br-|virbr)/.test(name))
                    continue;
                const f = parts[1].trim().split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now();
            if (root._prevNet) {
                const dt = (now - root._prevNet.t) / 1000;
                if (dt > 0) {
                    root.downSpeed = Math.max(0, (rx - root._prevNet.rx) / dt);
                    root.upSpeed = Math.max(0, (tx - root._prevNet.tx) / dt);
                    const d = root.downHist.concat([root.downSpeed]).slice(-root.historyLength);
                    const u = root.upHist.concat([root.upSpeed]).slice(-root.historyLength);
                    root.downHist = d;
                    root.upHist = u;
                }
            }
            root._prevNet = { rx: rx, tx: tx, t: now };
        }
    }
}
