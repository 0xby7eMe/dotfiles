import QtQuick
import qs.components

// Small caps card title with a leading icon, for the weather cards.
Row {
    id: hdr
    property string icon
    property string text
    x: 12
    y: 10
    spacing: 6
    MIcon {
        anchors.verticalCenter: parent.verticalCenter
        icon: hdr.icon
        size: 11
        color: Qt.rgba(1, 1, 1, 0.55)
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: hdr.text
        font.pixelSize: 10
        font.weight: Font.Bold
        font.letterSpacing: 0.8
        color: Qt.rgba(1, 1, 1, 0.55)
    }
}

