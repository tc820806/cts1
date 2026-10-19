import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Notes window (Super+N): one .txt per note in Config.notesFolder, title = first line. The folder is re-read on
// every open (hand edits show up). Autosave 500 ms after typing and on switch/close; a new note gets a file
// (named by its creation time) only once typed in. Delete needs a second click within 4 s.
Scope {
    id: win

    property bool open: false
    property var notes: []          // [{ name, mtime, text }], newest first
    property string current: ""     // file name of the note being edited; "" = none
    property string query: ""
    property bool dirty: false
    property bool deleteArmed: false

    readonly property var shown: {
        const q = win.query.trim().toLowerCase();
        return q === "" ? win.notes : win.notes.filter(n => n.text.toLowerCase().includes(q));
    }

    function titleOf(text: string): string {
        const first = text.split("\n")[0].trim();
        return first === "" ? "Untitled" : first;
    }
    function noteNamed(name: string): var {
        return win.notes.find(n => n.name === name) || null;
    }

    IpcHandler {
        target: "notes"
        function toggle(): void { win.open = !win.open; }
        function open(): void { win.open = true; }
        function close(): void { win.open = false; }
    }

    onOpenChanged: {
        if (open) {
            query = "";
            deleteArmed = false;
            lister.running = true;
        } else {
            win.flush();
        }
    }

    // Lists the folder (made if missing) as one JSON array of {name, mtime, text}.
    Process {
        id: lister
        command: ["sh", "-c", "mkdir -p \"$1\" && cd \"$1\" && for f in *.txt; do [ -f \"$f\" ] || continue; jq -Rs --arg n \"$f\" --argjson t \"$(stat -c %Y \"$f\")\" '{name: $n, mtime: $t, text: .}' < \"$f\"; done | jq -s 'sort_by(-.mtime)'", "sh", Config.notesFolder]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                win.notes = Array.isArray(list) ? list : [];
                win.select(win.noteNamed(win.current) ? win.current : (win.notes.length ? win.notes[0].name : ""));
            }
        }
    }
    // blockWrites: a save always lands before switching notes.
    FileView {
        id: file
        blockWrites: true
        printErrors: false
    }
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: win.flush()
    }
    Process {
        id: remover
    }

    function flush(): void {
        saveTimer.stop();
        if (!dirty || current === "")
            return;
        const n = noteNamed(current);
        if (n) {
            file.path = Config.notesFolder + "/" + current;
            file.setText(n.text);
        }
        dirty = false;
    }
    function select(name: string): void {
        flush();
        current = name;
        deleteArmed = false;
        const n = noteNamed(name);
        editor.text = n ? n.text : "";
        editor.cursorPosition = editor.length;
    }
    function newNote(): void {
        flush();
        const name = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".txt";
        if (!noteNamed(name))
            notes = [{ name: name, mtime: Date.now() / 1000, text: "", fresh: true }].concat(notes);
        query = "";
        select(name);
        editor.forceActiveFocus();
    }
    function deleteCurrent(): void {
        const n = noteNamed(current);
        if (!n)
            return;
        saveTimer.stop();
        dirty = false;
        if (!n.fresh) {
            remover.command = ["rm", "-f", "--", Config.notesFolder + "/" + n.name];
            remover.running = true;
        }
        const left = notes.filter(x => x.name !== n.name);
        notes = left;
        current = "";
        select(left.length ? left[0].name : "");
    }
    function edited(text: string): void {
        const n = noteNamed(current);
        if (!n || n.text === text)
            return;
        // Replace the entry (not change it in place), so the list's titles update.
        notes = notes.map(x => x.name === current ? { name: x.name, mtime: Date.now() / 1000, text: text } : x);
        dirty = true;
        saveTimer.restart();
    }

    PanelWindow {
        visible: win.open || panel.opacity > 0.01
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "cts1-notes"
        WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: win.open = false
        }
        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.open = false
        }
        Connections {
            target: win
            function onOpenChanged() {
                if (win.open)
                    editor.forceActiveFocus();
            }
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: 780
            height: 500
            radius: 6
            color: Theme.m3surface
            border.color: Theme.m3outlineVariant
            border.width: 1
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.95
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent    // clicks on the panel itself must not close it
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding.large
                spacing: Theme.spacing.medium

                ColumnLayout {
                    Layout.preferredWidth: 240
                    Layout.maximumWidth: 240
                    Layout.fillWidth: false     // its fill-width children would otherwise make it take the editor's room
                    Layout.fillHeight: true
                    spacing: Theme.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon {
                            text: "sticky_note_2"
                            font.pixelSize: 22
                            color: Theme.m3primary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Notes"
                            color: Theme.m3onSurface
                            font.pixelSize: Theme.fontSize.large
                            font.bold: true
                        }
                        IconButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            iconSize: 20
                            tonal: true
                            icon: "add"
                            onClicked: win.newNote()
                        }
                        IconButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            iconSize: 20
                            icon: "delete"
                            danger: win.deleteArmed
                            disabled: win.current === ""
                            onClicked: {
                                if (win.deleteArmed) {
                                    win.deleteCurrent();
                                } else {
                                    win.deleteArmed = true;
                                    disarm.restart();
                                }
                            }
                            Timer {
                                id: disarm
                                interval: 4000
                                onTriggered: win.deleteArmed = false
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        color: Theme.m3surfaceContainerHigh
                        border.width: search.activeFocus ? 1 : 0
                        border.color: Theme.m3primary

                        MaterialIcon {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            font.pixelSize: 18
                            color: Theme.m3outline
                        }
                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 6
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.m3onSurface
                            selectionColor: Theme.m3primaryContainer
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSize.normal
                            clip: true
                            text: win.query
                            onTextEdited: win.query = text
                            Keys.onEscapePressed: win.open = false

                            StyledText {
                                visible: search.text === "" && !search.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search"
                                color: Theme.m3outline
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: win.shown
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: item
                            required property var modelData
                            readonly property bool selected: modelData.name === win.current
                            width: ListView.view.width
                            height: 50
                            radius: 6
                            color: selected ? Theme.m3primaryContainer : itemArea.containsMouse ? Theme.m3surfaceContainerHigh : Theme.m3surfaceContainer

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 2
                                StyledText {
                                    width: parent.width
                                    text: win.titleOf(item.modelData.text)
                                    elide: Text.ElideRight
                                    color: item.selected ? Theme.m3onPrimaryContainer : Theme.m3onSurface
                                    font.bold: true
                                }
                                StyledText {
                                    width: parent.width
                                    text: Qt.formatDateTime(new Date(item.modelData.mtime * 1000), "ddd MMM d  hh:mm")
                                    elide: Text.ElideRight
                                    color: item.selected ? Theme.m3onPrimaryContainer : Theme.m3outline
                                    font.pixelSize: Theme.fontSize.small
                                }
                            }
                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.select(item.modelData.name);
                                    editor.forceActiveFocus();
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: win.notes.length === 0 ? "No notes yet" : "Nothing found"
                            color: Theme.m3outline
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: Theme.m3surfaceContainer

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: editor.contentHeight
                        boundsBehavior: Flickable.StopAtBounds
                        function follow(r) {
                            if (r.y < contentY)
                                contentY = r.y;
                            else if (r.y + r.height > contentY + height)
                                contentY = r.y + r.height - height;
                        }

                        TextEdit {
                            id: editor
                            width: flick.width
                            height: Math.max(flick.height, contentHeight)
                            enabled: win.current !== ""
                            wrapMode: TextEdit.Wrap
                            color: Theme.m3onSurface
                            selectionColor: Theme.m3primaryContainer
                            selectedTextColor: Theme.m3onPrimaryContainer
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSize.normal
                            selectByMouse: true
                            textFormat: TextEdit.PlainText
                            onTextChanged: win.edited(text)
                            onCursorRectangleChanged: flick.follow(cursorRectangle)
                            Keys.onEscapePressed: win.open = false
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        visible: win.current === ""
                        text: "Click + for a new note"
                        color: Theme.m3outline
                    }
                }
            }
        }
    }
}
