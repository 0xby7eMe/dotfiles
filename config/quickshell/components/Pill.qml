import QtQuick
import qs.services

// Small rounded text button with optional leading / trailing icons.
Rectangle {
    id: pill
    property string text
    property string icon
    property string trailing: ""
    property bool primary: false
    signal clicked

    implicitWidth: pillRow.implicitWidth + 28
    implicitHeight: 32
    radius: 16
    color: primary ? Theme.accent : pillMouse.containsMouse ? Theme.glassHover : Theme.glassHi
    scale: pillMouse.pressed ? 0.95 : 1
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 7
        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.icon !== ""
            icon: pill.icon
            size: 15
            color: pill.primary ? Theme.accentFg : Theme.fg
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: pill.primary ? Theme.accentFg : Theme.fg
        }
        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.trailing !== ""
            icon: pill.trailing
            size: 13
            color: Theme.fgDim
        }
    }
    MouseArea {
        id: pillMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
