pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// App / clipboard / run / calc launcher. Lives inside the bar's center pill,
// which grows around it; `open` resets and focuses it.
// Prefixes: ! web search (!g !yt !gh …), : emoji, / files, @ open windows,
// > run, = calc; "?" lists them.
Item {
    id: root

    property bool open: false
    implicitHeight: col.implicitHeight + 30

    readonly property bool clipMode: ShellState.launcherMode === "clip"
    property string query: ""

    function reset(): void {
        input.text = "";
        list.currentIndex = 0;
        input.forceActiveFocus();
        if (clipMode)
            clipProc.running = true;
    }
    onOpenChanged: if (open) reset()
    onClipModeChanged: if (open) reset()
    Component.onCompleted: if (open) reset()

    // ---------------- data ----------------
    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        printErrors: false
        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    function bump(id: string): void {
        const c = Object.assign({}, usage.counts);
        c[id] = (c[id] ?? 0) + 1;
        usage.counts = c;
        usageFile.writeAdapter();
    }

    property var clipItems: []
    readonly property string clipThumbDir: Quickshell.cachePath("clip-thumbs")
    property bool clipThumbsReady: false

    function parseClip(l: string): var {
        const tab = l.indexOf("\t");
        const id = l.slice(0, tab);
        const name = l.slice(tab + 1).replace(/\s+/g, " ").trim();
        const m = name.match(/^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$/i);
        if (!m)
            return { kind: "clip", line: l, name: name, search: name.toLowerCase() };
        const ext = m[2].toLowerCase();
        return {
            kind: "clip", line: l, image: true,
            file: id + "." + ext, w: +m[3], h: +m[4],
            name: "Image", sub: `${ext.toUpperCase()}  ·  ${m[3]} × ${m[4]}  ·  ${m[1]}`,
            search: "image " + ext
        };
    }

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipItems = text.split("\n").filter(l => l.length > 0).slice(0, 200).map(root.parseClip);
                root.clipThumbsReady = false;
                clipThumbProc.command = [Quickshell.shellPath("scripts/clip-thumbs.sh"), root.clipThumbDir,
                    ...root.clipItems.filter(c => c.image).map(c => c.file)];
                clipThumbProc.running = true;
            }
        }
    }
    Process {
        id: clipThumbProc
        onExited: root.clipThumbsReady = true
    }

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)

    // "?" — the prefix list; picking one fills it in
    readonly property var prefixes: [
        { kind: "hint", fill: "!", icon: "globe", name: "!  Search the web", sub: engines.map(e => "!" + e.bang).join("  ") },
        { kind: "hint", fill: ":", icon: "smile", name: ":  Emoji", sub: "Copy an emoji, e.g. :fire" },
        { kind: "hint", fill: "/", icon: "file-search", name: "/  Files", sub: "Find files in your home folder" },
        { kind: "hint", fill: "@", icon: "app-window", name: "@  Windows", sub: "Jump to an open window" },
        { kind: "hint", fill: ">", icon: "terminal", name: ">  Run", sub: "Run a shell command" },
        { kind: "hint", fill: "=", icon: "calculator", name: "=  Calculate", sub: "e.g. =2^10/3" }
    ]

    // ---- ! web search ----
    readonly property var engines: [
        { bang: "g", name: "Google", url: "https://www.google.com/search?q=" },
        { bang: "d", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
        { bang: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
        { bang: "gh", name: "GitHub", url: "https://github.com/search?q=" },
        { bang: "aw", name: "Arch Wiki", url: "https://wiki.archlinux.org/index.php?search=" },
        { bang: "aur", name: "AUR", url: "https://aur.archlinux.org/packages?K=" },
        { bang: "w", name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=" },
        { bang: "maps", name: "Maps", url: "https://www.google.com/maps/search/" }
    ]

    function web(s: string): var {
        const m = s.match(/^(\S+)\s+(.*)$/);
        const bang = m ? engines.find(e => e.bang === m[1].toLowerCase()) : null;
        const term = (bang ? m[2] : s).trim();
        const hints = engines.filter(e => !m && e.bang.startsWith(term.toLowerCase()))
            .map(e => ({ kind: "hint", fill: `!${e.bang} `, icon: "globe", name: `!${e.bang}  ${e.name}`, sub: "Search " + e.name }));
        if (!term)
            return hints;
        const items = [];
        if (!bang && /^(https?:\/\/)?[\w-]+(\.[\w-]+)+(:\d+)?(\/\S*)?$/.test(term))
            items.push({ kind: "web", name: term, sub: "Open website", url: /^https?:/.test(term) ? term : "https://" + term });
        for (const e of bang ? [bang] : engines)
            items.push({ kind: "web", name: term, sub: "Search " + e.name, url: e.url + encodeURIComponent(term) });
        // typing an exact bang (e.g. "!yt") suggests that engine first
        return hints.length === 1 && hints[0].fill.trim() === "!" + term.toLowerCase() ? hints.concat(items) : items;
    }

    // ---- : emoji ----
    property var emojiItems: []
    Process {
        running: true
        command: [Quickshell.shellPath("scripts/emoji-list.py")]
        stdout: StdioCollector {
            onStreamFinished: root.emojiItems = text.split("\n").filter(l => l.includes("\t")).map(l => {
                const [glyph, name] = l.split("\t");
                return { kind: "emoji", glyph: glyph, name: name.charAt(0).toUpperCase() + name.slice(1), sub: "Enter to copy", search: name };
            })
        }
    }

    function emoji(q: string): var {
        if (!q)
            return emojiItems.slice(0, 150);
        // drop the last letter of longer words so "smile" also finds "smiling"
        const words = q.split(/\s+/).map(w => w.length > 4 ? w.slice(0, -1) : w);
        // exact name, then whole-word match, then prefix, then anything; shorter first
        const rank = e => e.search === q ? 0 : new RegExp(`\\b${q.replace(/[^\w ]/g, "")}\\b`).test(e.search) ? 1
            : e.search.startsWith(q) ? 2 : 3;
        return emojiItems.filter(e => words.every(w => e.search.includes(w)))
            .map(e => [e, rank(e)])
            .sort((a, b) => a[1] - b[1] || a[0].search.length - b[0].search.length)
            .map(x => x[0])
            .slice(0, 150);
    }

    // ---- / files and folders under ~ (skips hidden and build/dependency dirs) ----
    property var fileItems: []
    readonly property string home: Quickshell.env("HOME")
    readonly property string fileQuery: !clipMode && query.trim().startsWith("/") ? query.trim().slice(1).trim() : ""
    onFileQueryChanged: fileTimer.restart()
    Timer {
        id: fileTimer
        interval: 120
        onTriggered: {
            if (root.fileQuery.length < 2) {
                root.fileItems = [];
                return;
            }
            // shortest paths first, so the closest matches lead
            fileProc.exec(["sh", "-c", 'cd "$HOME" && find . -mindepth 1 -maxdepth 7 \\( -name ".*" -o -name node_modules '
                + '-o -name target -o -name vendor -o -name __pycache__ -o -name venv -o -name Games \\) -prune '
                + '-o -iname "*$1*" -print 2>/dev/null | head -n 500 | cut -c3- '
                + '| awk \'{ print length($0) "\t" $0 }\' | sort -n | cut -f2- | head -n 60', "sh", root.fileQuery]);
        }
    }
    Process {
        id: fileProc
        stdout: StdioCollector {
            onStreamFinished: root.fileItems = text.split("\n").filter(l => l).map(rel => {
                const i = rel.lastIndexOf("/");
                return { kind: "file", name: rel.slice(i + 1), sub: "~/" + rel.slice(0, i + 1), path: root.home + "/" + rel };
            })
        }
    }

    // ---- @ windows ----
    readonly property bool windowMode: !clipMode && query.trim().startsWith("@")
    onWindowModeChanged: if (windowMode) Hyprland.refreshToplevels()

    function windows(q: string): var {
        return Hyprland.toplevels.values.map(t => {
            const o = t.lastIpcObject ?? {};
            const e = DesktopEntries.heuristicLookup(o.class ?? "");
            const app = e?.name ?? o.class ?? "";
            const ws = o.workspace?.name ?? "";
            return {
                kind: "window", address: o.address ?? "", icon: e?.icon ?? o.class ?? "",
                name: o.title || t.title || app, sub: app + (ws ? "  ·  workspace " + ws.replace(/^special:/, "") : ""),
                order: o.focusHistoryID ?? 999, search: ((o.title ?? "") + " " + (o.class ?? "") + " " + app).toLowerCase()
            };
        }).filter(w => w.address && q.split(/\s+/).every(x => w.search.includes(x)))
            .sort((a, b) => a.order - b.order);
    }

    function fuzzy(text: string, q: string): int {
        let from = 0, last = -2, s = 0;
        for (const ch of q) {
            const i = text.indexOf(ch, from);
            if (i < 0)
                return 0;
            s += i === last + 1 ? 3 : 1;
            last = i;
            from = i + 1;
        }
        return s;
    }

    function score(a: var, q: string): int {
        const n = (a.name ?? "").toLowerCase();
        if (n === q) return 1000;
        if (n.startsWith(q)) return 800 - n.length;
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 600 - n.length;
        if (n.includes(q)) return 400 - n.length;
        const extra = [a.genericName ?? "", a.id ?? "", [].concat(a.keywords ?? []).join(" "), a.comment ?? ""].join(" ").toLowerCase();
        if (extra.includes(q)) return 200;
        const f = fuzzy(n, q);
        return f > q.length ? 50 + f : 0;
    }

    function calc(expr: string): string {
        if (!/^[\d\s+\-*/().,%^]+$/.test(expr))
            return "";
        try {
            const v = Function(`"use strict"; return (${expr.replace(/\^/g, "**").replace(/,/g, ".")});`)();
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    readonly property var results: {
        const raw = query.trim();
        const q = raw.toLowerCase();
        if (clipMode)
            return q ? clipItems.filter(c => c.search.includes(q)) : clipItems;
        if (raw === "?")
            return prefixes;
        if (raw.startsWith("!"))
            return web(raw.slice(1));
        if (raw.startsWith(":"))
            return emoji(q.slice(1).trim());
        if (raw.startsWith("/"))
            return fileItems;
        if (raw.startsWith("@"))
            return windows(q.slice(1).trim());
        if (raw.startsWith(">")) {
            const cmd = raw.slice(1).trim();
            return cmd ? [{ kind: "run", name: cmd, sub: "Run command" }] : [];
        }
        if (raw.startsWith("=")) {
            const r = calc(raw.slice(1));
            return r ? [{ kind: "calc", name: r, sub: "Enter to copy" }] : [];
        }
        const counts = usage.counts;
        if (!q)
            return [...apps].sort((a, b) => ((counts[b.id] ?? 0) - (counts[a.id] ?? 0)) || a.name.localeCompare(b.name));
        return apps.map(a => [a, score(a, q) + Math.min(60, (counts[a.id] ?? 0) * 4)])
            .filter(x => x[1] > 0)
            .sort((x, y) => y[1] - x[1])
            .map(x => x[0]);
    }

    function iconFor(icon: string): string {
        if (!icon)
            return Quickshell.iconPath("application-x-executable");
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.iconPath(icon, "application-x-executable");
    }

    function activate(item: var): void {
        if (!item)
            return;
        const kind = item.kind ?? "app";
        if (kind === "hint") {
            input.text = item.fill;
            return;
        }
        if (kind === "app") {
            bump(item.id);
            if (item.runInTerminal)
                Quickshell.execDetached(["kitty", "-e", ...item.command]);
            else
                item.execute();
        } else if (kind === "run") {
            Quickshell.execDetached(["sh", "-c", item.name]);
        } else if (kind === "calc") {
            Quickshell.execDetached(["wl-copy", item.name]);
        } else if (kind === "web") {
            Quickshell.execDetached(["xdg-open", item.url]);
        } else if (kind === "emoji") {
            Quickshell.execDetached(["wl-copy", item.glyph]);
        } else if (kind === "file") {
            Quickshell.execDetached(["xdg-open", item.path]);
        } else if (kind === "window") {
            ShellState.dispatch(`hl.dsp.focus({ window = "address:${item.address}" })`, `focuswindow address:${item.address}`);
        } else if (kind === "clip") {
            Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", item.line]);
        }
        ShellState.launcherOpen = false;
    }

    // ---------------- ui ----------------
    Column {
        id: col
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 10

        Rectangle {
            width: parent.width
            height: 46
            radius: 23
            color: Theme.glassHi
            border.width: 1
            border.color: input.activeFocus ? Theme.borderHi : Theme.border

            MIcon {
                id: searchIcon
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                icon: root.clipMode ? "clipboard" : ({ ">": "terminal", "=": "calculator", "!": "globe", ":": "smile", "/": "file-search", "@": "app-window", "?": "circle-help" })[root.query.charAt(0)] ?? "search"
                size: 20
                color: Theme.fgDim
            }

            TextInput {
                id: input
                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: countText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.Medium
                color: Theme.fg
                selectionColor: Theme.fg
                selectedTextColor: Theme.bg
                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.fg
                    radius: 1
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: input.activeFocus
                        NumberAnimation { to: 0.15; duration: 530; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 530; easing.type: Easing.InOutSine }
                    }
                }
                onTextChanged: {
                    root.query = text;
                    list.currentIndex = 0;
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: root.clipMode ? "Search clipboard…" : "Search apps   ·   ? for shortcuts"
                    color: Theme.fgMuted
                    font.pixelSize: 15
                }

                Keys.onPressed: e => {
                    const ctrl = e.modifiers & Qt.ControlModifier;
                    if (e.key === Qt.Key_Escape) {
                        ShellState.launcherOpen = false;
                    } else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J)) {
                        list.incrementCurrentIndex();
                    } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K)) {
                        list.decrementCurrentIndex();
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.activate(root.results[list.currentIndex]);
                    } else {
                        return;
                    }
                    e.accepted = true;
                }
            }

            Txt {
                id: countText
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.results.length
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.fgMuted
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 400)
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 200
            highlightMoveVelocity: -1
            highlightResizeDuration: 0
            keyNavigationWraps: true
            model: ScriptModel {
                values: root.results
            }

            highlight: Rectangle {
                radius: 14
                color: Theme.glassHi
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 18
                    radius: 2
                    color: Theme.fg
                }
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dur; easing.type: Easing.OutCubic }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
                NumberAnimation { property: "opacity"; to: 1; duration: Theme.dur }
                NumberAnimation { property: "scale"; to: 1; duration: Theme.dur }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property string kind: modelData.kind ?? "app"
                readonly property bool current: ListView.isCurrentItem
                readonly property bool isImage: modelData.image ?? false

                width: list.width
                height: isImage ? 92 : 50

                Item {
                    id: iconBox
                    x: row.current ? 18 : 14
                    anchors.verticalCenter: parent.verticalCenter
                    // previews keep the image's aspect within 56–180 × 36–72
                    readonly property real aspect: row.isImage ? row.modelData.w / Math.max(1, row.modelData.h) : 1
                    width: row.isImage ? Math.max(56, Math.min(180, 72 * aspect)) : 32
                    height: row.isImage ? Math.max(36, Math.min(72, width / aspect)) : 32
                    Behavior on x { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }

                    IconImage {
                        anchors.fill: parent
                        visible: row.kind === "app" || row.kind === "window"
                        asynchronous: true
                        source: visible ? root.iconFor(row.modelData.icon) : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: row.kind === "emoji"
                        text: row.modelData.glyph ?? ""
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 24
                    }
                    ClippingRectangle {
                        anchors.fill: parent
                        visible: row.isImage
                        radius: Theme.radiusSm
                        color: Theme.glassHi
                        border.width: 1
                        border.color: Theme.border

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 360
                            source: row.isImage && root.clipThumbsReady ? "file://" + root.clipThumbDir + "/" + row.modelData.file : ""
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: row.kind !== "app" && row.kind !== "window" && row.kind !== "emoji" && !row.isImage
                        icon: row.modelData.icon ?? ({ run: "terminal", calc: "calculator", web: "globe", file: "file" })[row.kind] ?? "clipboard"
                        size: 22
                    }
                }

                Column {
                    anchors.left: iconBox.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Txt {
                        width: parent.width
                        text: row.modelData.name ?? ""
                        font.pixelSize: 14
                        font.weight: row.current ? Font.Bold : Font.DemiBold
                        color: row.current ? Theme.fg : Qt.rgba(1, 1, 1, 0.85)
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: row.kind === "app" ? (row.modelData.genericName || row.modelData.comment || "") : (row.modelData.sub ?? "")
                        font.pixelSize: 11
                        color: Theme.fgMuted
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: list.currentIndex = row.index
                    onClicked: root.activate(row.modelData)
                }
            }
        }

        Txt {
            visible: root.results.length === 0
            width: parent.width
            height: 60
            horizontalAlignment: Text.AlignHCenter
            text: root.clipMode ? "Clipboard is empty"
                : root.query.trim().startsWith("/") && root.fileQuery.length < 2 ? "Type at least 2 characters to search files"
                : "No results"
            color: Theme.fgMuted
        }
    }
}
