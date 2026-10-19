import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Settings window (Super+I): taskbar icons (shown, group, order), weather, mode, wallpaper folder. It edits a COPY
// of the layout and hands it back through `changed` (the bar applies and saves it). Rows are rebuilt on every change,
// so no state lives in a row.
Scope {
    id: settings

    property bool open: false
    property var layout: null                   // {top: [{id, on}], center: [...], bottom: [...]}
    property var labels: ({})                   // id -> {name, icon}
    signal changed(var newLayout)

    readonly property var groups: [
        { key: "top", title: "Top" },
        { key: "center", title: "Center" },
        { key: "bottom", title: "Bottom" }
    ]
    readonly property var weatherModes: [
        { key: "off", title: "Off" },
        { key: "city", title: "City" },
        { key: "auto", title: "Automatic" }
    ]
    // Kept in step with Weather.qml's header.
    readonly property var weatherNotes: ({
        off: "No weather requests are made, and the weather icon is hidden.",
        city: "Sends the city name to open-meteo.com to find it, then asks open-meteo.com for the forecast every 15 minutes.",
        auto: "Asks ipinfo.io for an approximate location from your IP address (often only your internet provider's city), then asks open-meteo.com for the forecast every 15 minutes."
    })

    IpcHandler {
        target: "settings"
        function toggle(): void { settings.open = !settings.open; }
        function open(): void { settings.open = true; }
        function close(): void { settings.open = false; }
    }

    function copy() {
        return JSON.parse(JSON.stringify(layout));
    }
    function move(g, i, d) {
        const l = copy();
        const j = i + d;
        if (j < 0 || j >= l[g].length)
            return;
        [l[g][i], l[g][j]] = [l[g][j], l[g][i]];
        changed(l);
    }
    function setGroup(g, i, ng) {
        if (g === ng)
            return;
        const l = copy();
        const e = l[g].splice(i, 1)[0];
        l[ng].push(e);
        changed(l);
    }
    function setOn(g, i, on) {
        const l = copy();
        l[g][i].on = on;
        changed(l);
    }

    PanelWindow {
        visible: settings.open || panel.opacity > 0.01
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: settings.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: settings.open = false
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: settings.open = false
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: 500
            height: Math.min(content.implicitHeight + Theme.padding.large * 2, parent.height - 80)
            radius: 6
            color: Theme.m3surface
            border.color: Theme.m3outlineVariant
            border.width: 1
            opacity: settings.open ? 1 : 0
            scale: settings.open ? 1 : 0.95
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent    // clicks on the panel itself must not close it
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.padding.large
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content
                    width: parent.width
                    spacing: Theme.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon {
                            text: "settings"
                            font.pixelSize: 22
                            color: Theme.m3primary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "CTS1 settings"
                            color: Theme.m3onSurface
                            font.pixelSize: Theme.fontSize.large
                            font.bold: true
                        }
                    }
                    StyledText {
                        text: "Taskbar icons: show or hide, reorder, and pick their group."
                        color: Theme.m3outline
                        font.pixelSize: Theme.fontSize.small
                    }

                    Repeater {
                        model: settings.groups

                        ColumnLayout {
                            id: section
                            required property var modelData
                            readonly property string key: modelData.key
                            readonly property var entries: settings.layout ? settings.layout[key] : []
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacing.small
                            spacing: 4

                            StyledText {
                                text: section.modelData.title
                                color: Theme.m3primary
                                font.pixelSize: Theme.fontSize.normal
                                font.bold: true
                            }
                            StyledText {
                                visible: section.entries.length === 0
                                text: "No icons here"
                                color: Theme.m3outline
                                font.pixelSize: Theme.fontSize.small
                            }

                            Repeater {
                                model: section.entries

                                Rectangle {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    readonly property var label: settings.labels[modelData.id] ?? { name: modelData.id, icon: "help" }
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    radius: 6
                                    color: Theme.m3surfaceContainer
                                    opacity: modelData.on ? 1 : 0.55

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        MaterialIcon {
                                            text: row.label.icon
                                            font.pixelSize: 18
                                            color: Theme.m3primary
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: row.label.name
                                            color: Theme.m3onSurface
                                            elide: Text.ElideRight
                                        }
                                        IconButton {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            iconSize: 16
                                            icon: "arrow_upward"
                                            disabled: row.index === 0
                                            onClicked: settings.move(section.key, row.index, -1)
                                        }
                                        IconButton {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            iconSize: 16
                                            icon: "arrow_downward"
                                            disabled: row.index === section.entries.length - 1
                                            onClicked: settings.move(section.key, row.index, 1)
                                        }

                                        Row {
                                            spacing: 2
                                            Repeater {
                                                model: settings.groups
                                                Rectangle {
                                                    required property var modelData
                                                    readonly property bool current: modelData.key === section.key
                                                    width: 50
                                                    height: 24
                                                    radius: 6
                                                    color: current ? Theme.m3primary
                                                         : segArea.containsMouse ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh
                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: parent.modelData.title
                                                        color: parent.current ? Theme.m3onPrimary : Theme.m3onSurfaceVariant
                                                        font.pixelSize: Theme.fontSize.small
                                                    }
                                                    MouseArea {
                                                        id: segArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: settings.setGroup(section.key, row.index, parent.modelData.key)
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 40
                                            height: 22
                                            radius: 11
                                            color: row.modelData.on ? Theme.m3primary : Theme.m3surfaceContainerHigh
                                            border.width: row.modelData.on ? 0 : 1
                                            border.color: Theme.m3outline
                                            Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: row.modelData.on ? parent.width - width - 3 : 3
                                                color: row.modelData.on ? Theme.m3onPrimary : Theme.m3outline
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: settings.setOn(section.key, row.index, !row.modelData.on)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: weatherSection
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.large
                        spacing: 6

                        StyledText {
                            text: "Weather"
                            color: Theme.m3primary
                            font.pixelSize: Theme.fontSize.normal
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Row {
                                spacing: 2
                                Repeater {
                                    model: settings.weatherModes
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool current: modelData.key === Config.weather.mode
                                        width: 90
                                        height: 26
                                        radius: 6
                                        color: current ? Theme.m3primary
                                             : modeArea.containsMouse ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: parent.modelData.title
                                            color: parent.current ? Theme.m3onPrimary : Theme.m3onSurfaceVariant
                                            font.pixelSize: Theme.fontSize.small
                                        }
                                        MouseArea {
                                            id: modeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: Config.weather.mode = parent.modelData.key
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Row {
                                visible: Weather.enabled
                                spacing: 2
                                Repeater {
                                    model: [{ c: true, title: "°C" }, { c: false, title: "°F" }]
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool current: modelData.c === Config.weather.celsius
                                        width: 50
                                        height: 24
                                        radius: 6
                                        color: current ? Theme.m3primary
                                             : unitArea.containsMouse ? Theme.m3surfaceContainerHighest : Theme.m3surfaceContainerHigh
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: parent.modelData.title
                                            color: parent.current ? Theme.m3onPrimary : Theme.m3onSurfaceVariant
                                            font.pixelSize: Theme.fontSize.small
                                        }
                                        MouseArea {
                                            id: unitArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: Config.weather.celsius = parent.modelData.c
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: settings.weatherNotes[Config.weather.mode] ?? ""
                            color: Theme.m3outline
                            font.pixelSize: Theme.fontSize.small
                            wrapMode: Text.WordWrap
                        }

                        // Saved (and looked up) on Enter or focus loss.
                        Rectangle {
                            visible: Config.weather.mode === "city"
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 6
                            color: Theme.m3surfaceContainer
                            border.width: cityInput.activeFocus ? 1 : 0
                            border.color: Theme.m3primary

                            TextInput {
                                id: cityInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.m3onSurface
                                selectionColor: Theme.m3primaryContainer
                                font.family: Theme.sans
                                font.pixelSize: Theme.fontSize.normal
                                clip: true
                                text: Config.weather.city
                                onEditingFinished: Config.weather.city = text.trim()
                                Keys.onEscapePressed: settings.open = false

                                StyledText {
                                    visible: cityInput.text === "" && !cityInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "City name, then Enter"
                                    color: Theme.m3outline
                                }
                            }
                            // Reopening shows the saved city, not a half-typed one.
                            Connections {
                                target: settings
                                function onOpenChanged() {
                                    if (settings.open)
                                        cityInput.text = Config.weather.city;
                                }
                            }
                        }

                        StyledText {
                            visible: Weather.enabled
                            Layout.fillWidth: true
                            text: Weather.city !== "" ? "Showing: " + Weather.city : Weather.description
                            color: Weather.error !== "" ? Theme.m3error : Theme.m3onSurfaceVariant
                            font.pixelSize: Theme.fontSize.small
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.large
                        spacing: 6

                        StyledText {
                            text: "Mode"
                            color: Theme.m3primary
                            font.pixelSize: Theme.fontSize.normal
                            font.bold: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: "Light mode"
                                color: Theme.m3onSurface
                            }
                            // A click saves the other mode and remakes the scheme from the current wallpaper.
                            Rectangle {
                                readonly property bool on: Theme.light
                                width: 40
                                height: 22
                                radius: 11
                                color: on ? Theme.m3primary : Theme.m3surfaceContainerHigh
                                border.width: on ? 0 : 1
                                border.color: Theme.m3outline
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.on ? parent.width - width - 3 : 3
                                    color: parent.on ? Theme.m3onPrimary : Theme.m3outline
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Theme.toggleMode()
                                }
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Taskbar, popups, lock and login screen. The colors still come from the wallpaper; apps stay dark."
                            color: Theme.m3outline
                            font.pixelSize: Theme.fontSize.small
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.large
                        spacing: 6

                        StyledText {
                            text: "Wallpaper"
                            color: Theme.m3primary
                            font.pixelSize: Theme.fontSize.normal
                            font.bold: true
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Folder the taskbar's wallpaper picker shows. Empty = ~/Pictures/Wallpapers. Needs awww."
                            color: Theme.m3outline
                            font.pixelSize: Theme.fontSize.small
                            wrapMode: Text.WordWrap
                        }
                        // Saved on Enter or focus loss.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 6
                            color: Theme.m3surfaceContainer
                            border.width: folderInput.activeFocus ? 1 : 0
                            border.color: Theme.m3primary

                            TextInput {
                                id: folderInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.m3onSurface
                                selectionColor: Theme.m3primaryContainer
                                font.family: Theme.sans
                                font.pixelSize: Theme.fontSize.normal
                                clip: true
                                text: Config.wallpaper.folder
                                onEditingFinished: Config.wallpaper.folder = text.trim()
                                Keys.onEscapePressed: settings.open = false

                                StyledText {
                                    visible: folderInput.text === "" && !folderInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "~/Pictures/Wallpapers"
                                    color: Theme.m3outline
                                }
                            }
                            Connections {
                                target: settings
                                function onOpenChanged() {
                                    if (settings.open)
                                        folderInput.text = Config.wallpaper.folder;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
