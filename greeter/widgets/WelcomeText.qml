// From aroa's Caelestia SDDM theme in ladybug-me's caelestia-kde (https://github.com/ladybug-me/caelestia-kde, src/sddm, GPL-3.0-or-later).
// Changed for CTS1: SDDM's `config` -> Config (Config.qml), greeting hours (morning 4-12, afternoon 12-15, evening 15-21, night 21-4).
import QtQuick
import qs

Item {
    id: topLeftRect

    property string welcomeString
    property string username

    function getPhase() {
        var now = new Date();
        var hour = now.getHours();
        if (hour >= 21 || hour < 4)
            welcomeString = "Good night";
        else if (hour < 12)
            welcomeString = "Good morning";
        else if (hour < 15)
            welcomeString = "Good afternoon";
        else
            welcomeString = "Good evening";
    }

    Component.onCompleted: getPhase()

    Text {
        renderType: Text.NativeRendering
        width: 370
        text: "<span style='color:" + Config.text + ";'>" + topLeftRect.welcomeString + " </span>" + "<span style='color:" + Config.primary + ";'>" + topLeftRect.username + "</span>"
        textFormat: Text.RichText
        wrapMode: Text.WordWrap
        anchors.centerIn: parent
        font.family: "Rubik"
        font.bold: false
        font.pixelSize: 40
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Timer {
        interval: 60000
        running: true
        onTriggered: topLeftRect.getPhase()
        repeat: true
    }
}
