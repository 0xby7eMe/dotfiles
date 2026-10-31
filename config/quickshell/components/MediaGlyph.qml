import QtQuick
import QtQuick.Shapes
import qs.services

// Filled, soft-cornered media transport glyphs drawn on a 24-unit grid:
// "play" | "pause" | "next" | "prev". Play and pause morph into each other.
Item {
    id: root

    property string kind: "play"
    property int size: 22
    property color color: Theme.fg

    implicitWidth: size
    implicitHeight: size

    // 0 = play, 1 = pause
    property real t: kind === "pause" ? 1 : 0
    Behavior on t { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
    function m(a: real, b: real): real {
        return a + (b - a) * t;
    }

    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    component Glyph: Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
    }
    component Fill: ShapePath {
        fillColor: root.color
        strokeColor: root.color
        strokeWidth: 2
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
    }

    // play ⇄ pause: each pause bar morphs into one half of the triangle
    Glyph {
        visible: root.kind === "play" || root.kind === "pause"
        Fill {
            startX: root.m(7.5, 6.5); startY: 5
            PathLine { x: root.m(13.5, 9); y: root.m(8.8, 5) }
            PathLine { x: root.m(13.5, 9); y: root.m(15.2, 19) }
            PathLine { x: root.m(7.5, 6.5); y: 19 }
            PathLine { x: root.m(7.5, 6.5); y: 5 }
        }
        Fill {
            startX: root.m(13.5, 15); startY: root.m(8.8, 5)
            PathLine { x: root.m(19.5, 17.5); y: root.m(12, 5) }
            PathLine { x: root.m(19.5, 17.5); y: root.m(12, 19) }
            PathLine { x: root.m(13.5, 15); y: root.m(15.2, 19) }
            PathLine { x: root.m(13.5, 15); y: root.m(8.8, 5) }
        }
    }

    // next / prev: triangle + bar, prev is mirrored
    Glyph {
        visible: root.kind === "next" || root.kind === "prev"
        transform: Scale { origin.x: 12; xScale: root.kind === "prev" ? -1 : 1 }
        Fill {
            startX: 5; startY: 6
            PathLine { x: 15; y: 12 }
            PathLine { x: 5; y: 18 }
            PathLine { x: 5; y: 6 }
        }
        Fill {
            startX: 18.6; startY: 6
            PathLine { x: 19; y: 6 }
            PathLine { x: 19; y: 18 }
            PathLine { x: 18.6; y: 18 }
            PathLine { x: 18.6; y: 6 }
        }
    }
}
