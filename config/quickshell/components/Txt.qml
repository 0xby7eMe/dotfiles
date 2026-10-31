import QtQuick
import qs.services

Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color {
        ColorAnimation { duration: Theme.durFast }
    }
}
