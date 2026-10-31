import QtQuick
import qs.services

// Open/close progress `p` (0 → 1) for a shell window, on the shared motion
// curves. Opening waits for the window's first rendered frame: mapping a
// layer surface takes a few frames, and animating meanwhile makes the open
// look like a jump. Bind the window's `visible` to `shown`.
Item {
    id: root

    property bool open: false
    property int openDuration: Theme.durSlow
    property int closeDuration: Theme.dur

    readonly property bool shown: open || p > 0.002
    property bool ready: false
    onOpenChanged: if (!open) ready = false

    Connections {
        target: root.Window.window
        enabled: root.open && !root.ready
        function onFrameSwapped(): void {
            root.ready = true;
        }
    }
    Timer {
        running: root.open && !root.ready
        interval: 150
        onTriggered: root.ready = true
    }

    property real p: open && ready ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: root.open ? root.openDuration : root.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }
}
