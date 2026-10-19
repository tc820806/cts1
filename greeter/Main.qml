// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: runs under greetd/Quickshell (login, users and sessions from Login.qml, SDDM's `config` -> Config (Config.qml)),
// the calendar (left middle) and the hardware monitor (right column) replace the fetch, resources and dino cards,
// the wallpaper comes from Config, an empty password is not sent, and Tab moves between the password and the power buttons.
import Qt5Compat.GraphicalEffects
import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "widgets"

Rectangle {
    id: root

    property bool ap: Config.ap === "true" ? true : false
    property bool sessionPickerEnabled: Config.sessionPicker === "true" ? true : false
    property bool welcomeMessageEnabled: Config.enableWelcomeMessage !== "false"
    property bool firstInput: welcomeMessageEnabled
    property bool loading: false
    property string buffer
    property real welcomeBgBlurAmount: parseFloat(Config.welcomeBgBlurAmount) || 1
    property bool welcomeBgBlur: Config.welcomeBgBlur === "true"
    property real mainCardBlurAmount: parseFloat(Config.mainCardBlurAmount) || 1
    property real mainCardComponentsOpacity: {
        const value = parseFloat(Config.mainCardComponentsOpacity);
        if (isNaN(value) || value < 0.6)
            return 1;

        return value;
    }
    property bool capsLockOn: false
    property bool mainCardBgBlur: Config.mainCardBgBlur === "true"
    readonly property int sessionIndex: sessionPickerBtn.selectedIndex
    property real midRadius: mainCard.radius / 1.4

    width: 1920
    height: 1080
    color: "#131313"

    Connections {
        function onLoginFailed() {
            root.buffer = "";
            root.loading = false;
            inputRect.color = Config.subComponents;
            inputRect.shake();
        }

        function onLoginSucceeded() {
            root.loading = false;
            inputRect.color = Config.subComponents;
        }

        target: Login
    }

    AnimatedImage {
        id: background

        anchors.fill: parent
        source: Config.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            if (status === Image.Error)
                console.log("Background missing, using fallback color");
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.firstInput ? 0 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }

    Item {
        id: keylogger

        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (root.welcomeMessageEnabled)
                    root.firstInput = true;

                root.buffer = "";
                systemButtons.kbIndex = -1;
                return;
            }
            if (event.key === Qt.Key_CapsLock) {
                root.capsLockOn = !root.capsLockOn;
                return;
            }
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                event.accepted = true;      // otherwise Qt moves the keyboard focus away from this handler
                if (!root.firstInput)
                    systemButtons.kbIndex = systemButtons.kbIndex < 0 ? 0 : -1;
                return;
            }

            if (root.firstInput) {
                root.firstInput = false;
                return;
            }
            // On the power buttons Left/Right move, Enter presses; any other key leaves them, so a typed password and its Enter
            // never reach a button.
            if (systemButtons.kbIndex >= 0) {
                const n = systemButtons.buttons.length;
                if (event.key === Qt.Key_Right) {
                    systemButtons.kbIndex = (systemButtons.kbIndex + 1) % n;
                    return;
                }
                if (event.key === Qt.Key_Left) {
                    systemButtons.kbIndex = (systemButtons.kbIndex + n - 1) % n;
                    return;
                }
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    systemButtons.press(systemButtons.kbIndex);
                    return;
                }
                if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
                    return;     // a lone modifier (e.g. Shift for Shift+Tab) stays on the buttons
                systemButtons.kbIndex = -1;
            }
            if (event.key === Qt.Key_Right) {
                if (userPicker.currentIndex < Login.users.count - 1)
                    userPicker.currentIndex += 1;

                return;
            }
            if (event.key === Qt.Key_Left) {
                if (userPicker.currentIndex > 0)
                    userPicker.currentIndex -= 1;

                return;
            }
            if (event.key === Qt.Key_Up) {
                if (sessionPickerBtn.selectedIndex < sessionPickerBtn.count - 1)
                    sessionPickerBtn.selectedIndex += 1;

                return;
            }
            if (event.key === Qt.Key_Down) {
                if (sessionPickerBtn.selectedIndex > 0)
                    sessionPickerBtn.selectedIndex -= 1;

                return;
            }
            if (event.key === Qt.Key_Backspace) {
                root.buffer = root.buffer.slice(0, -1);
                return;
            }
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                // An empty password would only count toward pam_faillock's lockout.
                if (root.buffer === "")
                    return;
                Login.login(userPicker.currentText, root.buffer, root.sessionIndex);
                root.buffer = "";
                root.loading = true;
                return;
            }
            root.buffer += event.text;
        }
    }

    MultiEffect {
        blurEnabled: true
        source: background
        blur: root.firstInput ? 0 : 1
        autoPaddingEnabled: false
        blurMultiplier: 1
        blurMax: 64
        anchors.fill: background

        Behavior on blur {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutCubic
            }
        }
    }

    Greeting {
        anchors.centerIn: parent
        firstInput: root.firstInput
        mainCardRadius: root.midRadius
        rootHeight: root.height
        rootWidth: root.width
        greetingText: greeting.welcomeString
        username: userPicker.currentText
        blurAmount: root.welcomeBgBlurAmount
        blurEnabled: root.welcomeBgBlur
    }

    Rectangle {
        id: mainCard

        property date currentTime: new Date()
        property string day: Qt.formatDateTime(currentTime, "dddd").toUpperCase()
        property string date: Qt.formatDateTime(currentTime, "d MMM").toUpperCase()
        readonly property var fontAxesTitle: ({
                "wght": 500,
                "wdth": 70,
                "ROND": 25,
                "opsz": 224
            })

        width: 1350
        height: 750
        scale: root.firstInput ? 0.5 : 1
        opacity: root.firstInput ? 0 : 1
        anchors.centerIn: parent
        radius: 70
        color: "transparent"

        BlurWrapper {
            anchors.centerIn: parent
            targetWidth: mainCard.width
            targetHeight: mainCard.height
            animDuration: 0
            blurAmount: root.mainCardBlurAmount
            bgColor: Config.mainCard
            visibleState: !root.firstInput
            radius: 6
        }

        MainClock {
            anchors.horizontalCenter: mainCard.horizontalCenter
            anchors.horizontalCenterOffset: 10
            anchors.top: mainCard.top
            anchors.topMargin: 150
            firstInput: root.firstInput
            mainCardComponentsOpacity: root.mainCardComponentsOpacity
            ap: root.ap
        }

        FontLoader {
            id: googleSansFlex

            source: "assets/google-sans-flex/GoogleSansFlex.ttf"
        }

        Text {
            anchors.horizontalCenter: mainCard.horizontalCenter
            anchors.top: mainCard.top
            anchors.topMargin: 267
            anchors.bottom: parent.bottom
            color: Config.text
            text: mainCard.day + " • " + mainCard.date
            font.pixelSize: 22
            font.family: googleSansFlex.name
            font.bold: true
            font.variableAxes: mainCard.fontAxesTitle
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 40

            ColumnLayout {
                spacing: 13
                Layout.alignment: Qt.AlignLeft

                Rectangle {
                    id: topLeftRect

                    width: 390
                    height: 220
                    color: Config.subComponents
                    radius: 6
                    opacity: root.firstInput ? 0 : root.mainCardComponentsOpacity
                    clip: true

                    WelcomeText {
                        id: greeting

                        anchors.centerIn: parent
                        username: userPicker.currentText
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }
                }

                Rectangle {
                    id: middleLeftRect

                    width: 390
                    Layout.fillHeight: true
                    color: Config.subComponents
                    radius: 6
                    opacity: root.firstInput ? 0 : root.mainCardComponentsOpacity
                    clip: true

                    CalendarCard {
                        anchors.fill: parent
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }
                }

                Rectangle {
                    id: bottomLeftRect

                    width: 390
                    height: 190
                    color: "transparent"
                    radius: 6
                    opacity: root.firstInput ? 0 : root.mainCardComponentsOpacity

                    SystemButtons {
                        id: systemButtons

                        anchors.horizontalCenter: parent.horizontalCenter
                        rectHeight: bottomLeftRect.height
                        rectWidth: bottomLeftRect.height - 1
                        rectRadius: bottomLeftRect.radius
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    color: "transparent"
                    width: 300
                    height: 140
                }

                Item {
                    height: 65
                }

                Avatar {
                    currentUserIndex: userPicker.currentIndex
                    userModel: Login.users
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 330
                    Layout.preferredHeight: 260
                    Layout.bottomMargin: 20
                    opacity: root.firstInput ? 0 : root.mainCardComponentsOpacity

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }
                }

                PasswordInput {
                    id: inputRect

                    Layout.alignment: Qt.AlignHCenter
                    mainCardComponentsOpacity: root.mainCardComponentsOpacity
                    firstInput: root.firstInput
                    isLoading: root.loading
                    buffer: root.buffer
                    currentUser: userPicker.currentText
                    currentSession: root.sessionIndex
                }

                // Sets where the centered column sits.
                Item {
                    Layout.preferredHeight: 55
                }
            }

            // Hardware monitor, in the place and size of the old resources and dino cards (390 x 723).
            PerfColumn {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 390
                Layout.preferredHeight: 723
                opacity: root.firstInput ? 0 : root.mainCardComponentsOpacity

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        }

        SessionPicker {
            id: sessionPickerBtn

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: mainCard.height - 100
            selectedIndex: Login.lastSessionIndex
            opacity: root.firstInput ? 0 : root.mainCardComponentsOpacity
            visible: root.sessionPickerEnabled

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutBack
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutBack
            }
        }
    }

    ComboBox {
        id: userPicker

        width: 190
        height: 50
        anchors.right: parent.right
        anchors.top: parent.top
        model: Login.users
        currentIndex: Login.lastUserIndex
        textRole: "name"
        font.family: "Rubik"
        font.pixelSize: 20
        visible: false

        background: Rectangle {
            color: "#BF131313"
            radius: 30
            border.color: "#353535"
            border.width: 1
        }

        contentItem: Text {
            renderType: Text.NativeRendering
            text: userPicker.displayText
            font: userPicker.font
            color: "#e2e2e2"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            anchors.fill: parent
        }

        indicator: Canvas {
            x: userPicker.width - 30
            y: (userPicker.height - 6) / 2
            width: 12
            height: 6
            onPaint: {
                var context = getContext("2d");
                context.reset();
                context.moveTo(0, 0);
                context.lineTo(width, 0);
                context.lineTo(width / 2, height);
                context.closePath();
                context.fillStyle = "#4cdadb";
                context.fill();
            }
        }
    }
}
