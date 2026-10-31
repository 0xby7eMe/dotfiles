import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Blurred, tinted backdrop on the monitors that don't host the open overview /
// cheat sheet / polkit prompt, so the whole desktop recedes rather than just one screen (see
// the qs-overlay-blur layer rule). Click to close.
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    readonly property bool open: (ShellState.overviewOpen || ShellState.cheatsheetOpen || ShellState.authOpen)
        && modelData.name !== ShellState.overlayScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || p > 0.002
    WlrLayershell.namespace: "qs-backdrop"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onOpenChanged: if (!open) ready = false

    // Start the open animation only once the surface is mapped and has drawn
    // its first frame. Mapping a fullscreen layer surface (and building its
    // scene graph) takes a few frames; animating meanwhile made the open look
    // like a jump. The timer is a fallback in case no frame arrives.
    property bool ready: false
    Connections {
        target: win.contentItem.Window.window
        enabled: win.open && !win.ready
        function onFrameSwapped(): void {
            win.ready = true;
        }
    }
    Timer {
        running: win.open && !win.ready
        interval: 150
        onTriggered: win.ready = true
    }

    // same motion as the overlays themselves
    property real p: open && ready ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: win.open ? Theme.durSlow : Theme.dur
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeAll()   // doesn't dismiss the polkit prompt
    }
}
