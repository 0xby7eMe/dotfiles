import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// Wallpaper picked in the bar (see services/Wallpapers.qml); a new pick loads
// behind the current one and, once decoded, is revealed on top by a soft-edged
// circle growing out from the top centre (where the picker drops down).
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-wallpaper"

    property Image front: imgA
    readonly property Image back: front === imgA ? imgB : imgA
    readonly property string wanted: Wallpapers.source
    property real reveal: 1 // 0..1 progress of the incoming wallpaper

    onWantedChanged: {
        if (revealAnim.running) { // finish the current transition before starting another
            revealAnim.stop();
            reveal = 1;
            retireBack();
        }
        if (wanted !== front.source.toString())
            back.source = wanted;
    }

    function retireBack(): void {
        back.opacity = 0;
        back.source = "";
    }

    component Layer: Image {
        id: self
        readonly property bool revealing: self === win.front && win.reveal < 1

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: win.width * (win.screen?.devicePixelRatio ?? 1)
        sourceSize.height: win.height * (win.screen?.devicePixelRatio ?? 1)
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        // settle from a slight zoom while revealing
        scale: revealing ? 1 + 0.05 * (1 - win.reveal) : 1

        layer.enabled: revealing
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.6
        }

        onStatusChanged: {
            if (status !== Image.Ready)
                return;
            if (self === win.front) {
                opacity = 1; // first load: plain fade in
            } else if (self.source.toString() === win.wanted) {
                z = 1;
                win.front.z = 0;
                win.front = self;
                opacity = 1;
                revealAnim.restart();
            }
        }
    }

    Layer {
        id: imgA
        Component.onCompleted: source = win.wanted // one-shot, not a binding
    }
    Layer {
        id: imgB
    }

    // Growing circle used as the reveal mask. Rendered into a tiny texture and
    // scaled up with smoothing, which gives it a wide feathered edge for free.
    Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, width / 20), Math.max(1, height / 20))

        Rectangle {
            readonly property real maxR: Math.hypot(win.width / 2, win.height) + 80
            width: 2 * maxR * win.reveal
            height: width
            radius: width / 2
            x: (win.width - width) / 2
            y: -height / 2
            color: "white"
        }
    }

    NumberAnimation {
        id: revealAnim
        target: win
        property: "reveal"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphasized
        onFinished: win.retireBack()
    }
}
