pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services
import qs.components

// One monitor's lock screen, macOS style: blurred wallpaper, date over a big
// clock, now-playing card, and avatar + password at the bottom. State (the
// typed password, PAM) lives in Lock.qml and is shared across monitors.
Item {
    id: root

    required property var lock          // Lock.qml scope
    property ShellScreen screen
    property bool preview: false

    readonly property real p: reveal.p
    readonly property var player: Mpris.players.values.find(pl => pl.isPlaying) ?? Mpris.players.values[0] ?? null

    // fades in on lock, out (with the blur lifting) on a successful unlock
    Reveal {
        id: reveal
        open: !root.lock.unlocking
        openDuration: 650
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: Qt.callLater(() => field.focusInput())

    Connections {
        target: root.lock
        function onFailure(): void {
            field.clear();
            field.error = true;
            field.shake();
            field.focusInput();
        }
        function onTextChanged(): void {
            if (field.text !== root.lock.text)
                field.text = root.lock.text;
        }
    }

    // ---------- background ----------
    Image {
        id: wall
        anchors.fill: parent
        source: Wallpapers.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width * (root.screen?.devicePixelRatio ?? 1)
        sourceSize.height: root.height * (root.screen?.devicePixelRatio ?? 1)
        asynchronous: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blurMax: 64
        blur: root.lock.unlocking ? 0 : 1
        saturation: root.lock.unlocking ? 0 : 0.15
        brightness: root.lock.unlocking ? 0 : -0.16
        autoPaddingEnabled: false
        Behavior on blur { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
        Behavior on brightness { NumberAnimation { duration: Theme.durSlow } }
        Behavior on saturation { NumberAnimation { duration: Theme.durSlow } }
    }
    // soft vignette so white text reads on bright wallpapers
    Rectangle {
        anchors.fill: parent
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.35) }
        }
    }

    // ---------- status (top right) ----------
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 18
        spacing: 14
        opacity: root.p

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Sys.netIcon
            size: 16
        }
        Row {
            visible: Sys.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Sys.batLevel * 100) + "%"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Sys.batIcon
                size: 18
            }
        }
    }

    // ---------- date + clock ----------
    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.09 - (1 - root.p) * 30
        opacity: root.p
        spacing: -10

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            font.pixelSize: 22
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.82)
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Math.min(150, root.height * 0.135)
            font.weight: Font.DemiBold
            font.letterSpacing: -3
            color: Qt.rgba(1, 1, 1, 0.92)
        }
    }

    // ---------- now playing ----------
    Rectangle {
        id: media
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockCol.bottom
        anchors.topMargin: 26 + (1 - root.p) * 20
        visible: root.player !== null && (root.player.trackTitle ?? "") !== ""
        width: 360
        height: 72
        radius: 20
        color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        opacity: root.p

        ClippingRectangle {
            id: art
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.1)
            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize.width: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MIcon {
                anchors.centerIn: parent
                visible: (root.player?.trackArtUrl ?? "") === ""
                icon: "music"
                size: 20
                color: Theme.fgDim
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 12
            anchors.right: controls.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Txt {
                width: parent.width
                text: root.player?.trackTitle ?? ""
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Txt {
                width: parent.width
                text: root.player?.trackArtist ?? ""
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [
                    { icon: "skip-back", act: () => root.player.previous() },
                    { icon: root.player?.isPlaying ? "pause" : "play", act: () => root.player.togglePlaying() },
                    { icon: "skip-forward", act: () => root.player.next() }
                ]
                Rectangle {
                    id: ctl
                    required property var modelData
                    width: 32
                    height: 32
                    radius: 16
                    color: ctlMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    MIcon {
                        anchors.centerIn: parent
                        icon: ctl.modelData.icon
                        size: 17
                    }
                    MouseArea {
                        id: ctlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ctl.modelData.act()
                    }
                }
            }
        }
    }

    // ---------- user + password ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.08 - (1 - root.p) * 30
        opacity: root.p
        spacing: 0

        // avatar
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 68
            height: 68

            RectangularShadow {
                anchors.fill: avatar
                radius: avatar.radius
                blur: 20
                offset.y: 4
                color: Qt.rgba(0, 0, 0, 0.35)
            }
            ClippingRectangle {
                id: avatar
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceHi
                Image {
                    anchors.fill: parent
                    source: User.avatar
                    sourceSize.width: 136
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)
            }
        }

        Item { width: 1; height: 12 }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: User.name
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        Item { width: 1; height: 14 }

        PasswordField {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 230
            placeholder: "Enter Password"
            busy: root.lock.busy || root.lock.unlocking
            color: Qt.rgba(1, 1, 1, 0.14)
            onTextChanged: {
                if (root.lock.text !== text)
                    root.lock.text = text;
                if (text !== "")
                    root.lock.failed = false;
            }
            onSubmitted: root.lock.submit()
            onCancelled: {
                if (text !== "")
                    clear();
                else
                    root.lock.cancelPreview();
            }
        }

        Item { width: 1; height: 12 }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lock.failed ? "Incorrect password"
                : root.preview ? "Preview · Esc to close"
                : "Locked"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: root.lock.failed ? Theme.danger : Qt.rgba(1, 1, 1, 0.55)
        }
    }
}
