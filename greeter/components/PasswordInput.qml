// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: login through Login.qml (greetd) instead of sddm.login, an empty password is not sent, SDDM's `config` -> Config (Config.qml).
pragma ComponentBehavior: Bound
import QtQuick
import qs

Rectangle {
    id: passwordRoot
    color: "transparent"

    property alias currentSession: inputRect.currentSession
    property alias currentUser: inputRect.currentUser
    property alias buffer: inputRect.buffer

    onBufferChanged: {
        while (dotModel.count < buffer.length)
            dotModel.append({
                shapeIdx: Math.floor(Math.random() * 3)
            });
        while (dotModel.count > buffer.length)
            dotModel.remove(dotModel.count - 1);
    }

    ListModel {
        id: dotModel
    }

    property alias isLoading: inputRect.isLoading
    property alias firstInput: inputRect.firstInput
    property alias mainCardComponentsOpacity: inputRect.mainCardComponentsOpacity

    function shake() {
        inputRect.shake();
    }

    Rectangle {
        id: inputRect

        property real mainCardComponentsOpacity
        property bool firstInput
        property bool isLoading
        property string buffer
        property string currentUser
        property int currentSession
        anchors.horizontalCenter: parent.horizontalCenter

        onIsLoadingChanged: {
            if (!inputRect.isLoading) {
                inputRect.width = 365;
            }
        }

        color: Config.subComponents
        radius: 6
        width: inputRect.buffer === "" ? 300 : 365
        height: 45
        opacity: inputRect.firstInput ? 0 : inputRect.mainCardComponentsOpacity

        Behavior on width {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutBack
            }
        }

        function shake() {
            shakeRotation.start();
        }

        Text {
            id: lockIcon
            renderType: Text.NativeRendering
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 17
            font.family: "Material Symbols Rounded"
            font.pointSize: 15
            text: "\ue897"
            color: '#a8a8a8'
            visible: !inputRect.isLoading
        }

        MorphShape {
            id: loadingShape
            readonly property var pairs: [Shapes.gemVerySunny, Shapes.verySunnyCookie4, Shapes.cookie4Gem]
            property int index: 2
            pair: pairs[index]
            progress: 1
            opacity: inputRect.isLoading ? 1 : 0
            color: Config.secondary

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 17

            size: lockIcon.height / 2 * 2.1

            NumberAnimation {
                id: morphAnim
                target: loadingShape
                property: "progress"
                from: 0
                to: 1
                duration: 350
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1] // Material 3 Expressive fast spatial (https://m3.material.io/styles/motion/overview/specs)
            }

            Timer {
                running: inputRect.isLoading
                interval: 500
                onTriggered: {
                    loadingShape.index = (loadingShape.index + 1) % loadingShape.pairs.length;
                    morphAnim.restart();
                    scaleAnim.running = true;
                }
                repeat: true
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
        }

        SequentialAnimation {
            id: scaleAnim

            running: false

            NumberAnimation {
                target: loadingShape
                property: "scale"
                to: 1.2
                duration: 100
            }
            NumberAnimation {
                target: loadingShape
                property: "scale"
                to: 1
                duration: 100
            }
        }

        SequentialAnimation {
            id: shakeRotation

            running: false

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: -6
                duration: 50
            }

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: 6
                duration: 50
            }

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: -4
                duration: 50
            }

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: 4
                duration: 50
            }

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: -2
                duration: 50
            }

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: 2
                duration: 50
            }

            NumberAnimation {
                target: inputRect
                property: "rotation"
                to: 0
                duration: 50
            }
        }

        SequentialAnimation {
            id: pulseColorRect1

            running: inputRect.isLoading

            NumberAnimation {
                target: inputRect
                property: "width"
                to: 300
                duration: 300
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            id: inputBorders

            anchors.centerIn: parent
            color: "transparent"
            radius: 30
            width: 250
            height: 40
            clip: true

            Text {
                renderType: Text.NativeRendering
                anchors.centerIn: parent
                font.pointSize: 12
                text: inputRect.isLoading ? "Loading..." : "Enter your password"
                color: '#6e6e6e'
                font.family: "Rubik"
                opacity: inputRect.buffer === "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            ListView {
                id: dots

                orientation: ListView.Horizontal
                spacing: 3
                interactive: false

                width: inputRect.buffer.length * 15 + (inputRect.buffer.length - 1) * 3 + parent.height
                height: 15
                anchors.centerIn: parent

                model: dotModel

                Behavior on width {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Item {
                    id: dot

                    required property int shapeIdx

                    width: 15
                    height: 15
                    scale: 0
                    opacity: 0

                    readonly property var pairs: [Shapes.gemCircle, Shapes.verySunnyCircle, Shapes.cookie4Circle]
                    property real morphProgress: 0

                    MorphShape {
                        size: dot.width
                        pair: dot.pairs[dot.shapeIdx]
                        progress: dot.morphProgress
                        color: "white"
                    }

                    SequentialAnimation {
                        id: initAnim
                        running: true

                        ParallelAnimation {
                            NumberAnimation {
                                target: dot
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 150
                            }
                            SequentialAnimation {
                                NumberAnimation {
                                    target: dot
                                    property: "scale"
                                    from: 0
                                    to: 1.4
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: dot
                                    property: "scale"
                                    to: 1
                                    duration: 150
                                }
                            }
                        }
                        PauseAnimation {
                            duration: 180
                        }
                        NumberAnimation {
                            target: dot
                            property: "morphProgress"
                            from: 0
                            to: 1
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }

                    ListView.onRemove: {
                        initAnim.stop();
                        removeAnim.start();
                    }

                    SequentialAnimation {
                        id: removeAnim

                        PropertyAction {
                            target: dot
                            property: "ListView.delayRemove"
                            value: true
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: dot
                                property: "opacity"
                                to: 0
                                duration: 150
                            }
                            NumberAnimation {
                                target: dot
                                property: "scale"
                                to: 0
                                duration: 150
                                easing.type: Easing.InCubic
                            }
                        }
                        PropertyAction {
                            target: dot
                            property: "ListView.delayRemove"
                            value: false
                        }
                    }
                }
            }
        }

        Rectangle {
            id: inputButtonShape

            radius: 48
            width: inputRect.height - 7
            height: inputRect.height - 7
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 4
            color: "transparent"

            // Empty: a square with 6 px corners (at 0.9 scale); typing: the arrow.
            MorphShape {
                id: shape
                rotation: 90
                scale: inputRect.buffer === "" ? 0.9 : 0.7
                size: inputButtonShape.height / 2 * 2.1
                pair: Shapes.squareArrow
                progress: inputRect.buffer === "" ? 0 : 1
                color: inputRect.buffer === "" ? Config.inverseOnSurface : Config.secondary
                y: -1

                Text {
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    font.family: "Material Symbols Rounded"
                    font.pointSize: 24
                    rotation: -90
                    text: "\ue941"
                    color: Config.text
                    opacity: inputRect.buffer === "" ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on progress {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1] // Material 3 Expressive fast spatial (https://m3.material.io/styles/motion/overview/specs)
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: inputRect.buffer === "" ? false : true
                    onEntered: {
                        shape.scale = 0.8;
                    }
                    onExited: {
                        shape.scale = 0.7;
                    }
                    onClicked: {
                        if (inputRect.buffer === "")
                            return;     // pam_faillock counts every attempt
                        Login.login(inputRect.currentUser, inputRect.buffer, inputRect.currentSession);
                        inputRect.isLoading = true;
                        inputRect.buffer = "";
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutBack
            }
        }
    }
}
