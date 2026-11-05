pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The now-playing player and an accent colour pulled from its cover art, for
// tinting the media cards (bar, control center, lock screen). Remote covers
// (Spotify serves https URLs) are fetched to the cache first, since the
// quantizer only reads local files. Grey covers fall back to white.
Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property string art: player ? (player.trackArtUrl || "") : ""

    readonly property bool remote: art.startsWith("http")
    readonly property string cached: remote ? `${Quickshell.cacheDir}/art/${Qt.md5(art)}` : ""
    property string localArt: ""
    onArtChanged: update()
    Component.onCompleted: update()

    function update(): void {
        if (!remote) {
            localArt = art;
            return;
        }
        localArt = "";
        fetch.command = ["sh", "-c", 'mkdir -p "${1%/*}"; [ -s "$1" ] || curl -sfL -m 10 -o "$1" "$2"', "sh", cached, art];
        fetch.running = true;
    }

    Process {
        id: fetch
        onExited: code => {
            if (code === 0)
                root.localArt = "file://" + root.cached;
        }
    }

    ColorQuantizer {
        id: quant
        source: root.localArt
        depth: 3          // 8 swatches
        rescaleSize: 64
    }

    // Most vivid swatch, lifted to a readable lightness.
    readonly property color raw: {
        let best = null, score = 0;
        for (const c of quant.colors) {
            const s = c.hsvSaturation * c.hsvValue * (c.hsvValue > 0.2 ? 1 : 0);
            if (s > score) {
                score = s;
                best = c;
            }
        }
        return best && score > 0.12 ? best : "#ffffff";
    }
    readonly property bool tinted: raw.hslSaturation > 0.05
    readonly property color accent: tinted
        ? Qt.hsla(raw.hslHue, Math.max(0.45, Math.min(0.9, raw.hslSaturation)), Math.max(0.6, Math.min(0.72, raw.hslLightness)), 1)
        : "#ffffff"
    // text / icons drawn on top of the accent
    readonly property color accentFg: 0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b > 0.5 ? "#000000" : "#ffffff"

    // the accent at low alpha, for washing a card
    function wash(alpha: real): color {
        return Qt.rgba(accent.r, accent.g, accent.b, tinted ? alpha : alpha * 0.5);
    }
}
