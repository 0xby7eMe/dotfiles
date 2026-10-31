pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// Wallpaper picker shown inside the bar's center pill. Click / Enter applies
// (the picker stays open so you can try a few); Esc or clicking outside closes.
Item {
    id: root

    property bool open: false
    implicitHeight: grid.y + grid.height + 16 - inset

    readonly property int tileW: 172
    readonly property int tileH: 108
    readonly property int gap: 10
    readonly property int inset: gap / 2

    // Scroll speed: columns per mouse-wheel notch, and a multiplier for touchpads.
    readonly property real wheelColumns: 4
    readonly property real touchpadSpeed: 2.5

    function reset(): void {
        Wallpapers.refreshThumbs();
        grid.currentIndex = grid.loops ? grid.period + Math.max(0, Wallpapers.currentIndex) : Math.max(0, Wallpapers.currentIndex);
        grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
        grid.forceActiveFocus();
    }
    onOpenChanged: if (open) reset()
    Component.onCompleted: if (open) reset()

    // ---- header ----
    Item {
        id: header
        x: 18
        y: 14
        width: parent.width - 36
        height: 30

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "image"
                size: 18
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Wallpapers"
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpapers.model.count
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.fgMuted
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            IconButton {
                implicitWidth: 30
                implicitHeight: 30
                iconSize: 18
                icon: "shuffle"
                onClicked: {
                    Wallpapers.random();
                    grid.currentIndex = grid.nearestCopy(Wallpapers.currentIndex);
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
                }
            }
            IconButton {
                implicitWidth: 30
                implicitHeight: 30
                iconSize: 18
                icon: "folder-open"
                onClicked: {
                    Quickshell.execDetached(["xdg-open", Wallpapers.dir]);
                    ShellState.closeAll();
                }
            }
        }
    }

    // ---- thumbnails: two rows, scrolling sideways ----
    // Tiles sit inset in their cells so the ring / hover scale isn't clipped;
    // the grid is pulled out by that inset to keep the 18px visual margin.
    GridView {
        id: grid
        x: 18 - root.inset
        y: header.y + header.height + 10 - root.inset
        width: parent.width - 2 * x
        height: 2 * cellHeight
        cellWidth: root.tileW + root.gap
        cellHeight: root.tileH + root.gap
        flow: GridView.FlowTopToBottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 2 * cellWidth
        keyNavigationWraps: false
        highlightFollowsCurrentItem: false

        // Endless strip: the wallpapers are repeated a few times and the view is
        // silently shifted by whole periods so it never reaches an end. With an
        // odd count the columns only line up again after two passes, so a
        // period is then 2n items. Too few wallpapers to fill the strip → no loop.
        readonly property int n: Wallpapers.model.count
        readonly property bool loops: Math.ceil(n / 2) * cellWidth > width
        readonly property int period: n % 2 === 0 ? n : 2 * n
        readonly property real periodWidth: period / 2 * cellWidth
        readonly property int periods: loops ? Math.ceil(width / periodWidth) + 3 : 1
        model: loops ? period * periods : n

        // Offset that moves x into the second period (whole periods only, so
        // nothing visibly changes); leaves a full period of slack either side.
        function loopShift(x: real): real {
            if (!loops)
                return 0;
            const lo = originX + periodWidth;
            return -Math.floor((x - lo) / periodWidth) * periodWidth;
        }
        // Copy of wallpaper i closest to the current index.
        function nearestCopy(i: int): int {
            if (!loops || i < 0)
                return Math.max(0, i);
            return i + Math.round((currentIndex - i) / n) * n;
        }
        function wrapIndex(): void {
            if (!loops || (currentIndex >= period && currentIndex < (periods - 1) * period))
                return;
            const k = Math.floor(currentIndex / period) - 1;
            scrollAnim.stop();
            contentX -= k * periodWidth;
            currentIndex -= k * period;
        }
        onCurrentIndexChanged: Qt.callLater(wrapIndex)
        onMovementEnded: contentX += loopShift(contentX)

        // Any wheel (vertical or horizontal) scrolls the strip sideways. A wheel
        // notch moves root.wheelColumns columns and animates; touchpads
        // (pixelDelta) track directly. Steps accumulate on scrollTarget so fast
        // spins don't lose distance.
        property real scrollTarget: contentX
        function scrollTo(x: real, animate: bool): void {
            scrollAnim.stop();
            if (loops) {
                const s = loopShift(x);
                contentX += s;
                scrollTarget = x + s;
            } else {
                const max = Math.max(0, contentWidth - width) + originX;
                scrollTarget = Math.max(originX, Math.min(max, x));
            }
            if (animate) {
                scrollAnim.to = scrollTarget;
                scrollAnim.start();
            } else {
                contentX = scrollTarget;
            }
        }
        NumberAnimation {
            id: scrollAnim
            target: grid
            property: "contentX"
            duration: Theme.dur
            easing.type: Easing.OutCubic
        }
        onMovementStarted: scrollAnim.stop()

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) {
                ShellState.closeAll();
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                Wallpapers.set(Wallpapers.model.get(grid.currentIndex % grid.n, "filePath"));
            } else if (e.key === Qt.Key_R) {
                Wallpapers.random();
                grid.currentIndex = grid.nearestCopy(Wallpapers.currentIndex);
            } else {
                return;
            }
            e.accepted = true;
        }

        delegate: Item {
            id: tile
            required property int index
            // the model is just a count now, so look the file up in the folder model
            readonly property int entry: index % grid.n
            readonly property string fileName: Wallpapers.model.get(entry, "fileName")
            readonly property string filePath: Wallpapers.model.get(entry, "filePath")
            readonly property url fileUrl: Wallpapers.model.get(entry, "fileUrl")

            readonly property bool selected: filePath === Wallpapers.current
            readonly property bool focused: GridView.isCurrentItem && grid.activeFocus
            property bool thumbFailed: false

            width: grid.cellWidth
            height: grid.cellHeight

            Item {
                id: frame
                x: root.inset
                y: root.inset
                width: root.tileW
                height: root.tileH
                scale: mouse.pressed ? 0.96 : mouse.containsMouse || tile.focused ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Theme.surfaceHi

                    Image {
                        id: img
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(root.tileW * 2, root.tileH * 2)
                        source: Wallpapers.thumbsReady && !tile.thumbFailed ? Wallpapers.thumb(tile.fileName) : tile.fileUrl
                        onStatusChanged: if (status === Image.Error && !tile.thumbFailed) tile.thumbFailed = true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    }

                    // dim everything but the hovered / focused / active one a touch
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: mouse.containsMouse || tile.focused || tile.selected ? 0 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    }
                }

                // ring: solid for the active wallpaper, faint for keyboard focus
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 15
                    color: "transparent"
                    border.width: 2
                    border.color: tile.selected ? Theme.fg : Qt.rgba(1, 1, 1, 0.35)
                    opacity: tile.selected || tile.focused ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    Behavior on border.color { ColorAnimation { duration: Theme.dur } }
                }

                // check badge on the active one
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 7
                    width: 22
                    height: 22
                    radius: 11
                    color: Theme.accent
                    scale: tile.selected ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack } }
                    MIcon {
                        anchors.centerIn: parent
                        icon: "check"
                        size: 15
                        color: Theme.accentFg
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: frame
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    grid.currentIndex = tile.index;
                    Wallpapers.set(tile.filePath);
                }
            }
        }
    }

    // Over the grid (not inside it, or it would scroll with the content) and
    // takes no buttons, so clicks / hover still reach the tiles.
    MouseArea {
        anchors.fill: grid
        acceptedButtons: Qt.NoButton
        onWheel: e => {
            const px = e.pixelDelta.x !== 0 || e.pixelDelta.y !== 0;
            const d = px ? (Math.abs(e.pixelDelta.x) > Math.abs(e.pixelDelta.y) ? e.pixelDelta.x : e.pixelDelta.y)
                         : (Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y);
            const from = scrollAnim.running ? grid.scrollTarget : grid.contentX;
            grid.scrollTo(from - (px ? d * root.touchpadSpeed : d / 120 * root.wheelColumns * grid.cellWidth), !px);
            e.accepted = true;
        }
    }

    Txt {
        anchors.centerIn: grid
        visible: Wallpapers.model.count === 0
        text: "No images in ~/.config/wallpapers"
        color: Theme.fgMuted
    }
}
