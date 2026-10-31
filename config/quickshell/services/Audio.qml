pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.audio != null
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property string icon: muted || volume <= 0.001 ? "volume-x"
        : volume < 0.34 ? "volume"
        : volume < 0.67 ? "volume-1" : "volume-2"

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? true

    function toggleMic(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function setVolume(v: real): void {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Avoid an OSD flash while pipewire state settles at startup.
    property bool armed: false
    Timer {
        running: true
        interval: 2000
        onTriggered: root.armed = true
    }

    onVolumeChanged: if (armed) ShellState.showOsd("volume", volume, muted)
    onMutedChanged: if (armed) ShellState.showOsd("volume", volume, muted)
}
