import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Volume / brightness indicator floating above the dock.
PanelWindow {
    id: win

    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: 96
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 260
    implicitHeight: 52
    color: "transparent"
    visible: shown || pill.opacity > 0
    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    Connections {
        target: ShellState
        function onOsdSerialChanged() {
            win.shown = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: win.shown = false
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.85
        anchors.verticalCenterOffset: win.shown ? 0 : 14

        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        Behavior on scale { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutBack } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }

        MIcon {
            id: icon
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            size: 20
            icon: ShellState.osdKind === "brightness" ? "sun" : Audio.icon
        }

        Rectangle {
            id: track
            anchors.left: icon.right
            anchors.leftMargin: 14
            anchors.right: value.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Theme.hover

            Rectangle {
                height: parent.height
                radius: 3
                width: parent.width * Math.max(0, Math.min(1, ShellState.osdValue))
                color: ShellState.osdMuted ? Theme.fgMuted : Theme.fg
                Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
            }
        }

        Txt {
            id: value
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            horizontalAlignment: Text.AlignRight
            text: ShellState.osdMuted ? "—" : Math.round(ShellState.osdValue * 100)
            font.family: Theme.mono
            font.pixelSize: 12
            color: Theme.fgDim
        }
    }
}
