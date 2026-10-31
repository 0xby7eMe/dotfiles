import QtQuick
import qs.services

// A single keyboard key as a small glass tile: translucent white face that's
// brighter at the top, a hairline rim, and a soft 1px shadow ledge below.
// Symbol keys (⌘ ⇧ ↩ …) use the mono font, which carries those glyphs.
Rectangle {
    id: cap

    property string text
    property int size: 11

    readonly property bool glyph: text.length === 1 && text.charCodeAt(0) > 0x2000

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 14)
    implicitHeight: size + 12
    radius: 6
    color: Qt.rgba(0, 0, 0, 0.22)

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 1
        radius: cap.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.17) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.08) }
        }

        Txt {
            id: label
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cap.glyph ? 0 : -0.5
            text: cap.text
            font.family: cap.glyph ? Theme.mono : Theme.font
            font.pixelSize: cap.glyph ? cap.size + 2 : cap.size
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.92)
        }
    }
}
