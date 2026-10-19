pragma Singleton
// Partly based on Caelestia (https://github.com/caelestia-dots/shell, GPL-3.0-only): cover-art fallback from services/Players.qml.
// Active media player (MPRIS): the first one that is playing, else the first one.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var list: Mpris.players.values

    // Firefox and others give no cover: like Caelestia, use the YouTube thumbnail of the page being played.
    function getArtUrl(player) {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;
        const url = (player.metadata && player.metadata["xesam:url"]) || "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            const m = url.match(/[?&]v=([\w-]{11})/);
            return m ? "https://img.youtube.com/vi/" + m[1] + "/hqdefault.jpg" : "";
        }
        return "";
    }
    readonly property var active: {
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }
}
