// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: users from Login.qml instead of SDDM's userModel (avatar: ~/.face, ~/.face.icon, AccountsService), SDDM's `config` -> Config (Config.qml).
pragma ComponentBehavior: Bound
import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    z: 2

    // OpacityMask shape: 6 px corners.
    Rectangle {
        id: rectMask
        anchors.fill: parent
        radius: 6
        color: "#000000"
    }

    property int currentUserIndex: 0
    property var userModel: null

    Image {
        id: avatarImage

        property var avatarCandidates: ["../assets/avatar.png"]
        property int avatarCandidateIndex: 0

        function toSourceUrl(pathOrUrl) {
            if (!pathOrUrl || pathOrUrl === "")
                return "";
            var value = String(pathOrUrl);
            if (value.startsWith("file://") || value.startsWith("qrc:/") || value.startsWith(":/"))
                return value;
            if (value.startsWith("/"))
                return "file://" + value;
            return value;
        }

        function appendCandidate(list, value) {
            var normalized = toSourceUrl(value);
            if (normalized !== "" && list.indexOf(normalized) === -1)
                list.push(normalized);
        }

        function rebuildAvatarCandidates() {
            var list = [];
            // {name, realName, home}. ~/.face is what Caelestia uses; the AccountsService icon what other display managers use.
            if (root.userModel && root.currentUserIndex >= 0 && root.currentUserIndex < root.userModel.count) {
                var user = root.userModel.get(root.currentUserIndex);
                appendCandidate(list, user.home + "/.face");
                appendCandidate(list, user.home + "/.face.icon");
                appendCandidate(list, "/var/lib/AccountsService/icons/" + user.name);
            }
            appendCandidate(list, "../assets/avatar.face.icon");
            appendCandidate(list, "../assets/avatar.face");
            appendCandidate(list, "../assets/avatar.png");
            avatarCandidates = list;
            avatarCandidateIndex = 0;
        }

        source: avatarCandidateIndex < avatarCandidates.length ? avatarCandidates[avatarCandidateIndex] : ""
        mipmap: true
        smooth: true
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        onStatusChanged: {
            if (status === Image.Error && avatarCandidateIndex < avatarCandidates.length - 1)
                avatarCandidateIndex += 1;
        }
        Component.onCompleted: rebuildAvatarCandidates()

        Connections {
            target: root

            function onCurrentUserIndexChanged() {
                avatarImage.rebuildAvatarCandidates();
            }
        }

        Connections {
            target: root.userModel

            function onCountChanged() {
                avatarImage.rebuildAvatarCandidates();
            }
        }

        layer.effect: OpacityMask {
            maskSource: rectMask
        }
    }
}
