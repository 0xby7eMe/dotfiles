pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Three floating pills: workspaces (left), clock (center, grows into the media
// player on hover, the app launcher, the wallpaper picker, notification
// popups and, on click, the notification center), tray + status (right).
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property bool focusedScreen: monitor?.name === ShellState.focusedScreen
    readonly property bool hostsPill: ShellState.pillScreen === monitor?.name
    readonly property bool launcherHere: ShellState.launcherOpen && hostsPill
    readonly property bool wallpaperHere: ShellState.wallpaperOpen && hostsPill
    readonly property bool dashHere: ShellState.dashOpen && hostsPill
    readonly property bool pillBusy: launcherHere || wallpaperHere || dashHere
    readonly property bool notifHere: Notifs.count > 0 && Notifs.screen === monitor?.name

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    // Tall enough for the grown center pill; the mask keeps the rest click-through.
    implicitHeight: Theme.barGap + center.launcherMaxHeight + 24
    exclusiveZone: Theme.barZone
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: pillBusy ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        Region { item: leftPill }
        Region { item: center }
        Region { item: rightPill }
    }

    // Clicking outside the bar closes the launcher / wallpaper picker. Armed a beat after opening:
    // starting it in the same frame the bar takes keyboard focus makes
    // Hyprland drop the grab right away.
    HyprlandFocusGrab {
        active: bar.pillBusy && !grabArm.running
        windows: [bar]
        onCleared: ShellState.autoClose()
    }
    Timer {
        id: grabArm
        interval: 80
    }
    onPillBusyChanged: if (pillBusy) grabArm.restart()

    // Keeps hypridle from locking while "caffeine" is on.
    IdleInhibitor {
        window: bar
        enabled: ShellState.caffeine
    }

    component Pill: Rectangle {
        y: Theme.barGap
        height: Theme.barHeight
        radius: height / 2
        color: Theme.glass
        border.width: 1
        border.color: Theme.border
        Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
    }

    // ---------------- left ----------------
    Pill {
        id: leftPill
        x: Theme.barGap
        width: leftRow.implicitWidth + 8
        clip: true

        Row {
            id: leftRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                id: launcherBtn
                readonly property bool open: bar.launcherHere
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 22
                radius: 11
                color: open ? Theme.accent : lbMouse.containsMouse ? Theme.glassHi : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur } }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    text: "\uf303" // Arch logo (nerd font)
                    font.family: Theme.mono
                    font.pixelSize: 14
                    color: launcherBtn.open ? Theme.accentFg : Theme.fg
                    rotation: launcherBtn.open ? 360 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
                    Behavior on color { ColorAnimation { duration: Theme.dur } }
                }

                MouseArea {
                    id: lbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.toggleLauncher("apps")
                }
            }

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                monitor: bar.monitor
            }
        }
    }

    // ---------------- center ----------------
    Item {
        id: center

        readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
        readonly property bool hasMedia: player !== null && (player.trackTitle ?? "") !== ""
        readonly property string art: player?.trackArtUrl ?? ""
        readonly property bool expanded: hasMedia && !bar.pillBusy && (hover.hovered || closeDelay.running)
        readonly property string mode: bar.launcherHere ? "launcher" : bar.wallpaperHere ? "wallpaper"
            : bar.dashHere ? "dash" : bar.notifHere ? "notif" : expanded ? "media" : "pill"

        readonly property int expandedWidth: 460
        readonly property int expandedHeight: Theme.barHeight + 136
        readonly property int collapsedWidth: topRow.implicitWidth + 28
        readonly property int launcherWidth: 600
        readonly property int launcherMaxHeight: Theme.barHeight + 500
        readonly property int wallpaperWidth: 754   // four thumbnail columns, see WallpaperView
        readonly property int notifWidth: 420
        readonly property int dashWidth: 680

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barGap
        width: mode === "launcher" ? launcherWidth : mode === "wallpaper" ? wallpaperWidth : mode === "notif" ? notifWidth
            : mode === "dash" ? dashWidth : mode === "media" ? expandedWidth : collapsedWidth
        height: mode === "launcher" ? Theme.barHeight + Math.min(launcherLoader.height, launcherMaxHeight - Theme.barHeight)
            : mode === "wallpaper" ? Theme.barHeight + Math.min(wallpaperLoader.height, launcherMaxHeight - Theme.barHeight)
            : mode === "notif" ? Theme.barHeight + Math.min(notifLoader.height, launcherMaxHeight - Theme.barHeight)
            : mode === "dash" ? Theme.barHeight + Math.min(dashLoader.height, launcherMaxHeight - Theme.barHeight)
            : mode === "media" ? expandedHeight : Theme.barHeight

        // Springs keep their velocity when the target changes mid-flight (hover
        // out early, typing in the launcher), so the morph never jerks.
        Behavior on width { SpringAnimation { spring: 3.5; damping: 0.42; epsilon: 0.25 } }
        Behavior on height { SpringAnimation { spring: 3.5; damping: 0.42; epsilon: 0.25 } }

        // 0..1 reveal progress for each grown state's content
        property real mediaP: mode === "media" ? 1 : 0
        property real launcherP: mode === "launcher" ? 1 : 0
        property real wallpaperP: mode === "wallpaper" ? 1 : 0
        property real notifP: mode === "notif" ? 1 : 0
        property real dashP: mode === "dash" ? 1 : 0
        Behavior on mediaP { NumberAnimation { duration: center.mediaP < 0.5 ? Theme.durSlow : Theme.dur; easing.type: Easing.OutCubic } }
        Behavior on launcherP { NumberAnimation { duration: center.launcherP < 0.5 ? Theme.durSlow : Theme.dur; easing.type: Easing.OutCubic } }
        Behavior on wallpaperP { NumberAnimation { duration: center.wallpaperP < 0.5 ? Theme.durSlow : Theme.dur; easing.type: Easing.OutCubic } }
        Behavior on notifP { NumberAnimation { duration: center.notifP < 0.5 ? Theme.durSlow : Theme.dur; easing.type: Easing.OutCubic } }
        Behavior on dashP { NumberAnimation { duration: center.dashP < 0.5 ? Theme.durSlow : Theme.dur; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) closeDelay.restart()
        }
        // small grace period so brushing past the edge doesn't snap it shut
        Timer {
            id: closeDelay
            interval: 280
        }

        // position isn't pushed by mpris; poll while the player is visible
        Timer {
            running: center.expanded && (center.player?.isPlaying ?? false)
            interval: 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: center.player.positionChanged()
        }

        ClippingRectangle {
            id: card
            anchors.fill: parent
            radius: Math.min(height / 2, 26)
            // frosted glass, same as the dock
            color: Theme.glass

            // blurred cover tint; kept faint so the compositor blur behind the
            // glass still shows through
            Image {
                id: backdrop
                anchors.fill: parent
                anchors.margins: -40
                source: center.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(128, 128)
                opacity: backdrop.status === Image.Ready ? center.mediaP * 0.35 : 0
                visible: opacity > 0
                layer.enabled: visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    saturation: 0.15
                    brightness: -0.12
                }
            }
            Rectangle {
                anchors.fill: parent
                opacity: center.mediaP
                // album accent pooling at the bottom
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Media.wash(0.22); Behavior on color { ColorAnimation { duration: Theme.durSlow } } }
                }
            }

            // ---- top row: (mini track) · date · time ----
            Row {
                id: topRow
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.barHeight
                spacing: 8

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.fgDim
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.weight: Font.Bold
                }
            }
            // the clock opens the notification center
            MouseArea {
                anchors.fill: topRow
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleDash(bar.monitor?.name ?? "")
            }

            // ---- launcher ----
            // Only the bar that last hosted the launcher keeps an instance, so
            // there is a single copy of its state (usage counts, clipboard).
            Loader {
                id: launcherLoader
                width: center.launcherWidth
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.barHeight + (1 - center.launcherP) * -16
                active: bar.hostsPill
                opacity: center.launcherP
                visible: opacity > 0.01
                height: item?.implicitHeight ?? 0
                sourceComponent: LauncherView {
                    open: bar.launcherHere
                }
            }

            // ---- wallpaper picker ----
            // No state worth keeping, so it only exists while shown (frees the thumbnails).
            Loader {
                id: wallpaperLoader
                width: center.wallpaperWidth
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.barHeight + (1 - center.wallpaperP) * -16
                active: bar.wallpaperHere || center.wallpaperP > 0.01
                opacity: center.wallpaperP
                visible: opacity > 0.01
                height: item?.implicitHeight ?? 0
                sourceComponent: WallpaperView {
                    open: bar.wallpaperHere
                }
            }

            // ---- notification popups ----
            // Kept alive while fading out so the last one's exit can play.
            Loader {
                id: notifLoader
                width: center.notifWidth
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.barHeight + (1 - center.notifP) * -16
                active: bar.notifHere || center.notifP > 0.01
                opacity: center.notifP
                visible: opacity > 0.01
                height: item?.implicitHeight ?? 0
                sourceComponent: NotificationView {
                    open: center.mode === "notif"
                }
            }

            // ---- notification center + calendar ----
            Loader {
                id: dashLoader
                width: center.dashWidth
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.barHeight + (1 - center.dashP) * -16
                active: bar.dashHere || center.dashP > 0.01
                opacity: center.dashP
                visible: opacity > 0.01
                height: item?.implicitHeight ?? 0
                sourceComponent: DashView {
                    open: bar.dashHere
                }
            }

            // ---- expanded player ----
            Item {
                id: playerView
                // laid out at full size and revealed by the growing card
                width: center.expandedWidth
                height: center.expandedHeight - Theme.barHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.barHeight + (1 - center.mediaP) * -12
                opacity: center.mediaP
                visible: opacity > 0.01

                RectangularShadow {
                    anchors.fill: cover
                    radius: cover.radius
                    offset.y: 6
                    blur: 22
                    spread: -2
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
                ClippingRectangle {
                    id: cover
                    x: 16
                    y: 2
                    width: 120
                    height: 120
                    radius: 16
                    color: Theme.surfaceHi
                    scale: 0.85 + 0.15 * center.mediaP

                    Image {
                        anchors.fill: parent
                        source: center.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(240, 240)
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: center.art === ""
                        icon: "music"
                        size: 40
                        color: Theme.fgMuted
                    }
                }

                Item {
                    id: info
                    anchors.left: cover.right
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: cover.top
                    anchors.bottom: cover.bottom

                    Column {
                        width: parent.width
                        y: 2
                        spacing: 2
                        Txt {
                            width: parent.width
                            text: center.player?.trackTitle ?? ""
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                        Txt {
                            width: parent.width
                            text: [center.player?.trackArtist, center.player?.trackAlbum].filter(s => s).join("  ·  ")
                            font.pixelSize: 12
                            color: Theme.fgDim
                        }
                    }

                    // progress
                    Item {
                        id: progress
                        readonly property real length: center.player?.length ?? 0
                        readonly property real pos: center.player?.position ?? 0
                        readonly property real ratio: length > 0 ? Math.max(0, Math.min(1, pos / length)) : 0
                        readonly property bool seekable: (center.player?.canSeek ?? false) && length > 0

                        function fmt(s: real): string {
                            s = Math.max(0, Math.floor(s));
                            return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
                        }

                        visible: (center.player?.lengthSupported ?? false) && length > 0
                        width: parent.width
                        height: 26
                        y: 50

                        Rectangle {
                            id: track
                            width: parent.width
                            height: seekMouse.containsMouse ? 6 : 4
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.16)
                            Behavior on height { NumberAnimation { duration: Theme.durFast } }

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: Math.max(height, parent.width * progress.ratio)
                                color: Media.accent
                                Behavior on color { ColorAnimation { duration: Theme.durSlow } }
                                Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                            }
                        }
                        Txt {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            text: progress.fmt(progress.pos)
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.fgDim
                        }
                        Txt {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            text: progress.fmt(progress.length)
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.fgDim
                        }
                        MouseArea {
                            id: seekMouse
                            width: parent.width
                            height: 14
                            y: -5
                            enabled: progress.seekable
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                center.player.position = (e.x / width) * progress.length;
                                center.player.positionChanged();
                            }
                        }
                    }

                    // controls
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 6

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 30
                            implicitHeight: 30
                            iconSize: 17
                            visible: center.player?.shuffleSupported ?? false
                            icon: "shuffle"
                            opacity: center.player?.shuffle ? 1 : 0.45
                            onClicked: center.player.shuffle = !center.player.shuffle
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "prev"
                            iconSize: 20
                            opacity: center.player?.canGoPrevious ? 1 : 0.35
                            onClicked: center.player.previous()
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 42
                            implicitHeight: 42
                            iconSize: 22
                            active: true
                            activeColor: Media.accent
                            activeFg: Media.accentFg
                            glyph: center.player?.isPlaying ? "pause" : "play"
                            onClicked: center.player.togglePlaying()
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "next"
                            iconSize: 20
                            opacity: center.player?.canGoNext ? 1 : 0.35
                            onClicked: center.player.next()
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 30
                            implicitHeight: 30
                            iconSize: 17
                            visible: center.player?.loopSupported ?? false
                            icon: center.player?.loopState === MprisLoopState.Track ? "repeat-1" : "repeat"
                            opacity: (center.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? 1 : 0.45
                            onClicked: {
                                const p = center.player;
                                p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                    : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                    : MprisLoopState.None;
                            }
                        }
                    }
                }
            }
        }

        // hairline border drawn over the clipped content (see card)
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: 1
            border.color: center.mode !== "pill" ? Theme.borderHi : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.dur } }
        }
    }

    // Themed menu shared by all tray items
    TrayMenu {
        id: trayMenu
        screen: bar.modelData
    }

    // ---------------- right ----------------
    Pill {
        id: rightPill
        anchors.right: parent.right
        anchors.rightMargin: Theme.barGap
        width: rightRow.implicitWidth + 8

        Row {
            id: rightRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // System tray (desaturated to keep the monochrome look)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: SystemTray.items

                    Item {
                        id: trayItem
                        required property SystemTrayItem modelData
                        width: 24
                        height: 22

                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: trayMouse.containsMouse ? Theme.glassHi : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 15
                            source: trayItem.modelData.icon
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                saturation: trayMouse.containsMouse ? 0 : -1
                                brightness: trayMouse.containsMouse ? 0.1 : 0
                            }
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                const it = trayItem.modelData;
                                if (e.button === Qt.RightButton || (e.button === Qt.LeftButton && it.onlyMenu)) {
                                    if (it.hasMenu) trayMenu.openFor(trayItem, it.menu);
                                } else if (e.button === Qt.MiddleButton) {
                                    it.secondaryActivate();
                                } else {
                                    it.activate();
                                }
                            }
                            onWheel: e => trayItem.modelData.scroll(e.angleDelta.y / 120, false)
                        }
                    }
                }
            }

            // Weather -> opens the forecast panel
            Rectangle {
                id: weatherBtn
                readonly property bool open: ShellState.weatherOpen && bar.focusedScreen
                readonly property color fgc: open ? Theme.accentFg : Theme.fg
                visible: Weather.ready
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                width: weatherRow.implicitWidth + 18
                radius: 11
                color: open ? Theme.accent : wMouse.containsMouse ? Theme.glassHi : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur } }

                Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Weather.icon; size: 15; color: weatherBtn.fgc }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.tempText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: weatherBtn.fgc
                    }
                }

                MouseArea {
                    id: wMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.toggleWeather()
                }
            }

            // Status cluster -> opens the control center
            Rectangle {
                id: status
                readonly property bool open: ShellState.controlOpen && bar.focusedScreen
                readonly property color fgc: open ? Theme.accentFg : Theme.fg
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                width: statusRow.implicitWidth + 20
                radius: 11
                color: open ? Theme.accent : sMouse.containsMouse ? Theme.glassHi : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur } }

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 9

                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Sys.netIcon; size: 15; color: status.fgc }
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Sys.btIcon; size: 15; color: status.fgc; visible: Sys.btAdapter !== null }
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: Audio.icon; size: 15; color: status.fgc }
                    Row {
                        visible: Sys.hasBattery
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Sys.batIcon
                            size: 15
                            color: !Sys.charging && Sys.batLevel < 0.15 ? Theme.danger : status.fgc
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(Sys.batLevel * 100) + "%"
                            font.pixelSize: 12
                            color: status.fgc
                        }
                    }
                }

                MouseArea {
                    id: sMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.toggleControl()
                    onWheel: e => Audio.setVolume(Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }
    }
}
