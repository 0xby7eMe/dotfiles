pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Super+/ keybind cheat sheet. Reads the live binds from `hyprctl binds -j`
// each time it opens, so it never drifts from the config. Binds are shown when
// they have a description of the form "Category: what it does" (set in
// hypr/modules/keybindings.lua); binds sharing a description are merged.
PanelWindow {
    id: win

    readonly property bool open: ShellState.cheatsheetOpen

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
    WlrLayershell.namespace: "qs-cheatsheet"
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

    onOpenChanged: {
        if (!open) {
            ready = false;
            return;
        }
        target = Quickshell.screens.find(s => s.name === ShellState.overlayScreen) ?? Quickshell.screens[0];
        search.text = "";
        flick.contentY = 0;
        bindsProc.running = true;
        Qt.callLater(() => search.forceActiveFocus());
    }

    HyprlandFocusGrab {
        active: win.open && win.visible
        windows: [win]
        onCleared: ShellState.cheatsheetOpen = false
    }

    // ---------- data ----------
    property var groups: []   // [{ name, items: [{ desc, chords: [{ mods, keys }], search }] }]
    property string bindsJson: ""

    // Fetched at startup and re-checked on every open; the rows are only
    // rebuilt when the binds actually changed, since recreating every row
    // mid-animation is what made opening stutter.
    Process {
        id: bindsProc
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === win.bindsJson)
                    return;
                try {
                    win.groups = win.parse(JSON.parse(text));
                    win.bindsJson = text;
                } catch (e) {
                    console.warn("cheatsheet: bad hyprctl output:", e);
                }
            }
        }
    }

    // macOS order (⌃ ⌥ ⇧ ⌘); shown as symbols, searchable by name.
    readonly property var modBits: [[4, "Ctrl"], [8, "Alt"], [1, "Shift"], [64, "Super"]]
    readonly property var modGlyphs: ({ Super: "⌘", Ctrl: "⌃", Alt: "⌥", Shift: "⇧" })
    readonly property var keyNames: ({
        Return: "↩", space: "Space", Escape: "esc", BackSpace: "⌫", Delete: "⌦", Print: "PrtSc", Page_Up: "PgUp", Page_Down: "PgDn",
        left: "←", right: "→", up: "↑", down: "↓", slash: "/", question: "?", Tab: "⇥",
        Super_L: "Super", Super_R: "Super",
        "mouse:272": "Left drag", "mouse:273": "Right drag", mouse_down: "Scroll ↓", mouse_up: "Scroll ↑",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −",
        XF86AudioNext: "Next", XF86AudioPrev: "Prev", XF86AudioPlay: "Play", XF86AudioPause: "Pause"
    })

    readonly property var catIcons: ({
        Apps: "app-window", Media: "play", Screenshots: "camera", Session: "power",
        Shell: "panels-top-left", Windows: "square-stack", Workspaces: "layout-grid"
    })

    function keyName(k: string): string {
        if (keyNames[k] !== undefined)
            return keyNames[k];
        k = k.replace(/^XF86/, "");
        return k.length === 1 ? k.toUpperCase() : k;
    }

    // Merge chords that differ only in their last key: Super+← / → / ↑ / ↓,
    // and long runs collapse to a range: Super+1 … Super+0 → Super + 1–0.
    function compress(combos: var): var {
        const byMods = {};
        const order = [];
        for (const c of combos) {
            // a bare modifier tap stays its own chord
            const m = c.mods.join("+") + (c.key === "" ? "|tap" : "");
            if (!byMods[m]) {
                byMods[m] = [];
                order.push(m);
            }
            if (c.key !== "" && !byMods[m].includes(c.key))
                byMods[m].push(c.key);
        }
        return order.map(m => {
            const keys = byMods[m];
            return {
                mods: m ? m.replace("|tap", "").split("+") : [],
                keys: keys.length > 4 ? [keys[0] + "–" + keys[keys.length - 1]] : keys
            };
        });
    }

    function parse(binds: var): var {
        const groups = [];
        const byCat = {};
        const items = {};
        for (const b of binds) {
            const raw = (b.description ?? "").trim();
            if (!raw)
                continue;
            const i = raw.indexOf(":");
            const cat = i > 0 ? raw.slice(0, i).trim() : "Other";
            const desc = i > 0 ? raw.slice(i + 1).trim() : raw;
            if (!byCat[cat]) {
                byCat[cat] = { name: cat, items: [] };
                groups.push(byCat[cat]);
            }
            const id = cat + "\n" + desc;
            if (!items[id]) {
                items[id] = { desc: desc, combos: [] };
                byCat[cat].items.push(items[id]);
            }
            const mods = modBits.filter(([bit]) => b.modmask & bit).map(([, n]) => n);
            let key = keyName(b.key ?? "");
            if (mods.includes(key))   // e.g. a bare tap of Super
                key = "";
            items[id].combos.push({ mods: mods, key: key });
        }
        for (const g of groups)
            for (const it of g.items) {
                it.chords = compress(it.combos);
                it.search = (g.name + " " + it.desc + " " + it.chords.map(c => c.mods.concat(c.keys).join(" ")).join(" ")).toLowerCase();
            }
        return groups;
    }

    readonly property int total: groups.reduce((n, g) => n + g.items.length, 0)
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var shown: groups
        .map(g => ({ name: g.name, items: query ? g.items.filter(it => it.search.includes(query)) : g.items }))
        .filter(g => g.items.length > 0)

    // Masonry: each group goes into the currently shortest column.
    // Sized from the target screen, not the window: the window's size resets
    // while it's hidden, which flipped the column count (and rebuilt every
    // row) on each open.
    readonly property int cardW: Math.min(1180, target.width - 120)
    readonly property int colCount: cardW > 1050 ? 3 : 2
    readonly property var columns: {
        const cols = [];
        const h = [];
        for (let i = 0; i < colCount; i++) {
            cols.push([]);
            h.push(0);
        }
        for (const g of shown) {
            const i = h.indexOf(Math.min(...h));
            cols[i].push(g);
            h[i] += g.items.length + 1.3;
        }
        return cols;
    }

    // ---------- ui ----------
    // tint + blur backdrop (see the qs-overlay-blur layer rule); click to close
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.p
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.cheatsheetOpen = false
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: 64
        spread: 4
        offset.y: 24
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: card.opacity
        scale: card.scale
    }

    // Frosted glass sheet over the blurred desktop (see GlassPanel).
    GlassPanel {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - win.p) * 30
        width: win.cardW
        height: Math.min(win.target.height - 140, toolbar.height + flick.anchors.topMargin + flick.contentHeight
            + flick.anchors.bottomMargin + footer.height)
        radius: 26
        opacity: win.p
        scale: 0.96 + 0.04 * win.p

        // While fading / scaling, draw the card as one cached texture instead
        // of re-rendering hundreds of rows and keycaps every frame. At rest
        // (p = 1, scale 1) it renders directly again, pixel-exact.
        layer.enabled: win.p < 1
        layer.smooth: true

        Behavior on height {
            enabled: win.open && win.p >= 1
            NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
        }

        // swallow clicks so they don't reach the backdrop
        MouseArea {
            anchors.fill: parent
        }

        // ---------- toolbar ----------
        Item {
            id: toolbar
            width: parent.width
            height: 72

            Rectangle {
                id: appIcon
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 10
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                }
                MIcon {
                    anchors.centerIn: parent
                    icon: "command"
                    size: 19
                }
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Txt {
                    text: "Keyboard Shortcuts"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                Txt {
                    text: win.total + " shortcuts · live from Hyprland"
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
            }

            // macOS search field: rounded rect, glyph, clear button
            Rectangle {
                id: searchField
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                height: 30
                radius: 8
                color: Qt.rgba(1, 1, 1, search.text !== "" ? 0.1 : 0.07)
                border.width: 1
                border.color: search.text !== "" ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                MIcon {
                    id: searchIcon
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "search"
                    size: 14
                    color: Theme.fgDim
                }

                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 7
                    anchors.right: clear.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.fg
                    selectionColor: Theme.fg
                    selectedTextColor: Theme.bg
                    clip: true

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: "Search"
                        color: Theme.fgMuted
                        font.pixelSize: 13
                    }

                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) {
                            if (search.text !== "")
                                search.text = "";
                            else
                                ShellState.cheatsheetOpen = false;
                        } else if (e.key === Qt.Key_Down || e.key === Qt.Key_PageDown) {
                            flick.flick(0, e.key === Qt.Key_Down ? -900 : -2400);
                        } else if (e.key === Qt.Key_Up || e.key === Qt.Key_PageUp) {
                            flick.flick(0, e.key === Qt.Key_Up ? 900 : 2400);
                        } else {
                            return;
                        }
                        e.accepted = true;
                    }
                }

                Rectangle {
                    id: clear
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.35)
                    opacity: search.text !== "" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                    MIcon {
                        anchors.centerIn: parent
                        icon: "x"
                        size: 11
                        color: "#1c1c1c"
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            search.text = "";
                            search.forceActiveFocus();
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }
        }

        // ---------- sections ----------
        Flickable {
            id: flick
            x: 24
            anchors.top: toolbar.bottom
            anchors.topMargin: 20
            anchors.bottom: footer.top
            anchors.bottomMargin: 12
            width: parent.width - 48
            contentHeight: body.implicitHeight + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: body
                width: parent.width
                spacing: 20

                Repeater {
                    model: win.columns

                    Column {
                        id: column
                        required property var modelData
                        width: (body.width - (win.colCount - 1) * body.spacing) / win.colCount
                        spacing: 20

                        Repeater {
                            model: column.modelData

                            Column {
                                id: group
                                required property var modelData
                                width: column.width
                                spacing: 8

                                Row {
                                    leftPadding: 6
                                    spacing: 7
                                    MIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: win.catIcons[group.modelData.name] ?? "command"
                                        size: 13
                                        color: Theme.fgDim
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: group.modelData.name
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: Theme.fgDim
                                    }
                                }

                                // inset grouped list, like System Settings
                                Rectangle {
                                    width: group.width
                                    height: rows.implicitHeight
                                    radius: 11
                                    color: Qt.rgba(1, 1, 1, 0.045)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.06)

                                    Column {
                                        id: rows
                                        width: parent.width

                                        Repeater {
                                            model: group.modelData.items

                                            Item {
                                                id: row
                                                required property var modelData
                                                required property int index
                                                readonly property bool last: index === group.modelData.items.length - 1
                                                width: rows.width
                                                height: Math.max(38, chords.implicitHeight + 12)

                                                Rectangle {
                                                    anchors.fill: parent
                                                    anchors.margins: 3
                                                    radius: 8
                                                    color: Qt.rgba(1, 1, 1, rowMouse.containsMouse ? 0.06 : 0)
                                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                                }

                                                MouseArea {
                                                    id: rowMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                Txt {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 14
                                                    anchors.right: chords.left
                                                    anchors.rightMargin: 12
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: row.modelData.desc
                                                    font.pixelSize: 13
                                                    color: rowMouse.containsMouse ? Theme.fg : Qt.rgba(1, 1, 1, 0.86)
                                                }

                                                Row {
                                                    id: chords
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 8

                                                    Repeater {
                                                        model: row.modelData.chords

                                                        Row {
                                                            id: chord
                                                            required property var modelData
                                                            required property int index
                                                            spacing: 3

                                                            Txt {
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                visible: chord.index > 0
                                                                text: "or"
                                                                font.pixelSize: 10
                                                                color: Theme.fgMuted
                                                                rightPadding: 5
                                                            }
                                                            Repeater {
                                                                model: chord.modelData.mods
                                                                Keycap {
                                                                    required property string modelData
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    text: win.modGlyphs[modelData] ?? modelData
                                                                    size: 10
                                                                }
                                                            }
                                                            Repeater {
                                                                model: chord.modelData.keys
                                                                Row {
                                                                    id: alt
                                                                    required property string modelData
                                                                    required property int index
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    spacing: 3
                                                                    Txt {
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        visible: alt.index > 0
                                                                        text: "/"
                                                                        font.pixelSize: 11
                                                                        color: Theme.fgMuted
                                                                    }
                                                                    Keycap {
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        text: alt.modelData
                                                                        size: 10
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // hairline separator, inset from the leading edge
                                                Rectangle {
                                                    visible: !row.last
                                                    x: 14
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width - 14
                                                    height: 1
                                                    color: Qt.rgba(1, 1, 1, 0.06)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: flick
            visible: win.shown.length === 0
            spacing: 10
            MIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "search-x"
                size: 28
                color: Theme.fgMuted
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.groups.length === 0 ? "No described binds found — add descriptions in keybindings.lua"
                    : "No results for “" + search.text + "”"
                color: Theme.fgDim
            }
        }

        // ---------- footer: modifier legend + close hint ----------
        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            height: 46

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }

            Row {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Repeater {
                    model: ["Super", "Ctrl", "Alt", "Shift"]
                    Row {
                        required property string modelData
                        spacing: 6
                        Keycap {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.modGlyphs[parent.modelData]
                            size: 9
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData
                            font.pixelSize: 11
                            color: Theme.fgMuted
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Keycap {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "esc"
                    size: 9
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "to close"
                    font.pixelSize: 11
                    color: Theme.fgMuted
                }
            }
        }
    }
}
