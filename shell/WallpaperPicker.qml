import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Design after the wallpaper picker in JAQC-shell by MystiaFin (https://github.com/MystiaFin/JAQC-shell); no code taken
// (JAQC-shell has no license), written for CTS1.
// Wallpaper picker: a band across the screen over the blurred wallpaper, the folder as a carousel. Enter sets it
// through bin/wallpaper-set (awww transition, remembered, colors from the picture).
Scope {
    id: picker

    property bool open: false
    property string current: ""

    // Starts on the current wallpaper (the first picture if it isn't in the folder).
    function selectCurrent() {
        for (let i = 0; i < folder.count; i++) {
            if (folder.get(i, "filePath") === picker.current) {
                carousel.currentIndex = i;
                return;
            }
        }
        carousel.currentIndex = 0;
    }
    function apply() {
        if (folder.count === 0 || carousel.currentIndex < 0)
            return;
        Quickshell.execDetached([Quickshell.shellPath("bin/wallpaper-set"), folder.get(carousel.currentIndex, "filePath")]);
        picker.open = false;
    }
    onOpenChanged: if (open)
        selectCurrent()

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { picker.open = !picker.open; }
        function open(): void { picker.open = true; }
        function close(): void { picker.open = false; }
    }

    FolderListModel {
        id: folder
        folder: "file://" + Config.wallpaperFolder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready && picker.open)
            picker.selectCurrent()
    }

    PanelWindow {
        id: win
        visible: picker.open || band.opacity > 0.01
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: picker.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: picker.open = false
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                    carousel.decrementCurrentIndex();
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
                    carousel.incrementCurrentIndex();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    picker.apply();
                else if (event.key === Qt.Key_Escape)
                    picker.open = false;
                else
                    return;
                event.accepted = true;
            }
        }

        // The wallpaper at screen size, not drawn: the source of the blurred slice.
        Image {
            id: backdrop
            anchors.fill: parent
            source: picker.current !== "" ? "file://" + picker.current : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        Item {
            id: band
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.max(1, Math.min(380, parent.height - 72))
            clip: true
            opacity: picker.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            MouseArea {
                anchors.fill: parent    // clicks on the band itself must not close it
            }

            MultiEffect {
                y: -band.y
                width: win.width
                height: win.height
                source: backdrop
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
            }
            Rectangle {
                anchors.fill: parent
                color: Theme.m3surface
                opacity: 0.5
            }

            PathView {
                id: carousel
                anchors.fill: parent
                model: folder
                pathItemCount: 7
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 300
                snapMode: PathView.SnapOneItem

                readonly property real cardWidth: Math.min(384, win.width * 0.3, (band.height - 48) * 16 / 9)
                readonly property real cardHeight: cardWidth * 9 / 16

                // A line through the middle, a little past both edges; "prominence" is 1 at the center, 0 at the ends.
                path: Path {
                    startX: -carousel.width * 0.1
                    startY: carousel.height / 2
                    PathAttribute { name: "prominence"; value: 0 }
                    PathLine { x: carousel.width / 2; y: carousel.height / 2 }
                    PathAttribute { name: "prominence"; value: 1 }
                    PathLine { x: carousel.width * 1.1; y: carousel.height / 2 }
                    PathAttribute { name: "prominence"; value: 0 }
                }

                delegate: Item {
                    id: card
                    required property int index
                    required property string filePath
                    readonly property real prominence: PathView.prominence ?? 0
                    width: carousel.cardWidth
                    height: carousel.cardHeight
                    scale: 0.5 + 0.5 * prominence
                    z: prominence * 10

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.rounding.medium
                        color: Theme.m3surfaceContainer

                        Image {
                            anchors.fill: parent
                            source: "file://" + card.filePath
                            sourceSize: Qt.size(card.width * 2, card.height * 2)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: (1 - card.prominence) * 0.7
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: carousel.currentIndex = card.index
                    }
                }
            }

            StyledText {
                visible: folder.status === FolderListModel.Ready && folder.count === 0
                anchors.centerIn: parent
                text: "No wallpapers in " + Config.wallpaperFolder
                color: Theme.m3outline
            }
        }
    }
}
