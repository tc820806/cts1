//@ pragma UseQApplication
// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): Bluetooth popup ported from modules/bar/popouts/Bluetooth.qml, Bluetooth status/device icons from its BluetoothStatus.qml and Icons.
// CTS1 taskbar (left edge) for sway. relayout() places the icons from layout.json; taskbar popups share one
// window (PopupHost). Run: qs -p <repo>/shell (or bin/shell-restart).
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.lockscreen

ShellRoot {
    id: root

    // No hot reload while locked: it would kill the lock (lockscreen/Lock.qml). Files saved meanwhile are not reloaded.
    settings.watchFiles: !lockScreen.locked

    // The taskbar background is plain black (white in light mode); the rest follows the wallpaper (Theme.qml).
    readonly property color bg: Theme.light ? "#ffffff" : "#000000"
    readonly property color surface: Theme.m3surfaceContainer
    readonly property color hover: Theme.m3surfaceContainerHighest
    readonly property color text: Theme.m3onSurface
    readonly property color dim: Theme.m3outline
    readonly property color accent: Theme.m3primary
    readonly property color warm: Theme.yellow
    readonly property color danger: Theme.red

    // Same step as the sway config's $volstep.
    readonly property real volumeStep: 0.05
    readonly property real brightnessStep: 0.05

    property string currentWallpaper: ""

    // When the last monitor goes (e.g. NVIDIA DP during suspend) sway closes every window and they never come back,
    // so reload the shell once a real monitor returns. Notifs.qml keeps the history in $XDG_RUNTIME_DIR.
    property bool monitorsLost: false
    Connections {
        target: Quickshell
        function onScreensChanged() {
            const real = Quickshell.screens.filter(s => s.name !== "");   // Qt's stand-in screen has no name
            if (real.length === 0) {
                root.monitorsLost = true;
            } else if (root.monitorsLost) {
                root.monitorsLost = false;
                monitorBack.restart();
            }
        }
    }
    Timer {
        id: monitorBack
        interval: 1500          // let the monitor settle (it can flicker on and off while waking up)
        onTriggered: {
            // A reload while locked would kill the lock: wait for the unlock.
            if (lockScreen.locked) {
                console.log("monitor is back after all were gone: reloading the shell after unlock");
                root.reloadAfterUnlock = true;
                return;
            }
            console.log("monitor is back after all were gone: reloading the shell");
            Quickshell.reload(true);
        }
    }
    property bool reloadAfterUnlock: false

    Lock {
        id: lockScreen
        osdShown: root.osdShown
        osdKind: root.osdKind
        osdLevel: root.osdLevel
        osdMuted: root.osdMuted
        onLockedChanged: if (!locked && root.reloadAfterUnlock) {
            root.reloadAfterUnlock = false;
            monitorBack.restart();
        }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen.lock(); }
        function preview(): void { lockScreen.previewShown = !lockScreen.previewShown; }
    }

    Desktop {}
    PrinterWatch {}

    // The center-screen windows take turns: opening one closes the others (keep = the one opening; null = power menu).
    function closeOthers(keep) {
        for (const w of [perfPopup, settingsWin, wallPicker, timerWin, notesWin])
            if (w !== keep)
                w.open = false;
        if (keep !== null)
            root.powerMenuOpen = false;
    }
    PerformancePopup {
        id: perfPopup
        onOpenChanged: if (open) root.closeOthers(perfPopup)
    }
    SettingsWindow {
        id: settingsWin
        layout: bar.layout
        labels: root.iconLabels
        onChanged: newLayout => bar.saveLayout(newLayout)
        onOpenChanged: if (open) root.closeOthers(settingsWin)
    }
    WallpaperPicker {
        id: wallPicker
        current: root.currentWallpaper
        onOpenChanged: if (open) root.closeOthers(wallPicker)
    }
    TimerWindow {
        id: timerWin
        onOpenChanged: if (open) root.closeOthers(timerWin)
    }
    NotesWindow {
        id: notesWin
        onOpenChanged: if (open) root.closeOthers(notesWin)
    }

    // Names and icons for the settings list.
    readonly property var iconLabels: ({
        launcher: { name: "App launcher", icon: "grid_view" },
        workspaces: { name: "Workspaces", icon: "view_agenda" },
        calendar: { name: "Calendar", icon: "calendar_month" },
        weather: { name: "Weather", icon: "cloud" },
        performance: { name: "Performance", icon: "speed" },
        media: { name: "Media player", icon: "play_arrow" },
        tray: { name: "System tray", icon: "chevron_right" },
        wallpaper: { name: "Wallpaper", icon: "wallpaper" },
        timer: { name: "Timer", icon: "timer" },
        notes: { name: "Notes", icon: "sticky_note_2" },
        recorder: { name: "Screen recorder", icon: "screen_record" },
        network: { name: "Network", icon: "network_wifi" },
        bluetooth: { name: "Bluetooth", icon: "bluetooth" },
        brightness: { name: "Brightness", icon: "light_mode" },
        volume: { name: "Volume", icon: "volume_up" },
        notifications: { name: "Notifications", icon: "notifications" },
        settings: { name: "Settings", icon: "settings" },
        power: { name: "Power", icon: "power_settings_new" }
    })

    PopupHost {
        id: popupHost
        barWidth: bar.implicitWidth
        wantsKeyboard: netPopup.pwNetwork !== null

        HostPopup {
            name: "calendar"
            CalendarCard {
                width: parent.width
                radius: 6
            }
        }

        // Ported from Caelestia's bar/popouts/Bluetooth.qml.
        HostPopup {
            id: btPopup
            name: "bluetooth"
            preferredWidth: 312
            // Device whose forget button was clicked once (null = none), for 3 s.
            property var forgetArmed: null
            Timer {
                id: btForgetArmTimer
                interval: 3000
                onTriggered: btPopup.forgetArmed = null
            }
            Column {
                width: parent.width
                spacing: 8

                ToggleRow {
                    label: root.btOn ? "Bluetooth on" : "Bluetooth off"
                    checked: root.btOn
                    onToggled: root.toggleBluetooth()
                }
                ToggleRow {
                    label: "Discovering"
                    checked: root.btOn && !!(root.btAdapter && root.btAdapter.discovering)
                    onToggled: {
                        if (root.btAdapter)
                            root.btAdapter.discovering = !root.btAdapter.discovering;
                    }
                }

                Text {
                    width: parent.width
                    visible: root.btOn
                    text: Bluetooth.devices.values.length + (Bluetooth.devices.values.length === 1 ? " device available" : " devices available") +
                          (root.btConnected.length > 0 ? " (" + root.btConnected.length + " connected)" : "") +
                          (Bluetooth.devices.values.length > 8 ? ", showing 8" : "")
                    color: root.dim
                    font.pixelSize: 12
                }

                // Scrolls past 180 px: the popup sits near the screen's bottom edge.
                Flickable {
                    width: parent.width
                    height: Math.min(btDeviceCol.implicitHeight, 180)
                    contentWidth: width
                    contentHeight: btDeviceCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: btDeviceCol
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.btOn ? [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)).slice(0, 8) : []

                            RowLayout {
                                id: btItem
                                required property var modelData
                                readonly property bool isBusy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                                width: btDeviceCol.width
                                spacing: 6

                                MaterialIcon {
                                    text: root.btDeviceIcon(btItem.modelData.icon)
                                    font.pixelSize: 16
                                    color: btItem.modelData.connected ? root.accent : root.dim
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: btItem.modelData.name || btItem.modelData.deviceName || "Unknown device"
                                    color: btItem.modelData.connected ? root.accent : root.text
                                    elide: Text.ElideRight
                                }
                                IconButton {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    iconSize: 15
                                    icon: btItem.isBusy ? "sync" : (btItem.modelData.connected ? "link_off" : "link")
                                    checked: btItem.modelData.connected
                                    disabled: btItem.isBusy
                                    onClicked: btItem.modelData.connected = !btItem.modelData.connected
                                }
                                // Forget: the first click arms it for 3 s, the second unpairs.
                                IconButton {
                                    readonly property bool armed: btPopup.forgetArmed === btItem.modelData
                                    visible: btItem.modelData.bonded
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    iconSize: 15
                                    icon: armed ? "check" : "delete"
                                    danger: armed
                                    onClicked: {
                                        if (!armed) {
                                            btPopup.forgetArmed = btItem.modelData;
                                            btForgetArmTimer.restart();
                                            return;
                                        }
                                        btPopup.forgetArmed = null;
                                        btItem.modelData.forget();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        HostPopup {
            id: trayPopup
            name: "tray"
            preferredWidth: SystemTray.items.values.length === 0 ? 112 : perRow * 36 + (perRow - 1) * 6     // up to 4 per row
            readonly property int perRow: Math.max(1, Math.min(SystemTray.items.values.length, 4))

            Column {
                width: parent.width
                spacing: 8

                StyledText {
                    visible: SystemTray.items.values.length === 0
                    text: "No tray icons"
                    color: root.dim
                }
                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            id: trayItem
                            required property var modelData
                            width: 36
                            height: 36
                            radius: 8
                            color: itemMouse.containsMouse ? root.hover : "transparent"

                            Image {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                source: trayItem.modelData.icon
                                sourceSize: Qt.size(44, 44)
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    const it = trayItem.modelData;
                                    // Menus need a parent window: the taskbar.
                                    const y = trayButton.mapToItem(null, 0, 0).y;
                                    if (mouse.button === Qt.LeftButton && !it.onlyMenu)
                                        it.activate();
                                    else if (mouse.button === Qt.MiddleButton)
                                        it.secondaryActivate();
                                    else if (it.hasMenu)
                                        it.display(bar, bar.implicitWidth + 4, y);
                                }
                            }
                        }
                    }
                }
            }
        }

        HostPopup {
            id: recorderPopup
            name: "recorder"
            preferredWidth: 220
            Column {
                width: parent.width
                spacing: 8

                ScreenRecorder { id: recorderContent }
            }
        }

        HostPopup {
            id: brightnessPopup
            name: "brightness"
            preferredWidth: 232
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Brightness (" + Math.round(brightness.value * 100) + "%)"
                    color: root.text
                    font.bold: true
                }
                HSlider {
                    width: parent.width
                    value: brightness.value
                    fill: root.warm
                    onMoved: v => root.setBrightness(v)
                }
            }
        }

        HostPopup {
            id: weatherPopup
            name: "weather"
            preferredWidth: 899
            Column {
                width: parent.width
                spacing: 8

                WeatherTab {
                    width: 899
                    height: 372
                }
            }
        }

        HostPopup {
            id: mediaPopup
            name: "media"
            preferredWidth: Theme.dash.mediaWidth
            Column {
                width: parent.width
                spacing: 8

                MediaPlayer {
                    width: parent.width
                    visualizerActive: mediaPopup.visible
                    radius: 6
                }
            }
        }

        HostPopup {
            id: notifPopup
            name: "notifications"
            preferredWidth: 272
            Column {
                width: parent.width
                spacing: 8

                NotificationsTab {
                    width: parent.width
                    height: 297
                }
            }
        }

        HostPopup {
            id: volumePopup
            name: "volume"
            preferredWidth: 292
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Output device"
                    color: root.text
                    font.bold: true
                }
                Repeater {
                    model: root.sinks
                    RadioRow {
                        required property var modelData
                        label: root.nodeName(modelData)
                        checked: root.sink !== null && root.sink.id === modelData.id
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }

                Item { width: 1; height: 6 }

                Text {
                    text: "Input device"
                    color: root.text
                    font.bold: true
                }
                Repeater {
                    model: root.sources
                    RadioRow {
                        required property var modelData
                        label: root.nodeName(modelData)
                        checked: root.source !== null && root.source.id === modelData.id
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }

                Item { width: 1; height: 6 }

                Text {
                    text: root.muted ? "Volume (muted)" : "Volume (" + Math.round(root.volume * 100) + "%)"
                    color: root.text
                    font.bold: true
                }
                HSlider {
                    width: parent.width
                    value: root.volume
                    fill: root.muted ? root.dim : root.accent
                    step: root.volumeStep
                    onMoved: v => root.setVolume(v)
                }
            }
        }

        HostPopup {
            id: netPopup
            name: "network"
            preferredWidth: 312

            // Scan only while open (Quickshell then asks NetworkManager every ~10 s); closed, the list holds only the
            // connected and saved networks.
            Binding {
                target: root.wifiDevice
                property: "scannerEnabled"
                value: popupHost.current === "network"
                when: root.wifiDevice !== null
            }

            property var pwNetwork: null
            property string pwError: ""
            function askPassword(net, error) {
                pwNetwork = net;
                pwError = error ?? "";
            }
            function cancelPassword() {
                pwNetwork = null;
                pwError = "";
            }
            // Row state lives here, not in the rows: every scan re-sorts and rebuilds them.
            // Network whose forget button was clicked once (null = none), for 3 s.
            property var forgetArmed: null
            Timer {
                id: forgetArmTimer
                interval: 3000
                onTriggered: netPopup.forgetArmed = null
            }
            property var failNet: null
            property string failText: ""
            function showFailure(net, text) {
                failNet = net;
                failText = text;
                failTimer.restart();
            }
            Timer {
                id: failTimer
                interval: 5000
                onTriggered: {
                    netPopup.failNet = null;
                    netPopup.failText = "";
                }
            }

            // What connectWithPsk accepts (WPA/WPA2/WPA3-Personal).
            function takesPassword(net) {
                return net.security === WifiSecurityType.WpaPsk || net.security === WifiSecurityType.Wpa2Psk
                    || net.security === WifiSecurityType.Sae;
            }
            Connections {
                target: popupHost
                function onCurrentChanged() {
                    if (popupHost.current !== "network")
                        netPopup.cancelPassword();
                }
            }

            // Stable order (connected, saved, rest; each alphabetical) so rows don't swap under the pointer on every scan.
            readonly property var allNetworks: root.wifiDevice && Networking.wifiEnabled
                ? [...root.wifiDevice.networks.values].sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                    || a.name.localeCompare(b.name))
                : []
            readonly property var networks: allNetworks.slice(0, 8)     // the list shows at most 8
            Column {
                width: parent.width
                spacing: 8

                ToggleRow {
                    label: Networking.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                    checked: Networking.wifiEnabled
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                Text {
                    width: parent.width
                    visible: root.wiredConnected !== null
                    readonly property var wired: root.netDevices.find(d => d.type === DeviceType.Wired) ?? null
                    text: "Ethernet connected" + (wired && wired.linkSpeed > 0 ? " (" + wired.linkSpeed + " Mb/s)" : "")
                    color: root.dim
                }

                Text {
                    width: parent.width
                    visible: root.wifiDevice === null
                    text: "No Wi-Fi adapter detected on this machine"
                    color: root.dim
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: root.wifiDevice !== null && Networking.wifiEnabled
                    text: netPopup.allNetworks.length + (netPopup.allNetworks.length === 1 ? " network available" : " networks available")
                          + (netPopup.allNetworks.length > 8 ? " (showing 8)" : "")
                    color: root.dim
                    font.pixelSize: 12
                }

                Flickable {
                    width: parent.width
                    visible: root.wifiDevice !== null && Networking.wifiEnabled
                    height: Math.min(netCol.implicitHeight, 5 * 26 + 4 * 4)     // sized to the list, up to 5 rows; more scroll
                    contentWidth: width
                    contentHeight: netCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: netCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: netPopup.networks

                            Column {
                                id: netItem
                                required property var modelData
                                readonly property real strength: modelData.signalStrength <= 1 ? modelData.signalStrength * 100 : modelData.signalStrength
                                width: netCol.width
                                spacing: 2

                                Connections {
                                    target: netItem.modelData
                                    function onConnectionFailed(reason) {
                                        // NoSecrets on a WPA network: ask for (another) password.
                                        if (reason === ConnectionFailReason.NoSecrets && netPopup.takesPassword(netItem.modelData)) {
                                            const retry = netPopup.pwNetwork === netItem.modelData;
                                            netPopup.askPassword(netItem.modelData, retry ? "Wrong password, try again" : "");
                                            return;
                                        }
                                        netPopup.showFailure(netItem.modelData, ({
                                            [ConnectionFailReason.NoSecrets]: "Password missing or wrong",
                                            [ConnectionFailReason.WifiAuthTimeout]: "Timed out while connecting",
                                            [ConnectionFailReason.WifiNetworkLost]: "Network went out of range"
                                        })[reason] ?? "Couldn't connect");
                                    }
                                }
                                Connections {
                                    target: netItem.modelData
                                    function onConnectedChanged() {
                                        if (netItem.modelData.connected && netPopup.pwNetwork === netItem.modelData)
                                            netPopup.cancelPassword();
                                    }
                                }

                                RowLayout {
                                    width: netCol.width
                                    spacing: 6

                                    MaterialIcon {
                                        text: root.networkIcons[Math.max(0, Math.min(4, Math.floor(netItem.strength / 20)))]
                                        font.pixelSize: 16
                                        color: netItem.modelData.connected ? root.accent : root.dim
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    MaterialIcon {
                                        visible: netItem.modelData.security !== WifiSecurityType.Open
                                        text: "lock"
                                        font.pixelSize: 12
                                        color: root.dim
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        text: netItem.modelData.name
                                        color: netItem.modelData.connected ? root.accent : root.text
                                        elide: Text.ElideRight
                                    }
                                    // Not saved and password-protected: ask for the password first.
                                    IconButton {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        iconSize: 15
                                        icon: netItem.modelData.stateChanging ? "sync" : (netItem.modelData.connected ? "link_off" : "link")
                                        checked: netItem.modelData.connected
                                        disabled: netItem.modelData.stateChanging
                                        onClicked: {
                                            const net = netItem.modelData;
                                            if (net.connected)
                                                net.disconnect();
                                            else if (net.known || net.security === WifiSecurityType.Open)
                                                net.connect();
                                            else if (netPopup.takesPassword(net))
                                                netPopup.askPassword(net, "");
                                            else
                                                netPopup.showFailure(net, "This kind of network isn't supported here");
                                        }
                                    }
                                    // Forget (deletes the saved profile and password): the first click arms it for 3 s, the second forgets.
                                    IconButton {
                                        readonly property bool armed: netPopup.forgetArmed === netItem.modelData
                                        visible: netItem.modelData.known
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        iconSize: 15
                                        icon: armed ? "check" : "delete"
                                        danger: armed
                                        disabled: netItem.modelData.stateChanging
                                        onClicked: {
                                            if (!armed) {
                                                netPopup.forgetArmed = netItem.modelData;
                                                forgetArmTimer.restart();
                                                return;
                                            }
                                            netPopup.forgetArmed = null;
                                            netItem.modelData.forget();
                                        }
                                    }
                                }

                                // Password field: Enter connects, Escape cancels.
                                RowLayout {
                                    id: pwRow
                                    visible: netPopup.pwNetwork === netItem.modelData
                                    width: netCol.width
                                    spacing: 6

                                    function submit() {
                                        if (pwInput.text.length === 0)
                                            return;
                                        netPopup.pwError = "";
                                        netItem.modelData.connectWithPsk(pwInput.text);
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 22
                                        implicitHeight: 26
                                        radius: 6
                                        color: root.surface
                                        border.width: netPopup.pwError !== "" ? 1 : 0
                                        border.color: root.danger

                                        TextInput {
                                            id: pwInput
                                            anchors.fill: parent
                                            leftPadding: 8
                                            rightPadding: 8
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: TextInput.Password
                                            color: root.text
                                            clip: true
                                            onVisibleChanged: if (visible) {
                                                text = "";
                                                forceActiveFocus();
                                            }
                                            Keys.onReturnPressed: pwRow.submit()
                                            Keys.onEnterPressed: pwRow.submit()
                                            Keys.onEscapePressed: netPopup.cancelPassword()
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 8
                                            visible: pwInput.text.length === 0
                                            text: "Password"
                                            color: root.dim
                                        }
                                    }
                                    IconButton {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        iconSize: 15
                                        icon: "check"
                                        disabled: pwInput.text.length === 0 || netItem.modelData.stateChanging
                                        onClicked: pwRow.submit()
                                    }
                                    IconButton {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        iconSize: 15
                                        icon: "close"
                                        onClicked: netPopup.cancelPassword()
                                    }
                                }
                                Text {
                                    visible: netPopup.pwNetwork === netItem.modelData && netPopup.pwError !== ""
                                    leftPadding: 22
                                    text: netPopup.pwError
                                    color: root.danger
                                    font.pixelSize: 11
                                }

                                Text {
                                    visible: netPopup.failNet === netItem.modelData && netPopup.failText !== ""
                                    leftPadding: 22
                                    text: netPopup.failText
                                    color: root.danger
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- On-screen indicator (volume, brightness) ----------
    // Shown only by the sway keys (`ipc call osd trigger`; "show" is taken by qs itself), never by PipeWire changes: a
    // USB speaker waking up re-reads its volume and would flash it. Not shown while the matching popup is open.
    property bool osdShown: false
    property string osdKind: "volume"           // "volume" or "brightness"

    Timer {
        id: osdHide
        interval: 1600
        onTriggered: root.osdShown = false
    }
    function showOsd(kind) {
        kind = kind || "volume";
        if ((kind === "brightness" ? brightnessPopup : volumePopup).visible)
            return;
        osdKind = kind;
        osdShown = true;
        osdHide.restart();
    }
    IpcHandler {
        target: "osd"
        function trigger(): void { root.showOsd(); }
    }

    readonly property real osdLevel: osdKind === "brightness" ? brightness.value : volume
    readonly property bool osdMuted: osdKind === "volume" && muted

    PanelWindow {
        visible: root.osdShown || osdBox.opacity > 0.01
        anchors.bottom: true
        margins.bottom: 64
        implicitWidth: 320
        implicitHeight: 64
        exclusionMode: ExclusionMode.Ignore     // centered on the whole screen, not beside the taskbar
        WlrLayershell.layer: WlrLayer.Overlay   // above fullscreen windows (the default Top layer sits below them)
        color: "transparent"
        mask: Region {}         // empty: clicks pass straight through

        Rectangle {
            id: osdBox
            anchors.fill: parent
            radius: 6       // like the lock screen's indicator and the taskbar buttons
            color: Theme.m3surface
            border.color: Theme.m3outlineVariant
            border.width: 1
            opacity: root.osdShown ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            MaterialIcon {
                id: osdIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.osdKind === "brightness"
                    ? (brightness.value < 0.34 ? "brightness_low" : brightness.value < 0.67 ? "brightness_medium" : "brightness_high")
                    : root.muted || root.volume <= 0 ? "volume_off" : root.volume < 0.34 ? "volume_mute"
                    : root.volume < 0.67 ? "volume_down" : "volume_up"
                font.pixelSize: 26
                color: root.osdMuted ? root.danger : root.accent
            }

            Rectangle {
                id: osdTrack
                anchors.left: osdIcon.right
                anchors.leftMargin: 14
                anchors.right: osdPercent.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 10
                radius: 5
                color: root.surface

                Rectangle {
                    anchors.left: parent.left
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, root.osdLevel))
                    radius: 5
                    color: root.osdMuted ? root.dim : root.accent
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                id: osdPercent
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.osdLevel * 100) + "%"
                font.pixelSize: 17
                font.bold: true
                color: root.osdMuted ? root.dim : root.text
            }
        }
    }

    // ---------- Power menu ----------
    // Nothing is highlighted on open, so a stray Enter does nothing.
    property bool powerMenuOpen: false
    property int powerIndex: -1
    onPowerMenuOpenChanged: {
        powerIndex = -1;
        if (powerMenuOpen)
            closeOthers(null);
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            root.powerMenuOpen = !root.powerMenuOpen;
        }
        function open(): void {
            root.powerMenuOpen = true;
        }
        function close(): void {
            root.powerMenuOpen = false;
        }
    }

    PanelWindow {
        id: powerOverlay
        visible: root.powerMenuOpen || powerBox.opacity > 0.01
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.powerMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.powerMenuOpen ? 0.5 : 0
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.powerMenuOpen = false
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.powerMenuOpen = false
            Keys.onLeftPressed: root.powerIndex = root.powerIndex <= 0 ? powerItems.count - 1 : root.powerIndex - 1
            Keys.onRightPressed: root.powerIndex = (root.powerIndex + 1) % powerItems.count
            Keys.onReturnPressed: powerItems.run(root.powerIndex)
            Keys.onEnterPressed: powerItems.run(root.powerIndex)
            Keys.onSpacePressed: powerItems.run(root.powerIndex)
        }

        Rectangle {
            id: powerBox
            anchors.centerIn: parent
            width: powerRow.implicitWidth + 44
            height: 140
            radius: 30
            color: Theme.m3surface
            border.color: Theme.m3outlineVariant
            border.width: 1
            opacity: root.powerMenuOpen ? 1 : 0
            scale: root.powerMenuOpen ? 1 : 0.9
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent    // clicks on the panel's padding must not close the menu
            }

            Row {
                id: powerRow
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    id: powerItems
                    function run(i: int): void {
                        if (i < 0)
                            return;
                        root.powerMenuOpen = false;
                        Quickshell.execDetached(model[i].cmd);
                    }
                    model: [
                        { icon: "bedtime",         colour: Theme.m3primary, cmd: ["systemctl", "suspend"] },
                        { icon: "logout",           colour: Theme.m3primary, cmd: ["swaymsg", "exit"] },
                        { icon: "restart_alt",      colour: Theme.m3primary, cmd: ["systemctl", "reboot"] },
                        { icon: "power_settings_new", colour: Theme.m3error, cmd: ["systemctl", "poweroff"] }
                    ]

                    Rectangle {
                        id: powerItem
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.powerIndex === index
                        width: 96
                        height: 96
                        radius: 24
                        color: selected ? root.hover : root.surface
                        border.width: 2
                        border.color: selected ? powerItem.modelData.colour : "transparent"
                        scale: selected ? 1.06 : 1
                        Behavior on scale {
                            NumberAnimation { duration: 120 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: powerItem.modelData.icon
                            font.pixelSize: 46
                            color: powerItem.modelData.colour
                        }
                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) root.powerIndex = powerItem.index
                            onClicked: powerItems.run(powerItem.index)
                        }
                    }
                }
            }
        }
    }

    // ---------- Notification toasts (Notifs.qml is the notification server) ----------
    PanelWindow {
        id: toastStack
        visible: Notifs.popupCount > 0
        anchors { top: true; right: true }
        margins { top: 12; right: 12 }
        implicitWidth: 340
        implicitHeight: toastCol.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Column {
            id: toastCol
            width: parent.width
            spacing: 8

            Repeater {
                // ScriptModel keeps each card when the list changes, so toasts don't flicker or land under the pointer.
                model: ScriptModel {
                    values: Notifs.popups
                    objectProp: "_key"
                }

                NotificationPopup {
                    width: toastCol.width
                    onDismissed: Notifs.dismissPopup(modelData._key)
                }
            }
        }
    }

    IpcHandler {
        target: "dnd"
        function toggle(): void { Notifs.dnd = !Notifs.dnd; }
    }

    // ---------- Reusable pieces ----------

    // Taskbar icon: a 30 px square in a bar-wide slot; `active` = accent fill, icon in the bar color. Children
    // (the timer's countdown) go inside the square. PopupHost reads `containsMouse` for its close timer.
    component BarButton: Item {
        id: bb
        property string icon: ""
        property int iconSize: 18
        property bool active: false
        property color iconColor: root.text
        property color fill: active ? root.accent : (containsMouse ? root.hover : root.surface)
        readonly property bool containsMouse: area.containsMouse
        default property alias content: box.data
        signal clicked()
        signal hovered()
        signal wheel(var event)
        width: bar.baseWidth
        height: 30

        Rectangle {
            id: box
            anchors.centerIn: parent
            width: 30
            height: 30
            radius: 6
            color: bb.fill

            MaterialIcon {
                anchors.centerIn: parent
                visible: bb.icon !== ""
                text: bb.icon
                font.pixelSize: bb.iconSize
                color: bb.active ? root.bg : bb.iconColor
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: bb.clicked()
            onContainsMouseChanged: if (containsMouse) bb.hovered()
            onWheel: event => bb.wheel(event)
        }
    }

    // On/off switch (Caelestia's StyledSwitch).
    component Switch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: 40; height: 22; radius: 11
        color: checked ? root.accent : root.surface
        border.width: checked ? 0 : 1
        border.color: root.dim
        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? root.bg : root.dim
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { anchors.fill: parent; onClicked: sw.toggled() }
    }

    // Label + Switch. RowLayout, not Row: a hand-computed spacer cut the switch off.
    component ToggleRow: RowLayout {
        id: trow
        property string label: ""
        property bool checked: false
        signal toggled()
        width: parent ? parent.width : 0

        Text {
            text: trow.label
            color: root.text
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        Switch {
            Layout.alignment: Qt.AlignVCenter
            checked: trow.checked
            onToggled: trow.toggled()
        }
    }

    // Horizontal slider: click/drag sets the value, wheel nudges it by 5%.
    component HSlider: Item {
        id: slider
        property real value: 0
        property color fill: root.accent
        property real step: 0.05       // how far one wheel notch moves the value
        signal moved(real v)
        signal released()
        height: 22
        readonly property real shown: Math.max(0, Math.min(1, value))     // volume can go above 100%

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: root.surface

            Rectangle {
                width: parent.width * slider.shown
                height: parent.height
                radius: 3
                color: slider.fill
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: (slider.width - width) * slider.shown
            width: 14
            height: 14
            radius: 7
            color: root.text
        }
        MouseArea {
            anchors.fill: parent
            function setFrom(x) {
                slider.moved(Math.max(0, Math.min(1, x / width)));
            }
            onPressed: mouse => setFrom(mouse.x)
            onPositionChanged: mouse => setFrom(mouse.x)
            onReleased: slider.released()
            onWheel: wheel => {
                const step = wheel.angleDelta.y > 0 ? slider.step : -slider.step;
                slider.moved(Math.max(0, Math.min(1, slider.value + step)));
                slider.released();
            }
        }
    }

    component RadioRow: Item {
        id: row
        property bool checked: false
        property string label: ""
        signal clicked()
        width: parent ? parent.width : 0
        height: 28

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: "transparent"
            border.width: 2
            border.color: row.checked ? root.accent : root.dim

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: root.accent
                visible: row.checked
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.right: parent.right
            elide: Text.ElideRight
            text: row.label
            color: root.text
        }
        MouseArea {
            anchors.fill: parent
            onClicked: row.clicked()
        }
    }

    // ---------- Volume (PipeWire) ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0

    // Binds every node so isSink/audio/description are populated.
    PwObjectTracker { objects: Pipewire.nodes.values }

    function nodesOf(wantSinks) {
        const out = [];
        const v = Pipewire.nodes.values;
        for (let i = 0; i < v.length; i++) {
            const n = v[i];
            if (n.isStream)
                continue;
            if (wantSinks ? n.isSink : (!n.isSink && n.audio))
                out.push(n);
        }
        // PipeWire's own order changes between boots: sort by the shown name so devices keep their place.
        return out.sort((a, b) => root.nodeName(a).localeCompare(root.nodeName(b)));
    }
    readonly property var sinks: nodesOf(true)
    readonly property var sources: nodesOf(false)

    function setVolume(v) {
        if (sink && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function nodeName(n) {
        return n.description || n.nickname || n.name;
    }

    // ---------- Brightness ----------
    // Backend found once at startup: "backlight" (brightnessctl), "ddc" (ddcutil, first monitor) or "" (icon hidden).
    // The keys (`ipc call brightness up/down`) change it here so the indicator shows the new value at once; a value
    // over 10 s old is read first and the step applied to that.
    QtObject {
        id: brightness
        property string backend: ""
        property real value: 0.5
        property int max: 100
        property int changes: 0         // bumped by every setBrightness(): a read started before a change is dropped
        property double lastRead: 0     // ms timestamp of the last refresh
        property double lastSet: 0      // ms timestamp of the last setBrightness()
        property real pendingStep: 0    // key steps waiting for a fresh read (stepBrightness)
    }
    // brightnessctl / ddcutil output -> brightness.max/value; true if it parsed.
    function parseBrightness(backend, line) {
        let cur = NaN, max = NaN;
        if (backend === "backlight" && line) {
            // Machine format: "<device>,backlight,<current>,<percent>%,<max>"
            const f = line.split(",");
            cur = parseInt(f[2]);
            max = parseInt(f[4]);
        } else if (backend === "ddc" && line) {
            // Terse format: "VCP 10 C <current> <max>"
            const f = line.trim().split(/\s+/);
            cur = parseInt(f[3]);
            max = parseInt(f[4]);
        }
        if (!(max > 0 && cur >= 0))
            return false;
        brightness.max = max;
        brightness.value = cur / max;
        return true;
    }
    function refreshBrightness(force) {
        const now = Date.now();
        if (brightness.backend === "" || brightRead.running || (!force && now - brightness.lastRead < 5000))
            return;
        brightness.lastRead = now;
        brightRead.startChanges = brightness.changes;
        brightRead.command = brightness.backend === "backlight"
            ? ["brightnessctl", "-m", "-c", "backlight"] : ["ddcutil", "-t", "getvcp", "10"];
        brightRead.running = true;
    }
    Process {
        id: brightRead
        property int startChanges: 0
        stdout: StdioCollector {
            onStreamFinished: {
                // Dropped if the value was changed here meanwhile (or a write is still pending): ours is newer.
                if (brightness.changes === brightRead.startChanges && !brightDebounce.running && !brightSet.running)
                    root.parseBrightness(brightness.backend, text.trim().split("\n")[0]);
                // Key steps that waited for this read (if the read failed, they apply to the old value).
                if (brightness.pendingStep !== 0) {
                    const d = brightness.pendingStep;
                    brightness.pendingStep = 0;
                    root.setBrightness(brightness.value + d);
                }
            }
        }
    }
    Process {
        id: brightDetect
        running: true
        command: ["sh", "-c",
            "if ls /sys/class/backlight/* >/dev/null 2>&1 && command -v brightnessctl >/dev/null; then "
            + "echo backlight; brightnessctl -m -c backlight; "
            + "elif command -v ddcutil >/dev/null && out=$(ddcutil -t getvcp 10 2>/dev/null); then "
            + "echo ddc; echo \"$out\"; "
            + "else echo none; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (root.parseBrightness(lines[0], lines[1])) {
                    brightness.backend = lines[0];
                    brightness.lastRead = Date.now();
                }
            }
        }
    }
    Process { id: brightSet }
    // ddcutil is slow (~1s), so coalesce drags into one write (harmless for brightnessctl too).
    Timer {
        id: brightDebounce
        interval: 300
        onTriggered: {
            if (brightSet.running) {
                brightDebounce.restart();
                return;
            }
            const raw = String(Math.round(brightness.value * brightness.max));
            if (brightness.backend === "backlight")
                brightSet.command = ["brightnessctl", "-q", "-c", "backlight", "set", raw];
            else if (brightness.backend === "ddc")
                brightSet.command = ["ddcutil", "--noverify", "setvcp", "10", raw];
            else
                return;
            brightSet.running = true;
        }
    }
    function setBrightness(v) {
        brightness.changes++;
        brightness.lastSet = Date.now();
        brightness.value = Math.max(0, Math.min(1, v));
        brightDebounce.restart();
    }
    function stepBrightness(d) {
        if (brightness.backend === "")
            return;
        if (brightness.pendingStep !== 0 || Date.now() - Math.max(brightness.lastRead, brightness.lastSet) > 10000) {
            brightness.pendingStep += d;
            refreshBrightness(true);    // no-op if a read is already running; its result applies the steps
        } else {
            setBrightness(brightness.value + d);
        }
        showOsd("brightness");
    }
    IpcHandler {
        target: "brightness"
        function up(): void { root.stepBrightness(root.brightnessStep); }
        function down(): void { root.stepBrightness(-root.brightnessStep); }
    }

    // ---------- Network ----------
    readonly property var networkIcons: ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "network_wifi"]
    readonly property var netDevices: Networking.devices.values
    readonly property var wiredConnected: netDevices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: netDevices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property string networkIcon: {
        if (wiredConnected)
            return "cable";
        if (!Networking.wifiEnabled || !wifiNetwork)
            return "wifi_off";
        const s = wifiNetwork.signalStrength <= 1 ? wifiNetwork.signalStrength * 100 : wifiNetwork.signalStrength;
        return networkIcons[Math.max(0, Math.min(4, Math.floor(s / 20)))];
    }

    // ---------- Bluetooth ----------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!(btAdapter && btAdapter.enabled)
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    // Same three states as Caelestia's BluetoothStatus.qml.
    readonly property string btIcon: !btOn ? "bluetooth_disabled" : (btConnected.length > 0 ? "bluetooth_connected" : "bluetooth")
    function toggleBluetooth() {
        if (btAdapter)
            btAdapter.enabled = !btAdapter.enabled;
    }
    // Caelestia's Icons.getBluetoothIcon: BlueZ icon hint -> Material icon, by substring.
    readonly property var btIconRules: [
        [["headset", "headphones"], "headphones"],
        [["audio"], "speaker"],
        [["phone"], "smartphone"],
        [["mouse"], "mouse"],
        [["keyboard"], "keyboard"]
    ]
    function btDeviceIcon(icon) {
        const text = icon || "";
        for (const [needles, result] of btIconRules)
            if (needles.some(n => text.includes(n)))
                return result;
        return "bluetooth";
    }

    // ---------- The taskbar ----------
    PanelWindow {
        id: bar
        anchors {
            top: true
            bottom: true
            left: true
        }
        // Shrink-to-fit: if the icons don't fit the height, the whole bar is scaled by `fit` (set by relayout()).
        readonly property int baseWidth: 44
        property real fit: 1
        implicitWidth: Math.ceil(baseWidth * fit)
        color: root.bg

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // The groups only declare icons; relayout() positions them. Never reparent an icon: the media icon stops painting.

        // ---- Top group ----
        Item {
            id: topGroup
            width: bar.baseWidth
            height: bar.height / bar.fit
            scale: bar.fit
            transformOrigin: Item.TopLeft

            // Launcher: the distro logo (os-release LOGO) in the accent color, else grid_view. fuzzel must not quit on focus
            // loss (focus follows the mouse).
            Rectangle {
                id: launcherButton
                width: 30
                height: 30
                radius: 6
                color: launchArea.containsMouse ? root.hover : root.surface

                property string osLogo: ""
                property string logoFile: ""
                FileView {
                    path: "/etc/os-release"
                    onLoaded: {
                        const m = text().match(/^LOGO="?([^"\n]*)"?/m);
                        launcherButton.osLogo = m ? m[1] : "";
                    }
                }
                Process {
                    command: [Quickshell.shellPath("bin/find-icon"), launcherButton.osLogo]
                    running: launcherButton.osLogo !== ""
                    stdout: StdioCollector {
                        onStreamFinished: launcherButton.logoFile = text.trim()
                    }
                }

                // Drawn at 4x and scaled down for smooth edges.
                Image {
                    id: logoImg
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    sourceSize: Qt.size(width * 4, height * 4)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: launcherButton.logoFile !== "" ? "file://" + launcherButton.logoFile : ""
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: logoImg
                    source: logoImg
                    color: root.accent
                    visible: logoImg.status === Image.Ready
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: logoImg.status !== Image.Ready
                    text: "grid_view"
                    font.pixelSize: 22
                    font.variableAxes: ({ "FILL": 1 })     // solid squares, not outlines
                    color: root.accent
                }
                MouseArea {
                    id: launchArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["sh", "-c",
                        "pkill -x fuzzel || exec fuzzel --keyboard-focus=exclusive --no-exit-on-keyboard-focus-loss"])
                }
            }

            // Workspaces 1-5: dim square = empty, larger accent = has windows (sway removes an empty unfocused workspace), red =
            // urgent. The focused one gets the star square, which slides there and turns half a turn per move.
            Rectangle {
                id: wsPill

                readonly property int focusedIdx: I3.focusedWorkspace !== null
                    && I3.focusedWorkspace.number >= 1 && I3.focusedWorkspace.number <= 5
                    ? I3.focusedWorkspace.number - 1 : -1
                property int previousIdx: focusedIdx
                property real starRotation: 0

                onFocusedIdxChanged: {
                    if (focusedIdx < 0)
                        return;
                    if (previousIdx >= 0)
                        starRotation += (focusedIdx >= previousIdx ? 1 : -1) * 180;
                    previousIdx = focusedIdx;
                }

                width: 30
                height: wsColumn.height + 8
                radius: 6
                color: root.surface

                Rectangle {
                    x: 2
                    y: 4 + Math.max(0, wsPill.focusedIdx) * 30
                    width: 26
                    height: 26
                    radius: 6
                    color: root.accent
                    visible: wsPill.focusedIdx >= 0

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f0ae2}"
                        color: root.bg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        rotation: wsPill.starRotation

                        Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                    }

                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                }

                Column {
                    id: wsColumn
                    x: 2
                    y: 4
                    spacing: 4

                    Repeater {
                        model: 5

                        Item {
                            id: wsCell
                            required property int index
                            readonly property var ws: I3.workspaces.values.find(w => w.number === index + 1) || null
                            width: 26
                            height: 26

                            Rectangle {
                                anchors.centerIn: parent
                                width: (wsCell.ws ? 11 : 8) + (wsArea.containsMouse ? 2 : 0)
                                height: width
                                radius: wsCell.ws ? 3 : 2
                                color: wsArea.containsMouse ? root.text
                                    : wsCell.ws && wsCell.ws.urgent ? root.danger : (wsCell.ws ? root.accent : root.dim)
                                visible: wsCell.index !== wsPill.focusedIdx

                                Behavior on width { NumberAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: wsArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: I3.dispatch("workspace number " + (wsCell.index + 1))
                            }
                        }
                    }
                }
            }
        }

        // ---- Center group: centered on the screen ----
        Item {
            id: centerGroup
            width: bar.baseWidth
            height: bar.height / bar.fit
            scale: bar.fit
            transformOrigin: Item.TopLeft

            BarButton {
                id: calendarButton
                icon: "calendar_month"
                active: popupHost.current === "calendar"
                iconColor: root.accent
                onClicked: popupHost.toggle("calendar", calendarButton)
            }
            BarButton {
                id: weatherButton
                icon: Weather.icon
                active: weatherPopup.visible
                iconColor: root.accent
                onClicked: popupHost.toggle("weather", weatherButton)
            }
            BarButton {
                id: perfButton
                icon: "speed"
                active: perfPopup.open
                iconColor: root.accent
                onClicked: perfPopup.open = !perfPopup.open
            }
            BarButton {
                id: mediaButton
                icon: "play_arrow"
                active: mediaPopup.visible
                iconColor: root.accent
                onClicked: popupHost.toggle("media", mediaButton)
            }
        }

        // ---- Bottom group ----
        Item {
            id: bottomGroup
            width: bar.baseWidth
            height: bar.height / bar.fit
            scale: bar.fit
            transformOrigin: Item.TopLeft

            BarButton {
                id: trayButton
                icon: trayPopup.visible ? "chevron_left" : "chevron_right"
                iconSize: 22
                active: trayPopup.visible
                onClicked: popupHost.toggle("tray", trayButton)
            }
            BarButton {
                id: wallpaperButton
                icon: "wallpaper"
                active: wallPicker.open
                onClicked: {
                    popupHost.close();
                    wallPicker.open = !wallPicker.open;
                }
            }
            // Shows the time left on the timer closest to running out; blinks while one has rung.
            BarButton {
                id: timerButton
                active: timerWin.open || timerWin.ringing
                onClicked: {
                    popupHost.close();
                    timerWin.open = !timerWin.open;
                }

                MaterialIcon {
                    id: timerIcon
                    anchors.centerIn: parent
                    visible: timerWin.ringing || timerWin.soonest === null
                    text: timerWin.ringing ? "alarm" : "timer"
                    font.pixelSize: 18
                    color: timerWin.open || timerWin.ringing ? root.bg : root.text
                    SequentialAnimation on opacity {
                        running: timerWin.ringing
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) timerIcon.opacity = 1
                        NumberAnimation { to: 0.2; duration: 400 }
                        NumberAnimation { to: 1; duration: 400 }
                    }
                }
                // m:ss under an hour, else "1h05"
                Text {
                    anchors.centerIn: parent
                    visible: !timerIcon.visible
                    text: {
                        const s = timerWin.soonest;
                        if (!s)
                            return "";
                        const total = Math.ceil(s.timeLeft / 1000);
                        const h = Math.floor(total / 3600), m = Math.floor(total / 60) % 60, sec = total % 60;
                        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m : Math.floor(total / 60) + ":" + (sec < 10 ? "0" : "") + sec;
                    }
                    color: timerWin.open ? root.bg : timerWin.soonest && timerWin.soonest.phase === "paused" ? root.dim : root.accent
                    font.family: Theme.sans
                    font.pixelSize: 9
                    font.bold: true
                }
            }
            BarButton {
                id: notesButton
                icon: "sticky_note_2"
                active: notesWin.open
                onClicked: {
                    popupHost.close();
                    notesWin.open = !notesWin.open;
                }
            }
            BarButton {
                id: recorderButton
                icon: "screen_record"
                active: recorderPopup.visible
                fill: active ? root.accent : recorderContent.running ? root.danger : (containsMouse ? root.hover : root.surface)
                iconColor: recorderContent.running ? "white" : root.text
                onClicked: popupHost.toggle("recorder", recorderButton)
            }
            BarButton {
                id: wifiButton
                icon: root.networkIcon
                active: netPopup.visible
                iconColor: root.networkIcon !== "wifi_off" ? root.accent : root.dim
                onClicked: popupHost.toggle("network", wifiButton)
            }
            BarButton {
                id: btButton
                icon: root.btIcon
                active: popupHost.current === "bluetooth"
                iconColor: root.btOn ? root.accent : root.dim
                onClicked: popupHost.toggle("bluetooth", btButton)
            }
            // Hover re-reads the brightness, so a change made elsewhere doesn't make the next scroll jump.
            BarButton {
                id: brightnessButton
                icon: "light_mode"
                iconColor: root.warm
                onClicked: popupHost.toggle("brightness", brightnessButton)
                onHovered: root.refreshBrightness()
                onWheel: e => root.setBrightness(brightness.value + (e.angleDelta.y > 0 ? root.brightnessStep : -root.brightnessStep))
            }
            // Hover opens the popup; click mutes (it can't do both).
            BarButton {
                id: volumeButton
                icon: root.muted || root.volume <= 0 ? "volume_off" : root.volume < 0.34 ? "volume_mute"
                    : root.volume < 0.67 ? "volume_down" : "volume_up"
                iconColor: root.muted ? root.danger : root.accent
                onHovered: popupHost.show("volume", volumeButton)
                onClicked: {
                    if (root.sink && root.sink.audio)
                        root.sink.audio.muted = !root.sink.audio.muted;
                }
                onWheel: e => root.setVolume(root.volume + (e.angleDelta.y > 0 ? root.volumeStep : -root.volumeStep))
            }
            // Hover opens the history; click toggles Do Not Disturb.
            BarButton {
                id: notifButton
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                active: notifPopup.visible
                iconColor: Notifs.dnd ? root.dim : root.text
                onHovered: popupHost.show("notifications", notifButton)
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            BarButton {
                id: settingsButton
                icon: "settings"
                active: settingsWin.open
                onClicked: settingsWin.open = !settingsWin.open
            }
            BarButton {
                id: powerButton
                icon: "power_settings_new"
                active: root.powerMenuOpen
                fill: active ? Theme.m3error : (containsMouse ? root.hover : root.surface)
                iconColor: Theme.m3error
                onClicked: root.powerMenuOpen = !root.powerMenuOpen
            }
        }

        // ---- layout.json: {"top": [{"id": ..., "on": true}, ...], "center": [...], "bottom": [...]} ----
        // Missing -> the default is written; broken -> the default is used and the file left alone; ids missing from the
        // file are added at their default spot (new icons appear after an update).
        readonly property var taskbarIcons: ({
            launcher: launcherButton, workspaces: wsPill, calendar: calendarButton, weather: weatherButton,
            performance: perfButton, media: mediaButton, tray: trayButton, wallpaper: wallpaperButton, timer: timerButton, notes: notesButton,
            recorder: recorderButton, network: wifiButton, bluetooth: btButton, brightness: brightnessButton,
            volume: volumeButton, notifications: notifButton, settings: settingsButton, power: powerButton
        })
        readonly property var defaultLayout: ({
            top: ["launcher", "workspaces"],
            center: ["calendar", "weather", "performance", "media"],
            bottom: ["tray", "wallpaper", "timer", "notes", "recorder", "network", "bluetooth", "brightness", "volume", "notifications", "settings", "power"]
        })
        property var layout: null       // the normalized layout currently applied

        function normaliseLayout(raw) {
            const out = { top: [], center: [], bottom: [] };
            const seen = {};
            for (const g of ["top", "center", "bottom"]) {
                // Array.from: a layout passed through a signal (the settings window) is a Qt sequence, not an Array.
                const list = raw && raw[g] && typeof raw[g] === "object" ? Array.from(raw[g]) : [];
                for (const e of list) {
                    const id = typeof e === "string" ? e : (e && e.id);
                    if (!id || !(id in bar.taskbarIcons) || seen[id])
                        continue;
                    seen[id] = true;
                    out[g].push({ id: id, on: typeof e === "object" && e.on === false ? false : true });
                }
            }
            for (const g of ["top", "center", "bottom"]) {
                const def = bar.defaultLayout[g];
                for (let k = 0; k < def.length; k++) {
                    const id = def[k];
                    if (seen[id])
                        continue;
                    seen[id] = true;
                    let at = out[g].length;
                    for (let n = k + 1; n < def.length; n++) {
                        const idx = out[g].findIndex(e => e.id === def[n]);
                        if (idx >= 0) {
                            at = idx;
                            break;
                        }
                    }
                    out[g].splice(at, 0, { id: id, on: true });
                }
            }
            return out;
        }
        function applyLayout(l) {
            bar.layout = l;
            bar.relayout();
        }
        // From the settings window: apply now, and save (the file watcher then re-reads the same layout).
        function saveLayout(l) {
            const n = bar.normaliseLayout(l);
            bar.applyLayout(n);
            layoutFile.setText(JSON.stringify(n, null, 2) + "\n");
        }
        // Top group from the top, bottom group from the bottom, center group centered between them, 7 px gaps. Hidden icons
        // (switched off, weather off, no brightness backend, no Bluetooth adapter, no network device) go to x -1000.
        function relayout() {
            const l = bar.layout;
            if (!l)
                return;
            const gap = 7;
            const shownIn = g => l[g].filter(e => e.on).map(e => bar.taskbarIcons[e.id])
                .filter(it => it !== weatherButton || Weather.enabled)
                .filter(it => it !== brightnessButton || brightness.backend !== "")
                .filter(it => it !== btButton || root.btAdapter !== null)
                .filter(it => it !== wifiButton || root.netDevices.length > 0);
            const place = (it, y) => {
                it.x = Math.round((bar.baseWidth - it.width) / 2);
                it.y = y;
            };
            for (const id in bar.taskbarIcons)
                bar.taskbarIcons[id].x = -1000;
            const top = shownIn("top"), c = shownIn("center"), bottom = shownIn("bottom");
            const all = top.concat(c, bottom);
            const needed = all.reduce((sum, it) => sum + it.height, 0) + gap * (all.length + 3);
            bar.fit = bar.height > 0 ? Math.min(1, bar.height / needed) : 1;
            const h = bar.height / bar.fit;     // the groups' unscaled height
            let y = gap;
            for (const it of top) {
                place(it, y);
                y += it.height + gap;
            }
            const topEnd = y;
            y = h - gap;
            for (const it of bottom.slice().reverse()) {
                y -= it.height;
                place(it, y);
                y -= gap;
            }
            const bottomStart = y;
            const total = c.reduce((sum, it) => sum + it.height, 0) + gap * Math.max(0, c.length - 1);
            y = Math.max(topEnd + gap, Math.min(Math.round((h - total) / 2), bottomStart - gap - total));
            for (const it of c) {
                place(it, y);
                y += it.height + gap;
            }
        }
        onHeightChanged: relayout()
        Connections {
            target: brightness
            function onBackendChanged() { bar.relayout(); }
        }
        // Hardware that can appear or vanish (USB Bluetooth dongle, NetworkManager starting late).
        Connections {
            target: root
            function onBtAdapterChanged() {
                if (root.btAdapter === null && popupHost.current === "bluetooth")
                    popupHost.close();
                bar.relayout();
            }
            function onNetDevicesChanged() { bar.relayout(); }
        }
        Connections {
            target: Weather
            function onEnabledChanged() {
                if (!Weather.enabled && popupHost.current === "weather")
                    popupHost.close();
                bar.relayout();
            }
        }
        Connections {
            target: wsPill
            function onHeightChanged() { bar.relayout(); }
        }

        function defaultLayoutJson() {
            const l = bar.normaliseLayout(null);
            return JSON.stringify(l, null, 2) + "\n";
        }

        FileView {
            id: layoutFile
            path: Config.dir + "/layout.json"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                let raw = null;
                try {
                    raw = JSON.parse(text());
                } catch (e) {
                    console.warn("taskbar layout: can't parse", path, "-", e, "- using the default layout");
                }
                bar.applyLayout(bar.normaliseLayout(raw));
            }
            printErrors: false      // a missing file on first start is normal; real read errors are reported below
            onLoadFailed: err => {
                bar.applyLayout(bar.normaliseLayout(null));
                // Only a missing file is written out.
                if (err === FileViewError.FileNotFound)
                    layoutDir.running = true;
                else
                    console.warn("taskbar layout: can't read", path, "- using the default layout (file left alone)");
            }
        }
        Process {
            id: layoutDir
            command: ["mkdir", "-p", Config.dir]
            // Writing the new file doesn't start watching it; reload() does, so later hand edits are seen.
            onExited: {
                layoutFile.setText(bar.defaultLayoutJson());
                layoutFile.reload();
            }
        }

        FileView {
            id: wallpaperState
            path: Config.stateDir + "/wallpaper"
            watchChanges: true
            printErrors: false      // no file until a wallpaper is first picked
            onLoaded: root.currentWallpaper = text().trim()
            onFileChanged: reload()
        }
    }
}
