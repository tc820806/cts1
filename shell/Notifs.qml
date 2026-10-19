pragma Singleton
// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): NotificationServer setup from services/Notifs.qml.
// The notification server (nothing else on sway is one). Keeps its own history (closed and expired ones stay until
// cleared). History + Do Not Disturb survive a shell reload in $XDG_RUNTIME_DIR (RAM: gone after logout/reboot); on a
// reload the server re-sends every open notification, which is matched back to its entry and not toasted again.
// "Clear" closes every notification for good so none can come back.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Newest first. Plain JS snapshots (a live Notification can be destroyed once the server drops it) plus closed/popup.
    property var list: []
    property bool dnd: false   // Do Not Disturb: still recorded in history, just no toast popup
    readonly property int maxToasts: 5
    property int _heldKey: -1   // the toast under the pointer: its time doesn't run out

    // Toast time (ms): what the sender asked for, else 5 s (low urgency) / 8 s; critical stays (0). A sender's "0"
    // gets the default too, so no app can pin a toast.
    function _toastTime(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout > 0)
            return n.expireTimeout;
        return n.urgency === NotificationUrgency.Low ? 5000 : 8000;
    }
    function holdToast(key, on) {
        if (on) {
            _heldKey = key;
            return;
        }
        if (_heldKey !== key)
            return;
        _heldKey = -1;
        const e = _find(key);
        if (e && e.toastUntil > 0)
            e.toastUntil = Date.now() + _toastTime(e);
    }
    Timer {
        interval: 250
        repeat: true
        running: root.popupCount > 0
        onTriggered: {
            const now = Date.now();
            let changed = false;
            for (const n of root.list)
                if (n.popup && !n.closed && n.toastUntil > 0 && n._key !== root._heldKey && now >= n.toastUntil) {
                    n.popup = false;
                    changed = true;
                }
            if (changed)
                root.listChanged();
        }
    }
    property int _nextKey: 0
    property bool _restored: false
    property var _early: []     // notifications re-sent before the saved history was restored

    readonly property var notClosed: list.filter(n => !n.closed)
    readonly property var popups: list.filter(n => n.popup && !n.closed)
    readonly property int popupCount: popups.length

    // Mutators look entries up by _key: modelData of a `property var` array is marshalled across files, so ===
    // against the passed entry never matches.
    function _find(key) {
        return list.find(n => n._key === key);
    }

    function close(key) {
        const entry = _find(key);
        if (!entry)
            return;
        entry.closed = true;
        entry.popup = false;
        listChanged();
        if (entry._notif && entry._notif.tracked)
            entry._notif.dismiss();
    }

    // Removes the entry (close() only flags it: the toast goes, the history keeps it).
    function remove(key) {
        const entry = _find(key);
        if (entry && entry._notif && entry._notif.tracked)
            entry._notif.dismiss();
        list = list.filter(n => n._key !== key);
    }

    // Closes every open notification, so a reload can't re-send it.
    function clearHistory() {
        for (const n of server.trackedNotifications.values)
            n.dismiss();
        list = [];
    }

    function dismissPopup(key) {
        const entry = _find(key);
        if (!entry)
            return;
        entry.popup = false;
        listChanged();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            // Re-sent after a reload: attach it to its restored entry; no new entry, no toast.
            if (notif.lastGeneration) {
                if (root._restored)
                    root._reattach(notif);
                else
                    root._early.push(notif);
                return;
            }

            const entry = {
                _key: root._nextKey++,
                _notif: notif,
                id: notif.id,
                appName: notif.appName || "Unknown",
                appIcon: notif.appIcon,
                summary: notif.summary,
                body: notif.body,
                urgency: notif.urgency,
                expireTimeout: notif.expireTimeout,     // ms asked for by the sender; -1 = no preference, 0 = never
                image: notif.image,
                actions: (notif.actions || []).map(a => ({ identifier: a.identifier, text: a.text, invoke: () => a.invoke() })),
                time: new Date(),
                closed: false,
                popup: !root.dnd,
                toastUntil: 0
            };
            const t = root._toastTime(entry);
            entry.toastUntil = t > 0 ? Date.now() + t : 0;

            root._watchClose(entry, notif);
            // At most maxToasts at once: older ones stop being toasts (they stay in the history).
            let shown = 0;
            for (const n of root.list)
                if (n.popup && !n.closed && ++shown >= root.maxToasts)
                    n.popup = false;
            root.list = [entry, ...root.list];
        }
    }

    function _actionsOf(notif) {
        return (notif.actions || []).map(a => ({ identifier: a.identifier, text: a.text, invoke: () => a.invoke() }));
    }

    function _watchClose(entry, notif) {
        notif.closed.connect(reason => {
            const e = root._find(entry._key);
            if (!e)
                return;
            e.closed = true;
            e.popup = false;
            root.listChanged();
        });
        // A sender can update a notification (same id), e.g. Thunar's eject notice goes from critical "Writing data" to
        // "safely unplugged" with 5 s. A showing toast takes the new time; a gone one doesn't come back. The entry is
        // replaced, not changed in place: cards read plain JS fields, which don't notify.
        const update = () => {
            const e = root._find(entry._key);
            if (!e || e.closed)
                return;
            const u = Object.assign({}, e, {
                summary: notif.summary,
                body: notif.body,
                appIcon: notif.appIcon,
                image: notif.image,
                urgency: notif.urgency,
                expireTimeout: notif.expireTimeout,
                actions: root._actionsOf(notif)
            });
            if (u.popup) {
                const t = root._toastTime(u);
                u.toastUntil = t > 0 ? Date.now() + t : 0;
            }
            root.list = root.list.map(n => n._key === u._key ? u : n);
        };
        notif.summaryChanged.connect(update);
        notif.bodyChanged.connect(update);
        notif.appIconChanged.connect(update);
        notif.imageChanged.connect(update);
        notif.urgencyChanged.connect(update);
        notif.expireTimeoutChanged.connect(update);
        notif.actionsChanged.connect(update);
    }

    function _reattach(notif) {
        const entry = list.find(n => n.id === notif.id && !n.closed && !n._notif);
        if (!entry) {
            notif.dismiss();    // cleared before the reload (or unknown): don't let it come back
            return;
        }
        entry._notif = notif;
        entry.actions = _actionsOf(notif);
        entry.image = notif.image;
        _watchClose(entry, notif);
        listChanged();
    }

    // What survives a reload: history (plain data) + DND, in $XDG_RUNTIME_DIR (tmpfs). It can outlive a logout (linger), so
    // the file is tagged with the login session. Not PersistentProperties: the monitor-back reload is a hard reload.
    readonly property string _session: Quickshell.env("XDG_SESSION_ID") + "|" + Quickshell.env("SWAYSOCK")
    readonly property string _runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""

    FileView {
        id: store
        path: root._runtimeDir !== "" ? root._runtimeDir + "/cts1-notifications.json" : ""
        printErrors: false      // no file yet (first start of a session) is normal
        onLoaded: root._restore(text())
        onLoadFailed: root._restore("")
    }

    function _restore(t) {
        let saved = null;
        try {
            saved = JSON.parse(t);
        } catch (e) {}
        if (saved && saved.session === _session) {
            // Open entries get their notification objects back from the server's re-send (_reattach), without a toast.
            list = (saved.entries || []).map(e => Object.assign(e, { _notif: null, actions: [], popup: false, time: new Date(e.time) }));
            dnd = saved.dnd === true;
            _nextKey = saved.nextKey || 0;
        }
        _restored = true;
        for (const n of _early)
            _reattach(n);
        _early = [];
        _save();
    }

    function _save() {
        if (!_restored || store.path === "")
            return;
        store.setText(JSON.stringify({
            session: _session, dnd: dnd, nextKey: _nextKey,
            entries: list.map(e => Object.assign({}, e, { _notif: null, actions: [] }))
        }));
    }
    onListChanged: _save()
    onDndChanged: _save()
}
