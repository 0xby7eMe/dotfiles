import QtQuick
import QtQuick.Shapes
import qs.services

// Concave ("inverted") corner used to blend panels into the bar and screen edges.
// `corner` names the corner of this square that is filled.
Shape {
    id: root

    enum Pos { TopLeft, TopRight, BottomLeft, BottomRight }
    property int corner: Corner.TopLeft
    property int size: Theme.corner
    property color color: Theme.bg

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        id: sp
        strokeWidth: -1
        fillColor: root.color

        readonly property bool left: root.corner === Corner.TopLeft || root.corner === Corner.BottomLeft
        readonly property bool top: root.corner === Corner.TopLeft || root.corner === Corner.TopRight

        // Start at the filled corner, run along one edge, arc back along the other.
        startX: left ? 0 : root.size
        startY: top ? 0 : root.size
        PathLine {
            x: sp.left ? root.size : 0
            y: sp.top ? 0 : root.size
        }
        PathArc {
            x: sp.left ? 0 : root.size
            y: sp.top ? root.size : 0
            radiusX: root.size
            radiusY: root.size
            direction: (sp.left === sp.top) ? PathArc.Counterclockwise : PathArc.Clockwise
        }
        PathLine {
            x: sp.startX
            y: sp.startY
        }
    }
}
