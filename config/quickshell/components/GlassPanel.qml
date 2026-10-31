import QtQuick

// Frosted-glass sheet for the fullscreen overlays (cheat sheet, polkit). It
// sits on a compositor-blurred layer, so it only adds a light tint: a faint
// darkening for legibility, a white sheen that fades downwards, a hairline
// rim, and a specular line along the top edge.
Item {
    id: root

    property real radius: 24
    property real darken: 0.12
    default property alias content: inner.data

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0, 0, 0, root.darken)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.11) }
            GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.05) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.03) }
        }
    }

    // specular highlight on the top rim
    Rectangle {
        x: root.radius * 0.6
        width: parent.width - 2 * x
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.5) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
