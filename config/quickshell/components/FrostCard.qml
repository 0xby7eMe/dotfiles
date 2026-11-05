import QtQuick
import QtQuick.Effects

// Frosted card that blurs a sibling `backdrop` item inside the shell, on top
// of the compositor blur: the panel's sky shapes show through it softened,
// like macOS widgets over a wallpaper. The snapshot only re-renders when the
// backdrop changes, so moving or fading the panel costs nothing extra.
Item {
    id: root

    property Item backdrop
    property real radius: 18
    property real blurMax: 40
    property real tint: 0.06
    property real darken: 0       // black wash under the sheen, for bright backdrops
    default property alias content: inner.data

    // extra snapshot margin, so the blur never samples past the edges
    readonly property int pad: 40
    readonly property rect area: {
        void [x, y, width, height, parent?.x, parent?.y];
        return backdrop ? mapToItem(backdrop, -pad, -pad, width + 2 * pad, height + 2 * pad) : Qt.rect(0, 0, 0, 0);
    }

    ShaderEffectSource {
        id: snap
        x: -root.pad
        y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        sourceItem: root.backdrop
        sourceRect: root.area
        visible: false
    }

    Item {
        id: mask
        anchors.fill: snap
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.pad
            radius: root.radius
        }
    }

    MultiEffect {
        anchors.fill: snap
        source: snap
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: root.blurMax
        saturation: -0.2
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.darken > 0
        color: Qt.rgba(0, 0, 0, root.darken)
    }
    // glass tint + sheen that fades downwards, hairline rim
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.tint + 0.04) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, root.tint) }
        }
    }
    // specular highlight on the top rim
    Rectangle {
        x: root.radius
        width: parent.width - 2 * x
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.32) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
