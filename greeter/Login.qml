pragma Singleton
// What the SDDM theme got from SDDM (users, sessions, login, power), through greetd; remembers user and session.
// $CTS1_GREETER_TEST_CMD (testing): run this instead of the session after a correct password. Without greetd
// (GREETD_SOCK unset, a preview window) every login fails and the power buttons only log.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Singleton {
    id: root

    signal loginFailed(string message)
    signal loginSucceeded

    readonly property bool live: Greetd.available
    readonly property string testCmd: Quickshell.env("CTS1_GREETER_TEST_CMD") || ""
    readonly property ListModel users: ListModel {}
    // Wayland sessions only (no X).
    readonly property ListModel sessions: ListModel {}
    property bool sessionsLoaded: false
    readonly property int lastUserIndex: indexOf(users, saved.lastUser)
    readonly property int lastSessionIndex: indexOf(sessions, saved.lastSession)

    // From login() until greetd answers; greetd errors outside that are only logged.
    property bool busy: false
    property string pendingPassword: ""
    property var pendingSession: null
    property string pendingUser: ""

    function indexOf(model, name) {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).name === name)
                return i;
        return 0;
    }

    function login(user, password, sessionIndex) {
        const session = sessionIndex >= 0 && sessionIndex < sessions.count ? sessions.get(sessionIndex) : null;
        if (!root.live) {
            console.log("greeter: no greetd (preview) - login for", user, "into", session ? session.name : "?", "not sent");
            Qt.callLater(() => root.loginFailed("preview"));
            return;
        }
        if (!session || user === "") {
            Qt.callLater(() => root.loginFailed("no user or session"));
            return;
        }
        root.busy = true;
        root.pendingUser = user;
        root.pendingPassword = password;
        root.pendingSession = {
            name: session.name,
            exec: session.exec,
            desktopNames: session.desktopNames
        };
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        Greetd.createSession(user);
    }

    function powerOff() {
        power(["systemctl", "poweroff"]);
    }

    function reboot() {
        power(["systemctl", "reboot"]);
    }

    function rebootToFirmware() {
        power(["systemctl", "reboot", "--firmware-setup"]);
    }

    function power(cmd) {
        if (!root.live) {
            console.log("greeter: preview, not running", cmd.join(" "));
            return;
        }
        Quickshell.execDetached(cmd);
    }

    function fail(message) {
        root.busy = false;
        root.pendingPassword = "";
        root.loginFailed(message);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            // The first prompt is the password; anything PAM asks after that gets an empty answer.
            if (responseRequired) {
                Greetd.respond(root.pendingPassword);
                root.pendingPassword = "";
            }
        }

        function onAuthFailure(message) {
            root.fail(message);
        }

        // Quickshell sends a cancel after a rejected password, which greetd answers with an error: only errors during an
        // attempt count.
        function onError(error) {
            if (!root.busy)
                return;
            console.warn("greeter: greetd error:", error);
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
            root.fail(error);
        }

        function onReadyToLaunch() {
            const s = root.pendingSession;
            saved.lastUser = root.pendingUser;
            saved.lastSession = s.name;
            stateFile.writeAdapter();
            const desktop = s.desktopNames.split(";")[0];
            // greetd runs `sh -c "<profile>; exec <command>"`, so one string goes and the shell splits the Exec line. Output goes
            // to the journal (cts1-session), not the VT, where it would flash before the session draws.
            Greetd.launch(["systemd-cat --identifier=cts1-session -- " + (root.testCmd || s.exec)], ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + desktop, "XDG_CURRENT_DESKTOP=" + s.desktopNames.replace(/;$/, "").replace(/;/g, ":")], true);
            root.busy = false;
            root.loginSucceeded();
        }
    }

    // uid 1000-59999 with a login shell.
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            root.users.clear();
            for (const line of text().split("\n")) {
                const f = line.split(":");
                const uid = parseInt(f[2]);
                if (f.length < 7 || uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6]))
                    continue;
                root.users.append({
                    name: f[0],
                    realName: f[4].split(",")[0],
                    home: f[5]
                });
            }
        }
    }

    // Name<TAB>Exec<TAB>DesktopNames; Hidden/NoDisplay and missing-TryExec entries skipped, as display managers do.
    Process {
        running: true
        command: ["sh", "-c", `
            for f in /usr/share/wayland-sessions/*.desktop; do
                [ -f "$f" ] || continue
                awk -F= '
                    /^\\[/ { main = ($0 == "[Desktop Entry]"); next }
                    !main { next }
                    $1 == "Name" && name == "" { name = substr($0, 6) }
                    $1 == "Exec" { exec = substr($0, 6) }
                    $1 == "TryExec" { tryexec = substr($0, 9) }
                    $1 == "DesktopNames" { dn = substr($0, 14) }
                    ($1 == "Hidden" || $1 == "NoDisplay") && $2 == "true" { skip = 1 }
                    END {
                        if (skip || exec == "") exit
                        if (tryexec != "" && system("command -v \\"" tryexec "\\" >/dev/null 2>&1") != 0) exit
                        if (dn == "") dn = name
                        print name "\\t" exec "\\t" dn
                    }' "$f"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessions.clear();
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length === 3)
                        root.sessions.append({
                            name: f[0],
                            exec: f[1],
                            desktopNames: f[2]
                        });
                }
                root.sessionsLoaded = true;
            }
        }
    }

    // $CTS1_GREETER_STATE, else ~/cts1-greeter.json in the greeter user's home.
    FileView {
        id: stateFile

        path: Quickshell.env("CTS1_GREETER_STATE") || Quickshell.env("HOME") + "/cts1-greeter.json"
        printErrors: false

        JsonAdapter {
            id: saved

            property string lastUser: ""
            property string lastSession: ""
        }
    }
}
