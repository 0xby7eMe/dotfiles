pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services
import qs.components

// macOS-style control center: modules of 1x1 / 2x1 / 2x2 / 4x1 cells packed
// into a 4-column grid. "Edit Controls" makes them jiggle: drag to reorder,
// click to cycle sizes, − to remove, and add more from the gallery below.
DropPanel {
    id: root

    open: ShellState.controlOpen
    align: "right"
    ns: "qs-control"
    panelWidth: 392
    maxHeight: Math.min(1000, (target?.height ?? 1080) - Theme.barZone - 2 * Theme.barGap)
    contentHeight: col.implicitHeight + 34
    onDismissed: ShellState.autoClose()

    onOpenChanged: if (open) {
        uptimeProc.running = true;
        confirm = "";
    } else {
        wifiOpen = false;
        editing = false;
    }

    property string uptime: ""
    property bool wifiOpen: false
    property string confirm: ""   // action awaiting a second click
    property bool editing: false
    onEditingChanged: if (editing) wifiOpen = false

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: root.uptime = text.trim().replace(/^up /, "")
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirm = ""
    }

    function power(action: string): void {
        if (action === "lock") {
            ShellState.closeAll();
            Quickshell.execDetached(["loginctl", "lock-session"]);
            return;
        }
        if (action === "suspend") {
            ShellState.closeAll();
            Quickshell.execDetached(["systemctl", "suspend"]);
            return;
        }
        if (confirm !== action) {
            confirm = action;
            confirmTimer.restart();
            return;
        }
        ShellState.closeAll();
        if (action === "logout")
            ShellState.dispatch("hl.dsp.exit()", "exit");
        else if (action === "reboot")
            Quickshell.execDetached(["systemctl", "reboot"]);
        else if (action === "poweroff")
            Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    // ---------- module catalog ----------
    readonly property var catalog: ({
        connectivity: { name: "Connectivity", icon: "wifi", sizes: ["2x2"] },
        display: { name: "Display", icon: "sun", sizes: ["4x1", "2x1"] },
        sound: { name: "Sound", icon: "volume-2", sizes: ["4x1", "2x1"] },
        media: { name: "Now Playing", icon: "music", sizes: ["4x1", "2x2"] },
        wifi: { name: "Wi-Fi", icon: "wifi", sizes: ["1x1", "2x1"] },
        bluetooth: { name: "Bluetooth", icon: "bluetooth", sizes: ["1x1", "2x1"] },
        airplane: { name: "Airplane Mode", icon: "plane", sizes: ["1x1", "2x1"] },
        focus: { name: "Do Not Disturb", icon: "moon", sizes: ["2x1", "1x1"] },
        nightlight: { name: "Night Light", icon: "sun-moon", sizes: ["1x1", "2x1"] },
        caffeine: { name: "Caffeine", icon: "coffee", sizes: ["1x1", "2x1"] },
        power: { name: "Power Mode", icon: "zap", sizes: ["1x1", "2x1"] },
        mic: { name: "Microphone", icon: "mic", sizes: ["1x1", "2x1"] },
        battery: { name: "Battery", icon: "battery-medium", sizes: ["1x1", "2x1"] },
        screenshot: { name: "Screenshot", icon: "scan", sizes: ["1x1", "2x1"] },
        picker: { name: "Color Picker", icon: "pipette", sizes: ["1x1", "2x1"] },
        wallpaper: { name: "Wallpaper", icon: "image", sizes: ["1x1", "2x1"] },
        clipboard: { name: "Clipboard", icon: "clipboard", sizes: ["1x1", "2x1"] }
    })
    readonly property var order: ["connectivity", "display", "sound", "media", "wifi", "bluetooth", "airplane",
        "focus", "nightlight", "caffeine", "power", "mic", "battery", "screenshot", "picker", "wallpaper", "clipboard"]
    readonly property var defaults: [
        { id: "connectivity", size: "2x2" },
        { id: "focus", size: "2x1" },
        { id: "nightlight", size: "1x1" },
        { id: "caffeine", size: "1x1" },
        { id: "display", size: "4x1" },
        { id: "sound", size: "4x1" },
        { id: "media", size: "4x1" },
        { id: "power", size: "1x1" },
        { id: "mic", size: "1x1" },
        { id: "screenshot", size: "1x1" },
        { id: "picker", size: "1x1" }
    ]

    function available(id: string): bool {
        return id === "battery" ? Sys.hasBattery : root.catalog[id] !== undefined;
    }

    // Live state of the simple toggle / action modules.
    function spec(id: string): var {
        switch (id) {
        case "wifi":
            return { icon: Sys.netIcon, label: "Wi-Fi", sub: Sys.netLabel, on: Sys.wifiOn, detail: true };
        case "bluetooth":
            return { icon: Sys.btIcon, label: "Bluetooth", sub: Sys.btLabel, on: Sys.btOn };
        case "airplane":
            return { icon: "plane", label: "Airplane Mode", short: "Airplane", sub: Sys.airplane ? "On" : "Off", on: Sys.airplane };
        case "focus":
            return { icon: ShellState.dnd ? "bell-off" : "moon", label: "Do Not Disturb", short: "Focus", sub: ShellState.dnd ? "On" : "Off", on: ShellState.dnd };
        case "nightlight":
            return { icon: "sun-moon", label: "Night Light", sub: ShellState.nightLight ? "4500 K" : "Off", on: ShellState.nightLight };
        case "caffeine":
            return { icon: "coffee", label: "Caffeine", sub: ShellState.caffeine ? "Staying awake" : "Off", on: ShellState.caffeine };
        case "power":
            return { icon: Sys.profileIcon, label: "Power Mode", short: "Power", sub: Sys.profileLabel, on: Sys.profileLabel !== "Balanced" };
        case "mic":
            return { icon: Audio.micMuted ? "mic-off" : "mic", label: "Microphone", sub: Audio.micMuted ? "Muted" : "On", on: !Audio.micMuted };
        case "battery": {
            const pct = Math.round(Sys.batLevel * 100) + "%";
            return { icon: Sys.batIcon, label: "Battery", short: pct, sub: pct + (Sys.charging ? " · Charging" : ""), on: false };
        }
        case "screenshot":
            return { icon: "scan", label: "Screenshot", sub: "Select an area", on: false };
        case "picker":
            return { icon: "pipette", label: "Color Picker", short: "Picker", sub: "Copy a color", on: false };
        case "wallpaper":
            return { icon: "image", label: "Wallpaper", sub: "Change", on: false };
        case "clipboard":
            return { icon: "clipboard", label: "Clipboard", sub: "History", on: false };
        }
        return { icon: "", label: id, sub: "", on: false };
    }

    function trigger(id: string): void {
        switch (id) {
        case "wifi": Sys.toggleWifi(); break;
        case "bluetooth": Sys.toggleBt(); break;
        case "airplane": Sys.toggleAirplane(); break;
        case "focus": ShellState.dnd = !ShellState.dnd; break;
        case "nightlight": ShellState.nightLight = !ShellState.nightLight; break;
        case "caffeine": ShellState.caffeine = !ShellState.caffeine; break;
        case "power": Sys.cycleProfile(); break;
        case "mic": Audio.toggleMic(); break;
        case "wallpaper": ShellState.toggleWallpaper(); break;
        case "clipboard": ShellState.toggleLauncher("clip"); break;
        case "screenshot":
            ShellState.closeAll();
            // wait for the panel to slide away so it isn't in the shot
            ShellState.sh(`sleep 0.4; '${Quickshell.shellPath("scripts/screenshot.sh")}' region`);
            break;
        case "picker":
            ShellState.closeAll();
            ShellState.sh('sleep 0.4; c="$(hyprpicker -a)" && [ -n "$c" ] && notify-send "Color copied" "$c"');
            break;
        }
    }

    function detail(id: string): void {
        if (id === "wifi")
            wifiOpen = !wifiOpen;
    }

    // ---------- layout model ----------
    ListModel {
        id: mods
    }
    property int rev: 0   // bumped on every model change so bindings re-pack

    FileView {
        id: savedFile
        path: Quickshell.statePath("control-center.json")
        blockLoading: true
        printErrors: false
        JsonAdapter {
            id: saved
            property string layout: ""
        }
    }

    Component.onCompleted: load()

    function load(): void {
        let list = null;
        try {
            list = JSON.parse(saved.layout);
        } catch (e) {}
        fill(Array.isArray(list) ? list : defaults);
    }

    function fill(list: var): void {
        mods.clear();
        const seen = {};
        for (const m of list) {
            const c = catalog[m.id];
            if (!c || seen[m.id])
                continue;
            seen[m.id] = true;
            mods.append({ mid: m.id, size: c.sizes.includes(m.size) ? m.size : c.sizes[0] });
        }
        rev++;
    }

    function save(): void {
        const l = [];
        for (let i = 0; i < mods.count; i++)
            l.push({ id: mods.get(i).mid, size: mods.get(i).size });
        saved.layout = JSON.stringify(l);
        savedFile.writeAdapter();
        rev++;
    }

    function has(id: string): bool {
        for (let i = 0; i < mods.count; i++)
            if (mods.get(i).mid === id)
                return true;
        return false;
    }

    function add(id: string): void {
        if (has(id))
            return;
        mods.append({ mid: id, size: catalog[id].sizes[0] });
        save();
    }

    function remove(index: int): void {
        mods.remove(index, 1);
        save();
    }

    function cycleSize(index: int): void {
        const m = mods.get(index);
        const sizes = catalog[m.mid].sizes;
        mods.setProperty(index, "size", sizes[(sizes.indexOf(m.size) + 1) % sizes.length]);
        save();
    }

    // Corner-handle resize: snap to the allowed size nearest the dragged extent
    // (in cells). The current size gets a small bonus so it doesn't flicker at
    // the boundary between two sizes.
    function resizeTo(index: int, ew: real, eh: real): void {
        const m = mods.get(index);
        let best = m.size, bd = Infinity;
        for (const s of catalog[m.mid].sizes) {
            const [w, h] = s.split("x").map(Number);
            const d = (w - ew) ** 2 + (h - eh) ** 2 - (s === m.size ? 0.2 : 0);
            if (d < bd) {
                bd = d;
                best = s;
            }
        }
        if (best !== m.size) {
            mods.setProperty(index, "size", best);
            rev++;
        }
    }

    function reset(): void {
        fill(defaults);
        save();
    }

    readonly property int cols: 4
    readonly property int gap: 10

    // First-fit dense packing, row by row (like CSS grid-auto-flow: dense).
    readonly property var slots: {
        rev;
        const occ = [];
        const free = (r, c) => !(occ[r] && occ[r][c]);
        const cells = [];
        let rows = 0;
        for (let i = 0; i < mods.count; i++) {
            const m = mods.get(i);
            if (!available(m.mid)) {
                cells.push(null);
                continue;
            }
            const [w, h] = m.size.split("x").map(Number);
            let r = 0, c = 0;
            search: for (r = 0; ; r++) {
                for (c = 0; c <= cols - w; c++) {
                    let ok = true;
                    for (let dr = 0; dr < h && ok; dr++)
                        for (let dc = 0; dc < w && ok; dc++)
                            ok = free(r + dr, c + dc);
                    if (ok)
                        break search;
                }
            }
            for (let dr = 0; dr < h; dr++) {
                occ[r + dr] = occ[r + dr] ?? [];
                for (let dc = 0; dc < w; dc++)
                    occ[r + dr][c + dc] = true;
            }
            cells.push({ r: r, c: c, w: w, h: h });
            rows = Math.max(rows, r + h);
        }
        return { cells: cells, rows: rows };
    }

    readonly property var addable: {
        rev;
        return order.filter(id => available(id) && !has(id));
    }

    // Reorder while dragging: entering another module's cell moves the dragged
    // one into its place. `dragHit` stops it bouncing back and forth while the
    // pointer stays over the module that just moved.
    property string dragHit: ""
    function dragOver(from: int, px: real, py: real): void {
        const step = grid.cell + gap;
        const cells = slots.cells;
        for (let j = 0; j < cells.length; j++) {
            const s = cells[j];
            if (!s || j === from)
                continue;
            if (px >= s.c * step && px < (s.c + s.w) * step - gap && py >= s.r * step && py < (s.r + s.h) * step - gap) {
                const id = mods.get(j).mid;
                if (dragHit === id)
                    return;
                dragHit = id;
                mods.move(from, j, 1);
                rev++;
                return;
            }
        }
        dragHit = "";
        if (py > grid.height && from !== mods.count - 1) {
            mods.move(from, mods.count - 1, 1);
            rev++;
        }
    }

    // Shared wobble clock for the edit-mode jiggle.
    property real phase: 0
    NumberAnimation on phase {
        running: root.editing && root.visible
        from: 0
        to: 2 * Math.PI
        duration: 380
        loops: Animation.Infinite
    }

    ColumnLayout {
        id: col
        x: 18
        y: 16
        width: parent.width - 36
        spacing: 14

        // ---------- header ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: Theme.accent
                Txt {
                    anchors.centerIn: parent
                    text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase()
                    color: Theme.accentFg
                    font.pixelSize: 17
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt {
                    text: Quickshell.env("USER") ?? ""
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                Txt {
                    Layout.fillWidth: true
                    text: root.confirm ? "Click again to " + root.confirm.replace("poweroff", "shut down")
                        : root.uptime ? "up " + root.uptime : ""
                    font.pixelSize: 11
                    color: root.confirm ? Theme.fg : Theme.fgDim
                }
            }

            Repeater {
                model: [
                    { a: "lock", i: "lock" },
                    { a: "suspend", i: "moon-star" },
                    { a: "logout", i: "log-out" },
                    { a: "reboot", i: "rotate-cw" },
                    { a: "poweroff", i: "power" }
                ]
                IconButton {
                    required property var modelData
                    icon: modelData.i
                    iconSize: 18
                    implicitWidth: 32
                    implicitHeight: 32
                    active: root.confirm === modelData.a
                    activeColor: Theme.danger
                    activeFg: Theme.bg
                    onClicked: root.power(modelData.a)
                }
            }
        }

        // ---------- module grid ----------
        Item {
            id: grid
            Layout.fillWidth: true
            readonly property real cell: (width - (root.cols - 1) * root.gap) / root.cols
            implicitHeight: Math.max(0, root.slots.rows * (cell + root.gap) - root.gap)
            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
            }

            Txt {
                anchors.centerIn: parent
                visible: mods.count === 0
                text: "No controls — add some below"
                color: Theme.fgDim
            }

            Repeater {
                model: mods

                Item {
                    id: del
                    required property int index
                    required property string mid
                    required property string size

                    readonly property var slot: root.slots.cells[index] ?? null
                    readonly property real step: grid.cell + root.gap
                    readonly property var sizes: root.catalog[mid]?.sizes ?? []

                    property bool dragging: false
                    property bool resizing: false
                    property bool animate: true
                    property real dragX: 0
                    property real dragY: 0

                    visible: slot !== null
                    x: dragging ? dragX : slot ? slot.c * step : 0
                    y: dragging ? dragY : slot ? slot.r * step : 0
                    width: slot ? slot.w * step - root.gap : 0
                    height: slot ? slot.h * step - root.gap : 0
                    z: dragging ? 10 : 0
                    scale: dragging ? 1.06 : 1
                    opacity: dragging ? 0.9 : 1
                    rotation: root.editing && !dragging && !resizing
                        ? Math.min(0.8, 60 / Math.max(1, width)) * Math.sin(root.phase + index * 2.1) : 0

                    Behavior on x { enabled: del.animate; NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                    Behavior on y { enabled: del.animate; NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                    Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                    Behavior on height { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }
                    Behavior on scale { NumberAnimation { duration: Theme.durFast } }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: del.mid === "connectivity" ? connectivityC
                            : del.mid === "display" || del.mid === "sound" ? sliderC
                            : del.mid === "media" ? mediaC : toggleC
                    }

                    // --- module bodies ---
                    Component {
                        id: toggleC
                        CcToggle {
                            readonly property var s: root.spec(del.mid)
                            variant: del.size
                            icon: s.icon
                            label: del.size === "1x1" ? s.short ?? s.label : s.label
                            sublabel: s.sub
                            active: s.on
                            hasDetail: s.detail ?? false
                            onToggled: root.trigger(del.mid)
                            onDetail: root.detail(del.mid)
                        }
                    }

                    Component {
                        id: connectivityC
                        Rectangle {
                            radius: 20
                            color: Theme.glassHi
                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                Repeater {
                                    model: ["wifi", "bluetooth", "airplane"]
                                    CcToggle {
                                        required property string modelData
                                        readonly property var s: root.spec(modelData)
                                        width: parent.width
                                        height: parent.height / 3
                                        variant: "row"
                                        icon: s.icon
                                        label: s.label
                                        sublabel: s.sub
                                        active: s.on
                                        hasDetail: s.detail ?? false
                                        onToggled: root.trigger(modelData)
                                        onDetail: root.detail(modelData)
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: sliderC
                        Rectangle {
                            radius: 20
                            color: Theme.glassHi
                            readonly property bool sound: del.mid === "sound"
                            Txt {
                                id: sliderTitle
                                x: 14
                                y: 10
                                text: parent.sound ? "Sound" : "Display"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            Txt {
                                anchors.left: sliderTitle.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.baseline: sliderTitle.baseline
                                horizontalAlignment: Text.AlignRight
                                visible: parent.sound && del.size === "4x1"
                                text: Audio.sink?.description ?? ""
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                            QSlider {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                implicitHeight: 32
                                icon: parent.sound ? Audio.icon : "sun"
                                value: parent.sound ? Audio.volume : ShellState.brightness
                                dimmed: parent.sound && Audio.muted
                                onMoved: v => parent.sound ? Audio.setVolume(v) : ShellState.setBrightness(v)
                                onIconClicked: if (parent.sound) Audio.toggleMute()
                            }
                        }
                    }

                    Component {
                        id: mediaC
                        Rectangle {
                            radius: 20
                            color: Theme.glassHi
                            id: media
                            readonly property var p: root.player
                            readonly property bool has: p !== null && (p.trackTitle ?? "") !== ""
                            readonly property bool big: del.size === "2x2"

                            ClippingRectangle {
                                id: art
                                x: 12
                                y: media.big ? 14 : (parent.height - height) / 2
                                width: media.big ? 64 : 56
                                height: width
                                radius: 12
                                color: Theme.glassHover
                                MIcon {
                                    anchors.centerIn: parent
                                    visible: !media.has || artImg.status !== Image.Ready
                                    icon: "music"
                                    size: 22
                                    color: Theme.fgMuted
                                }
                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: media.has ? media.p.trackArtUrl ?? "" : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(128, 128)
                                }
                            }

                            ColumnLayout {
                                anchors.left: media.big ? parent.left : art.right
                                anchors.leftMargin: 12
                                anchors.right: media.big ? parent.right : controls.left
                                anchors.rightMargin: media.big ? 12 : 4
                                y: media.big ? art.y + art.height + 8 : (parent.height - height) / 2
                                spacing: 1
                                Txt {
                                    Layout.fillWidth: true
                                    text: media.has ? media.p.trackTitle : "Not Playing"
                                    font.weight: Font.Bold
                                    color: media.has ? Theme.fg : Theme.fgDim
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    visible: media.has
                                    text: media.p?.trackArtist ?? ""
                                    font.pixelSize: 11
                                    color: Theme.fgDim
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 5
                                    implicitHeight: 3
                                    radius: 2
                                    color: Theme.glassHover
                                    visible: media.has && media.p.lengthSupported && media.p.length > 0
                                    Rectangle {
                                        height: parent.height
                                        radius: 2
                                        color: Theme.fg
                                        width: parent.width * Math.min(1, (media.p?.position ?? 0) / Math.max(1, media.p?.length ?? 1))
                                    }
                                    // position isn't pushed by mpris; poll while visible
                                    Timer {
                                        running: root.open && parent.visible && (media.p?.isPlaying ?? false)
                                        interval: 1000
                                        repeat: true
                                        onTriggered: media.p.positionChanged()
                                    }
                                }
                            }

                            Row {
                                id: controls
                                x: media.big ? (parent.width - width) / 2 : parent.width - width - 8
                                y: media.big ? parent.height - height - 8 : (parent.height - height) / 2
                                opacity: media.has ? 1 : 0.4
                                enabled: media.has
                                IconButton { glyph: "prev"; iconSize: 18; onClicked: media.p.previous() }
                                IconButton {
                                    glyph: media.p?.isPlaying ? "pause" : "play"
                                    iconSize: 20
                                    active: true
                                    onClicked: media.p.togglePlaying()
                                }
                                IconButton { glyph: "next"; iconSize: 18; onClicked: media.p.next() }
                            }
                        }
                    }

                    // --- edit mode: swallow input, drag to reorder, click to resize ---
                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        visible: root.editing
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: del.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property point start
                        property bool moved: false

                        onPressed: e => {
                            start = Qt.point(e.x, e.y);
                            moved = false;
                        }
                        onPositionChanged: e => {
                            if (!pressed)
                                return;
                            if (!moved) {
                                if (Math.hypot(e.x - start.x, e.y - start.y) < 6)
                                    return;
                                moved = true;
                                root.dragHit = "";
                                del.animate = false;
                                del.dragX = del.x;
                                del.dragY = del.y;
                                del.dragging = true;
                            }
                            const p = mapToItem(grid, e.x, e.y);
                            del.dragX = p.x - start.x;
                            del.dragY = p.y - start.y;
                            root.dragOver(del.index, p.x, p.y);
                        }
                        onReleased: {
                            if (moved) {
                                del.animate = true;
                                del.dragging = false;
                                root.save();
                            } else if (del.sizes.length > 1) {
                                root.cycleSize(del.index);
                            }
                        }
                        onCanceled: {
                            del.animate = true;
                            del.dragging = false;
                        }
                    }

                    // remove badge
                    Rectangle {
                        x: -7
                        y: -7
                        width: 22
                        height: 22
                        radius: 11
                        color: rmMouse.containsMouse ? Theme.danger : "#4a4a4a"
                        border.width: 1
                        border.color: Theme.borderHi
                        opacity: root.editing && !del.dragging ? 1 : 0
                        scale: root.editing ? 1 : 0.4
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        MIcon {
                            anchors.centerIn: parent
                            icon: "minus"
                            size: 14
                        }
                        MouseArea {
                            id: rmMouse
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.remove(del.index)
                        }
                    }

                    // resize handle: drag the corner to resize, click to cycle sizes
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -5
                        width: 20
                        height: 20
                        radius: 10
                        color: rsMouse.containsMouse || rsMouse.pressed ? Theme.accent : "#4a4a4a"
                        border.width: 1
                        border.color: Theme.borderHi
                        opacity: root.editing && !del.dragging && del.sizes.length > 1 ? 1 : 0
                        scale: rsMouse.pressed ? 1.2 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        MIcon {
                            anchors.centerIn: parent
                            icon: "move-diagonal-2"
                            size: 11
                            color: rsMouse.containsMouse || rsMouse.pressed ? Theme.accentFg : Theme.fg
                        }

                        MouseArea {
                            id: rsMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.SizeFDiagCursor

                            property point start
                            property int w0
                            property int h0
                            property bool moved: false

                            onPressed: e => {
                                start = mapToItem(grid, e.x, e.y);
                                w0 = del.slot.w;
                                h0 = del.slot.h;
                                moved = false;
                            }
                            onPositionChanged: e => {
                                if (!pressed)
                                    return;
                                // map into the grid so the handle moving with the module doesn't matter
                                const p = mapToItem(grid, e.x, e.y);
                                if (!moved) {
                                    if (Math.hypot(p.x - start.x, p.y - start.y) < 4)
                                        return;
                                    moved = true;
                                    del.resizing = true;
                                }
                                root.resizeTo(del.index, w0 + (p.x - start.x) / del.step, h0 + (p.y - start.y) / del.step);
                            }
                            onReleased: {
                                if (moved)
                                    root.save();
                                else
                                    root.cycleSize(del.index);
                                del.resizing = false;
                            }
                            onCanceled: {
                                del.resizing = false;
                                root.save();
                            }
                        }
                    }
                }
            }
        }

        WifiView {
            Layout.fillWidth: true
            Layout.topMargin: visible ? -4 : 0
            shown: root.wifiOpen
        }

        // ---------- edit controls ----------
        Pill {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.editing
            text: "Edit Controls"
            icon: "sliders-horizontal"
            onClicked: root.editing = true
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.editing
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                Txt {
                    text: "Add Controls"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }
                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "Drag to move · drag corner to resize"
                    font.pixelSize: 11
                    color: Theme.fgMuted
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.addable.length > 0

                Repeater {
                    model: root.addable
                    Pill {
                        required property string modelData
                        text: root.catalog[modelData].name
                        icon: root.catalog[modelData].icon
                        trailing: "plus"
                        onClicked: root.add(modelData)
                    }
                }
            }

            Txt {
                visible: root.addable.length === 0
                text: "Every control is already added"
                font.pixelSize: 11
                color: Theme.fgMuted
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Pill {
                    text: "Reset"
                    icon: "rotate-ccw"
                    onClicked: root.reset()
                }
                Item {
                    Layout.fillWidth: true
                }
                Pill {
                    text: "Done"
                    icon: "check"
                    primary: true
                    onClicked: root.editing = false
                }
            }
        }
    }
}
