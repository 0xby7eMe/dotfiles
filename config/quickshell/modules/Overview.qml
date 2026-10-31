pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// Super+Tab workspace overview on the focused monitor: every workspace as a
// mini screen with live window previews. Click a window to focus it, click a
// workspace to switch, drag a window onto another workspace to move it there,
// middle-click to close. Typing filters windows (Tab cycles, Enter focuses);
// with an empty search, arrows / 1–0 pick a workspace.
PanelWindow {
    id: win

    readonly property bool open: ShellState.overviewOpen

    property ShellScreen target: Quickshell.screens[0]
    screen: target

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || p > 0.002
    WlrLayershell.namespace: "qs-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Start the open animation only once the surface is mapped and has drawn
    // its first frame. Mapping a fullscreen layer surface (and building its
    // scene graph) takes a few frames; animating meanwhile made the open look
    // like a jump. The timer is a fallback in case no frame arrives.
    property bool ready: false
    Connections {
        target: win.contentItem.Window.window
        enabled: win.open && !win.ready
        function onFrameSwapped(): void {
            win.ready = true;
        }
    }
    Timer {
        running: win.open && !win.ready
        interval: 150
        onTriggered: win.ready = true
    }

    property real p: open && ready ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: win.open ? Theme.durSlow : Theme.dur
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }

    property string query: ""
    property int selected: 1     // keyboard-selected workspace (empty search)
    property int matchIndex: 0   // selected search match
    property var hovered: null   // HyprlandToplevel under the pointer
    property var dragged: null   // HyprlandToplevel being dragged
    property int dropWs: 0

    onOpenChanged: {
        if (!open) {
            ready = false;
            dragged = null;
            hovered = null;
            return;
        }
        target = Quickshell.screens.find(s => s.name === ShellState.overlayScreen) ?? Quickshell.screens[0];
        refresh();
        search.text = "";
        selected = activeId;
        Qt.callLater(() => search.forceActiveFocus());
    }

    HyprlandFocusGrab {
        active: win.open && win.visible
        windows: [win]
        onCleared: ShellState.overviewOpen = false
    }

    // ---------- data ----------
    // Window geometry comes from Hyprland's IPC objects, which only update on
    // request; refresh (debounced) on every event while open.
    function refresh(): void {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }
    Timer {
        id: refreshTimer
        interval: 60
        onTriggered: win.refresh()
    }
    // Title changes don't move anything (titles update on their own), and
    // terminals retitle constantly, so they don't trigger a refetch.
    readonly property var quietEvents: ["windowtitle", "windowtitlev2", "activewindow"]
    Connections {
        target: Hyprland
        enabled: win.open
        function onRawEvent(event: HyprlandEvent): void {
            if (!win.quietEvents.includes(event.name))
                refreshTimer.restart();
        }
    }

    // Previews: one snapshot on open, then 5 fps once the open animation has
    // settled. Only the hovered / picked window (and a dragged one) streams at
    // full rate; capturing every window at 144 Hz was the main GPU cost.
    readonly property bool settled: open && p >= 1
    Timer {
        id: previewTick
        interval: 200
        repeat: true
        running: win.settled
    }

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(target)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var geom: monGeom(monitor)

    // Logical geometry of a monitor in global layout coordinates.
    function monGeom(m: var): var {
        const o = m?.lastIpcObject ?? {};
        const s = o.scale || 1;
        const swap = (o.transform ?? 0) % 2 === 1;
        return {
            x: o.x ?? 0,
            y: o.y ?? 0,
            w: ((swap ? o.height : o.width) / s) || target.width,
            h: ((swap ? o.width : o.height) / s) || target.height
        };
    }

    // Workspaces 1..N: at least 5, plus one empty slot after the last used one.
    readonly property int count: {
        let m = Math.max(4, activeId);
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0 && w.id <= 10 && (w.toplevels?.values?.length ?? 0) > 0)
                m = Math.max(m, w.id);
        return Math.min(10, m + 1);
    }

    readonly property var windows: Hyprland.toplevels.values.filter(t => {
        const o = t.lastIpcObject;
        return o?.at !== undefined && o.mapped !== false && !o.hidden && (o.workspace?.id ?? 0) > 0;
    })

    function wsOf(t: var): int {
        return t?.lastIpcObject?.workspace?.id ?? 0;
    }

    function matches(t: var): bool {
        const o = t.lastIpcObject;
        return ((o.title ?? "") + " " + (o.class ?? "")).toLowerCase().includes(query.trim().toLowerCase());
    }

    // Search hits, most recently focused first.
    readonly property var matched: query.trim() === "" ? []
        : windows.filter(matches).sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 0) - (b.lastIpcObject.focusHistoryID ?? 0))
    onMatchedChanged: matchIndex = 0

    function iconFor(cls: string): string {
        const icon = DesktopEntries.heuristicLookup(cls)?.icon ?? cls;
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.iconPath(icon, "application-x-executable");
    }

    function appName(cls: string): string {
        return DesktopEntries.heuristicLookup(cls)?.name ?? cls;
    }

    // ---------- actions ----------
    function addr(t: var): string {
        return t.lastIpcObject?.address ?? ("0x" + t.address);
    }

    function focusWindow(t: var): void {
        const a = addr(t);
        ShellState.overviewOpen = false;
        ShellState.dispatch(`hl.dsp.focus({ window = "address:${a}" })`, `focuswindow address:${a}`);
    }

    function moveWindow(t: var, ws: int): void {
        const a = addr(t);
        ShellState.dispatch(`hl.dsp.window.move({ workspace = ${ws}, follow = false, window = "address:${a}" })`,
            `movetoworkspacesilent ${ws},address:${a}`);
        refreshTimer.restart();
    }

    function closeWindow(t: var): void {
        const a = addr(t);
        ShellState.dispatch(`hl.dsp.window.close({ window = "address:${a}" })`, `closewindow address:${a}`);
        refreshTimer.restart();
    }

    function goTo(ws: int): void {
        ShellState.overviewOpen = false;
        ShellState.focusWorkspace(String(ws));
    }

    function wsAt(p: point): int {
        const q = grid.mapFromItem(win.contentItem, p.x, p.y);
        return grid.childAt(q.x, q.y)?.wsId ?? 0;
    }

    // Move the keyboard selection around the grid.
    function step(dx: int, dy: int): void {
        let i = selected - 1 + dx + dy * cols;
        if (dy !== 0 && (i < 0 || i >= count))
            return;
        selected = (i + count) % count + 1;
    }

    // ---------- layout ----------
    readonly property int cols: count <= 5 ? count : Math.ceil(count / 2)
    readonly property int rows: Math.ceil(count / cols)
    readonly property int gap: 26
    readonly property int labelH: 34
    readonly property real aspect: geom.w / geom.h
    // Sized from the target screen, not the window, whose size resets while
    // hidden (that re-laid out and re-animated every preview on each open).
    readonly property real cellW: Math.min((target.width * 0.9 - (cols - 1) * gap) / cols,
        ((target.height - 300) / rows - labelH - gap) * aspect)
    readonly property real cellH: cellW / aspect

    // ---------- ui ----------
    // dim + blur backdrop (see the qs-overview layer rule); click to close
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.overviewOpen = false
    }

    // search
    Rectangle {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: grid.y - height - 44 - (1 - win.p) * 20
        width: 440
        height: 46
        radius: 23
        color: Theme.glass
        border.width: 1
        border.color: search.text !== "" ? Theme.borderHi : Theme.border
        opacity: win.p

        MIcon {
            id: searchIcon
            x: 17
            anchors.verticalCenter: parent.verticalCenter
            icon: "search"
            size: 19
            color: Theme.fgDim
        }

        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: hitCount.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.Medium
            color: Theme.fg
            selectionColor: Theme.fg
            selectedTextColor: Theme.bg
            clip: true
            onTextChanged: win.query = text

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text.length === 0
                text: "Search windows…"
                color: Theme.fgMuted
                font.pixelSize: 15
            }

            Keys.onPressed: e => {
                const searching = win.query.trim() !== "";
                const n = win.matched.length;
                if (e.key === Qt.Key_Escape) {
                    if (search.text !== "")
                        search.text = "";
                    else
                        ShellState.overviewOpen = false;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    if (searching) {
                        if (n > 0)
                            win.focusWindow(win.matched[win.matchIndex]);
                    } else {
                        win.goTo(win.selected);
                    }
                } else if (searching && (e.key === Qt.Key_Tab || e.key === Qt.Key_Down)) {
                    win.matchIndex = n ? (win.matchIndex + 1) % n : 0;
                } else if (searching && (e.key === Qt.Key_Backtab || e.key === Qt.Key_Up)) {
                    win.matchIndex = n ? (win.matchIndex - 1 + n) % n : 0;
                } else if (!searching && (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)) {
                    win.step(1, 0);
                } else if (!searching && (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)) {
                    win.step(-1, 0);
                } else if (!searching && e.key === Qt.Key_Down) {
                    win.step(0, 1);
                } else if (!searching && e.key === Qt.Key_Up) {
                    win.step(0, -1);
                } else if (search.text === "" && e.key >= Qt.Key_0 && e.key <= Qt.Key_9 && !(e.modifiers & ~Qt.KeypadModifier)) {
                    win.goTo(e.key === Qt.Key_0 ? 10 : e.key - Qt.Key_0);
                } else {
                    return;
                }
                e.accepted = true;
            }
        }

        Txt {
            id: hitCount
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: win.query.trim() !== ""
            text: win.matched.length ? `${win.matchIndex + 1}/${win.matched.length}` : "0"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.fgMuted
        }
    }

    // workspaces
    Grid {
        id: grid
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 20
        columns: win.cols
        columnSpacing: win.gap
        rowSpacing: win.gap

        Repeater {
            model: win.count

            Item {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                readonly property var g: ws?.monitor ? win.monGeom(ws.monitor) : win.geom
                readonly property bool current: wsId === win.activeId
                readonly property bool shownElsewhere: !current && ws !== null && ws.monitor?.activeWorkspace === ws
                readonly property bool selected: win.query.trim() === "" && win.dragged === null && wsId === win.selected
                readonly property bool dropping: win.dragged !== null && win.dropWs === wsId && win.wsOf(win.dragged) !== wsId
                readonly property var wins: win.windows.filter(t => win.wsOf(t) === wsId)

                // staggered entrance
                readonly property real t: Math.max(0, Math.min(1, win.p * 1.6 - index * 0.06))
                width: win.cellW
                height: win.cellH + win.labelH
                opacity: t
                scale: 0.92 + 0.08 * t
                transform: Translate { y: (1 - cell.t) * 26 }

                RectangularShadow {
                    anchors.fill: screenRect
                    radius: screenRect.radius
                    blur: 28
                    spread: 2
                    offset.y: 8
                    color: Qt.rgba(0, 0, 0, 0.55)
                    scale: screenRect.scale
                }

                ClippingRectangle {
                    id: screenRect
                    width: parent.width
                    height: win.cellH
                    radius: 14
                    color: Theme.surface
                    scale: cell.dropping ? 1.03 : cellMouse.containsMouse && win.dragged === null ? 1.012 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack } }

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.source
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 512
                        asynchronous: true
                        opacity: cell.current || cell.selected || cell.dropping ? 0.75 : 0.45
                        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.goTo(cell.wsId)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: cell.wins.length === 0
                        opacity: cellMouse.containsMouse || cell.dropping ? 0.9 : 0.4
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        MIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: cell.dropping ? "arrow-down-to-line" : "plus"
                            size: 20
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: cell.wins
                        }

                        Item {
                            id: thumb
                            required property var modelData
                            readonly property var o: modelData.lastIpcObject
                            readonly property real sx: screenRect.width / cell.g.w
                            readonly property real sy: screenRect.height / cell.g.h
                            readonly property bool searching: win.query.trim() !== ""
                            readonly property bool hit: !searching || win.matches(modelData)
                            readonly property bool picked: searching && win.matched[win.matchIndex] === modelData
                            readonly property bool hover: win.hovered === modelData && win.dragged === null
                            readonly property real iconSize: Math.max(14, Math.min(36, Math.min(width, height) * 0.34))

                            x: ((o.at?.[0] ?? 0) - cell.g.x) * sx
                            y: ((o.at?.[1] ?? 0) - cell.g.y) * sy
                            width: Math.max(8, (o.size?.[0] ?? 0) * sx)
                            height: Math.max(8, (o.size?.[1] ?? 0) * sy)
                            // floating above tiled, most recently focused on top
                            z: (o.fullscreen ? 3 : o.floating ? 2 : 1) - (o.focusHistoryID ?? 0) * 0.001
                            opacity: win.dragged === modelData ? 0.25 : hit ? 1 : 0.22
                            scale: hover || picked ? 1.03 : 1

                            Behavior on x { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                            Behavior on y { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                            Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                            Behavior on height { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 7
                                color: Theme.surfaceHi

                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    captureSource: win.visible ? thumb.modelData.wayland : null
                                    live: win.settled && (thumb.hover || thumb.picked)
                                    opacity: hasContent ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }

                                    Connections {
                                        target: previewTick
                                        function onTriggered(): void {
                                            if (!shot.live)
                                                shot.captureFrame();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                color: "transparent"
                                border.width: thumb.hover || thumb.picked ? 2 : 1
                                border.color: thumb.hover || thumb.picked ? Theme.fg : Theme.borderHi
                            }

                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: shot.hasContent ? parent.bottom : undefined
                                anchors.bottomMargin: Math.min(8, thumb.height * 0.08)
                                anchors.verticalCenter: shot.hasContent ? undefined : parent.verticalCenter
                                implicitSize: thumb.iconSize
                                source: win.iconFor(thumb.o.class ?? "")
                                asynchronous: true
                                mipmap: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: win.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                property point start
                                property bool moved: false

                                onEntered: win.hovered = thumb.modelData
                                onExited: if (win.hovered === thumb.modelData) win.hovered = null
                                onPressed: e => {
                                    start = Qt.point(e.x, e.y);
                                    moved = false;
                                }
                                onPositionChanged: e => {
                                    if (!(pressedButtons & Qt.LeftButton))
                                        return;
                                    const p = mapToItem(win.contentItem, e.x, e.y);
                                    if (!moved) {
                                        if (Math.hypot(e.x - start.x, e.y - start.y) < 8)
                                            return;
                                        moved = true;
                                        ghost.begin(thumb, start);
                                    }
                                    ghost.moveTo(p);
                                }
                                onReleased: e => {
                                    if (moved)
                                        ghost.end();
                                    else if (e.button === Qt.MiddleButton)
                                        win.closeWindow(thumb.modelData);
                                    else
                                        win.focusWindow(thumb.modelData);
                                }
                                onCanceled: if (moved) ghost.cancel()
                            }
                        }
                    }
                }

                // selection / current / drop ring
                Rectangle {
                    anchors.fill: screenRect
                    scale: screenRect.scale
                    radius: screenRect.radius
                    color: "transparent"
                    border.width: cell.selected || cell.dropping ? 2 : 1
                    border.color: cell.dropping || cell.selected ? Theme.fg
                        : cell.current ? Qt.rgba(1, 1, 1, 0.4) : Theme.borderHi
                    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                }

                // label
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.cellH + 10
                    spacing: 7

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: cell.current ? 14 : 6
                        height: 6
                        radius: 3
                        color: cell.current ? Theme.fg : cell.shownElsewhere ? Theme.fgDim : Qt.rgba(1, 1, 1, 0.25)
                        Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack } }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.wsId
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: cell.current || cell.selected ? Theme.fg : Theme.fgDim
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Quickshell.screens.length > 1 && cell.ws !== null
                        text: cell.ws?.monitor?.name ?? ""
                        font.pixelSize: 11
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }

    // dragged window, following the pointer
    Item {
        id: ghost
        z: 100
        visible: win.dragged !== null
        property point hot

        function begin(th: Item, start: point): void {
            win.dragged = th.modelData;
            width = th.width;
            height = th.height;
            hot = start;
        }
        function moveTo(p: point): void {
            x = p.x - hot.x;
            y = p.y - hot.y;
            win.dropWs = win.wsAt(p);
        }
        function end(): void {
            if (win.dropWs > 0 && win.dropWs !== win.wsOf(win.dragged))
                win.moveWindow(win.dragged, win.dropWs);
            cancel();
        }
        function cancel(): void {
            win.dragged = null;
            win.dropWs = 0;
        }

        RectangularShadow {
            anchors.fill: parent
            radius: 8
            blur: 24
            offset.y: 10
            color: Qt.rgba(0, 0, 0, 0.6)
        }
        ClippingRectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.surfaceHi
            border.width: 2
            border.color: Theme.fg
            ScreencopyView {
                anchors.fill: parent
                captureSource: win.dragged?.wayland ?? null
                live: true
            }
        }
        IconImage {
            anchors.centerIn: parent
            implicitSize: Math.max(16, Math.min(40, Math.min(parent.width, parent.height) * 0.34))
            source: win.dragged ? win.iconFor(win.dragged.lastIpcObject?.class ?? "") : ""
        }
    }

    // caption: hovered / picked window, or usage hints
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: grid.y + grid.height + 34 + (1 - win.p) * 20
        spacing: 14
        opacity: win.p

        readonly property var shown: win.dragged ?? win.hovered ?? win.matched[win.matchIndex] ?? null

        Item {
            id: caption
            readonly property var w: parent.shown
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(win.width * 0.6, Math.max(captionRow.implicitWidth, 1))
            height: 22
            opacity: w ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

            Row {
                id: captionRow
                anchors.centerIn: parent
                spacing: 10
                Txt {
                    text: caption.w ? win.appName(caption.w.lastIpcObject?.class ?? "") : ""
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
                Txt {
                    width: Math.min(implicitWidth, win.width * 0.45)
                    text: caption.w?.lastIpcObject?.title ?? ""
                    font.pixelSize: 14
                    color: Theme.fgDim
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Repeater {
                model: [
                    { k: "Click", t: "focus" },
                    { k: "Drag", t: "move" },
                    { k: "Middle", t: "close window" },
                    { k: "Tab", t: "next match" },
                    { k: "1–0", t: "workspace" },
                    { k: "Esc", t: "exit" }
                ]
                Row {
                    required property var modelData
                    spacing: 6
                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.k
                        size: 10
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.t
                        font.pixelSize: 11
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }
}
