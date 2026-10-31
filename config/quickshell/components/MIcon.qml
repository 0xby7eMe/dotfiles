import QtQuick
import qs.services
import "lucide.js" as Lucide

// Lucide glyph by name (e.g. "wifi"), see https://lucide.dev/icons.
Text {
    property string icon
    property int size: 18

    text: Lucide.glyph(icon)
    font.family: Theme.icons
    font.pixelSize: size
    color: Theme.fg
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation { duration: Theme.durFast }
    }
}
