import QtQuick
import qs.services

// macOS-style control: a round button that fills white when active.
//   "1x1" – bare circle with the label underneath
//   "2x1" – platter with the circle and label + sublabel beside it
//   "row" – like 2x1 without the platter (rows inside a bigger module)
// Clicking the circle toggles; clicking the text opens the detail view when
// there is one (right-click works everywhere).
Item {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool active: false
    property bool hasDetail: false
    property string variant: "2x1"
    signal toggled
    signal detail

    readonly property bool compact: variant === "1x1"
    readonly property int disc: compact ? 50 : variant === "row" ? 34 : 38
    readonly property color fgc: active ? Theme.accentFg : Theme.fg

    function press(e: var): void {
        if (e.button === Qt.RightButton && hasDetail)
            detail();
        else
            toggled();
    }

    Rectangle {
        anchors.fill: parent
        visible: root.variant === "2x1"
        radius: 20
        color: textMouse.containsMouse && root.hasDetail ? Theme.glassHover : Theme.glassHi
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Rectangle {
        id: circle
        width: root.disc
        height: width
        radius: width / 2
        x: root.compact ? (root.width - width) / 2 : root.variant === "row" ? 0 : 12
        y: root.compact ? (root.height - width - 20) / 2 : (root.height - height) / 2
        color: root.active ? Theme.accent : circleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Theme.glassHover
        scale: circleMouse.pressed ? 0.9 : 1

        Behavior on color { ColorAnimation { duration: Theme.dur } }
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

        MIcon {
            anchors.centerIn: parent
            icon: root.icon
            size: root.compact ? 21 : 17
            color: root.fgc
        }

        MouseArea {
            id: circleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => root.press(e)
        }
    }

    Txt {
        visible: root.compact
        anchors.top: circle.bottom
        anchors.topMargin: 6
        x: 2
        width: root.width - 4
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font.pixelSize: 11
        color: Theme.fgDim
    }

    Column {
        visible: !root.compact
        anchors.left: circle.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: root.variant === "row" ? 0 : 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Txt {
            width: parent.width
            text: root.label
            font.weight: Font.DemiBold
        }
        Txt {
            width: parent.width
            visible: text !== ""
            text: root.sublabel
            font.pixelSize: 11
            color: Theme.fgDim
        }
    }

    MouseArea {
        id: textMouse
        visible: !root.compact
        anchors.fill: parent
        anchors.leftMargin: circle.x + circle.width
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => root.hasDetail && e.button === Qt.LeftButton ? root.detail() : root.press(e)
    }
}
