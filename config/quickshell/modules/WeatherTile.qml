import QtQuick
import qs.services
import qs.components

// square detail tile: header, big value, optional caption, note at the bottom
FrostCard {
    id: tile
    property string icon
    property string title
    property string value
    property string caption
    property string sub
    radius: 16
    tint: 0.04
    darken: 0.05
    height: 114

    WeatherCardHeader { icon: tile.icon; text: tile.title }
    Txt {
        x: 12
        y: 27
        text: tile.value
        font.pixelSize: 25
        font.weight: Font.DemiBold
    }
    Txt {
        x: 12
        y: 53
        visible: tile.caption !== ""
        text: tile.caption
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    Txt {
        x: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: parent.width - 24
        text: tile.sub
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        maximumLineCount: 2
        font.pixelSize: 11
    }
}
