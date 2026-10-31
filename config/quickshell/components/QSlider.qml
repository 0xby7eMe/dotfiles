import QtQuick
import qs.services

// Thick pill slider with an icon inside the filled part.
Item {
    id: root

    property real value: 0
    property string icon
    property bool dimmed: false
    signal moved(real value)
    signal iconClicked

    implicitHeight: 40

    readonly property real shown: drag.pressed ? dragValue : value
    property real dragValue: 0

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.glassHi

        Rectangle {
            id: fillRect
            height: parent.height
            radius: height / 2
            width: Math.max(height, parent.width * root.shown)
            color: root.dimmed ? Theme.fgMuted : Theme.accent

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
            }
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }

        MIcon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: 20
            color: Theme.accentFg

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Txt {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.shown * 100) + "%"
            font.pixelSize: 12
            font.family: Theme.mono
            color: root.shown > 0.86 ? Theme.accentFg : Theme.fgDim
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.leftMargin: 40
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function update(x: real): void {
            root.dragValue = Math.max(0, Math.min(1, (x + 40) / root.width));
            root.moved(root.dragValue);
        }
        onPressed: e => update(e.x)
        onPositionChanged: e => { if (pressed) update(e.x); }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
