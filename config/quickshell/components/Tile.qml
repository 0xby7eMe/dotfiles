import QtQuick
import qs.services

// Quick-settings toggle: inverts to white when active. With `expandable` it
// grows a chevron on the right (also right-click) that toggles a detail view.
Rectangle {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool active: false
    property bool expandable: false
    property bool expanded: false
    signal clicked
    signal expandClicked

    readonly property color fgc: active ? Theme.accentFg : Theme.fg

    implicitHeight: 56
    radius: Theme.radius
    color: active ? Theme.accent : mouse.containsMouse || more.containsMouse ? Theme.glassHover : Theme.glassHi
    scale: mouse.pressed || more.pressed ? 0.96 : 1

    Behavior on color { ColorAnimation { duration: Theme.dur } }
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: root.expandable ? chevron.width : 10
        spacing: 10

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: 20
            color: root.fgc
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30
            spacing: 1

            Txt {
                width: parent.width
                text: root.label
                font.weight: Font.DemiBold
                color: root.fgc
            }
            Txt {
                width: parent.width
                visible: text !== ""
                text: root.sublabel
                font.pixelSize: 11
                color: root.active ? Qt.rgba(0, 0, 0, 0.6) : Theme.fgDim
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton && root.expandable ? root.expandClicked() : root.clicked()
    }

    Item {
        id: chevron
        visible: root.expandable
        anchors.right: parent.right
        width: 34
        height: parent.height

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: root.active ? Qt.rgba(0, 0, 0, 0.15) : Theme.border
        }
        MIcon {
            anchors.centerIn: parent
            icon: "chevron-down"
            size: 16
            color: root.fgc
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
        }
        MouseArea {
            id: more
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandClicked()
        }
    }
}
