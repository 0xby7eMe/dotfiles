import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// A floating card that drops down below the bar pills; height + content slide
// animated together.
PanelWindow {
    id: win

    property bool open: false
    property string align: "center"      // "center" | "right"
    property int panelWidth: 560
    property int maxHeight: 640
    property real contentHeight: 0
    property string ns: "qs-panel"
    property int keyboardMode: WlrKeyboardFocus.OnDemand
    default property alias content: body.data
    signal dismissed

    readonly property bool right: align === "right"
    readonly property int bottomRadius: 24

    // Pin to the monitor that was focused when opening.
    property ShellScreen target: Quickshell.screens[0]
    onOpenChanged: {
        if (open)
            target = Quickshell.screens.find(s => s.name === ShellState.focusedScreen) ?? Quickshell.screens[0];
    }
    screen: target

    anchors.top: true
    anchors.right: right
    margins.top: Theme.barZone + Theme.barGap
    margins.right: right ? Theme.barGap : 0
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: panelWidth
    implicitHeight: maxHeight
    color: "transparent"
    visible: open || p > 0.002

    WlrLayershell.namespace: ns
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? keyboardMode : WlrKeyboardFocus.None
    mask: Region { item: shape }

    property real p: open ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: win.open ? Theme.durSlow : Theme.dur
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }

    HyprlandFocusGrab {
        active: win.open && win.visible
        windows: [win]
        onCleared: win.dismissed()
    }

    Item {
        id: shape
        width: win.implicitWidth
        height: bg.height

        Rectangle {
            id: bg
            width: win.panelWidth
            height: Math.round(Math.min(win.contentHeight, win.maxHeight) * win.p)
            color: Theme.glass
            radius: Math.min(win.bottomRadius, height / 2)
            border.width: 1
            border.color: Theme.border
            clip: true

            Behavior on height {
                enabled: win.open && win.p >= 1
                NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
            }

            Item {
                id: body
                width: parent.width
                height: win.contentHeight
                y: -(1 - win.p) * 28
                opacity: Math.min(1, win.p * 1.5)
                scale: 0.97 + 0.03 * win.p
                transformOrigin: Item.Top
            }
        }
    }
}
