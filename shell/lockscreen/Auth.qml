pragma ComponentBehavior: Bound
// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): PAM handling trimmed from modules/lock/Pam.qml.
// PAM password check (Caelestia's Pam.qml stack incl. pam_faillock, minus fingerprint/face) plus the typed buffer.
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs

Scope {
    id: root

    enum State {
        None,
        Error,
        MaxTries,
        Failed
    }

    property string buffer: ""
    property int state: Auth.None
    property string lockMessage: ""
    readonly property alias passwd: passwd

    signal flashMsg    // a wrong password: shake the field
    signal success     // the password was right

    // An empty password is not an attempt (it would count toward pam_faillock). After "too many attempts" PAM itself
    // refuses until the lockout has passed.
    function submit(): void {
        if (passwd.active || buffer.length === 0)
            return;
        lockMessage = "";       // a new attempt: PAM sends the lock message again if the account is still locked
        passwd.start();
    }

    function handleKey(event: KeyEvent): void {
        if (passwd.active)
            return;
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            submit();
        } else if (event.key === Qt.Key_Backspace) {
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1);
        } else if (event.key === Qt.Key_Escape) {
            buffer = "";
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            buffer += event.text;   // anything except control characters
        }
    }

    function reset(): void {
        buffer = "";
        state = Auth.None;
        lockMessage = "";
        passwd.abort();
    }

    PamContext {
        id: passwd

        config: "passwd"
        configDirectory: Quickshell.shellPath("lockscreen/pam.d")

        // pam_faillock's two messages, shortened to one line that fits under the field.
        onMessageChanged: {
            const left = message.match(/\((\d+) (minute|second)s? left to unlock\)/);
            if (message.startsWith("The account is locked"))
                root.lockMessage = "Locked: too many tries";
            else if (root.lockMessage && left)
                root.lockMessage = "Locked: too many tries (" + left[1] + (left[2] === "minute" ? " min" : " s") + " left)";
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success)
                return root.success();
            root.state = Auth.None;
            if (res === PamResult.Error)
                root.state = Auth.Error;
            else if (res === PamResult.MaxTries)
                root.state = Auth.MaxTries;
            else if (res === PamResult.Failed)
                root.state = Auth.Failed;
            root.flashMsg();
            stateReset.restart();
        }
    }

    Timer {
        id: stateReset

        interval: 4000
        onTriggered: root.state = Auth.None      // the lock message (if any) stays until the next attempt
    }
}
