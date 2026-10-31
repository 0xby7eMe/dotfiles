import QtQuick
import qs.services

// Round icon button with a soft hover/press state.
Rectangle {
    id: root

    property string icon
    property string glyph: "" // MediaGlyph kind; replaces `icon` when set
    property int iconSize: 18
    property bool active: false
    property color activeColor: Theme.accent
    property color activeFg: Theme.accentFg
    signal clicked
    signal rightClicked

    implicitWidth: 34
    implicitHeight: 34
    radius: height / 2
    color: active ? activeColor
        : mouse.pressed ? Theme.glassHover
        : mouse.containsMouse ? Theme.glassHi : "transparent"
    scale: mouse.pressed ? 0.92 : 1

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

    MIcon {
        anchors.centerIn: parent
        visible: root.glyph === ""
        icon: root.icon
        size: root.iconSize
        color: root.active ? root.activeFg : Theme.fg
    }
    MediaGlyph {
        anchors.centerIn: parent
        visible: root.glyph !== ""
        kind: root.glyph
        size: root.iconSize
        color: root.active ? root.activeFg : Theme.fg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
