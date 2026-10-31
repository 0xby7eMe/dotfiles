pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// macOS ⌘Tab-style app switcher on Alt+Tab: hold Alt, Tab / Shift+Tab (or
// ←/→, hover) to pick, release Alt (or click) to switch, Esc to cancel. Apps are in
// most-recently-used order with their windows grouped; switching focuses the
// app's most recent window. A quick tap switches straight to the previous app
// without showing the panel.
//
// Driven by Hyprland global shortcuts (quickshell:switcherNext / Prev /
// Commit / Cancel, see hypr/modules/keybindings.lua, which also detects the
// Alt release). The panel never takes keyboard focus: holding it while the
// target window is focused made Hyprland hand focus back on close.
PanelWindow {
    id: win

    property bool active: false     // a switch is in progress
    property bool shown: false      // panel visible (after the hold delay)
    property int index: 0
    property var apps: []           // [{ cls, name, icon, windows: [HyprlandToplevel] }]

    property ShellScreen target: Quickshell.screens[0]
    screen: target

    // ---------- most-recently-used order ----------
    // Hyprland only reports focus history on request, so track it live.
    property var mru: []            // toplevel addresses, most recent first
    Connections {
        target: Hyprland
        function onActiveToplevelChanged(): void {
            const t = Hyprland.activeToplevel;
            if (!t)
                return;
            win.mru = [t.address].concat(win.mru.filter(a => a !== t.address)).slice(0, 200);
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()

    function rank(t: var): int {
        const i = mru.indexOf(t.address);
        // unseen windows: after the tracked ones, by Hyprland's focus history
        return i >= 0 ? i : 1000 + (t.lastIpcObject?.focusHistoryID ?? 500);
    }

    function clsOf(t: var): string {
        return t.wayland?.appId || t.lastIpcObject?.class || "";
    }

    function iconFor(cls: string): string {
        const icon = DesktopEntries.heuristicLookup(cls)?.icon ?? cls;
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.iconPath(icon, "application-x-executable");
    }

    function build(): void {
        const groups = [];
        const byCls = {};
        const wins = Hyprland.toplevels.values.filter(t => clsOf(t) !== "").sort((a, b) => rank(a) - rank(b));
        for (const t of wins) {
            const cls = clsOf(t);
            if (!byCls[cls]) {
                const entry = DesktopEntries.heuristicLookup(cls);
                byCls[cls] = { cls: cls, name: entry?.name ?? cls, icon: iconFor(cls), windows: [] };
                groups.push(byCls[cls]);
            }
            byCls[cls].windows.push(t);
        }
        apps = groups;
    }

    // ---------- actions ----------
    function step(d: int): void {
        if (!active) {
            build();
            if (apps.length === 0)
                return;
            target = Quickshell.screens.find(s => s.name === ShellState.focusedScreen) ?? Quickshell.screens[0];
            ShellState.closeAll();
            // the current app is first; start on the one before it
            index = apps.length > 1 ? (d > 0 ? 1 : apps.length - 1) : 0;
            active = true;
            showTimer.restart();
            return;
        }
        if (apps.length > 0)
            index = (index + d + apps.length) % apps.length;
        shown = true;
    }

    function commit(): void {
        if (!active)
            return;
        const app = apps[index];
        close();
        const t = app?.windows?.[0];
        if (!t)
            return;
        const a = t.lastIpcObject?.address ?? ("0x" + t.address);
        ShellState.dispatch(`hl.dsp.focus({ window = "address:${a}" })`, `focuswindow address:${a}`);
    }

    function close(): void {
        showTimer.stop();
        active = false;
        shown = false;
    }

    // macOS waits a beat before showing the panel, so a quick tap doesn't flash it
    Timer {
        id: showTimer
        interval: 110
        onTriggered: win.shown = true
    }

    GlobalShortcut {
        name: "switcherNext"
        description: "App switcher: next app"
        onPressed: win.step(1)
    }
    GlobalShortcut {
        name: "switcherPrev"
        description: "App switcher: previous app"
        onPressed: win.step(-1)
    }
    GlobalShortcut {
        name: "switcherCommit"
        description: "App switcher: switch to the selected app"
        onPressed: win.commit()
    }
    GlobalShortcut {
        name: "switcherCancel"
        description: "App switcher: cancel"
        onPressed: win.close()
    }

    // ---------- window ----------
    readonly property int cell: Math.min(112, Math.floor((target.width - 160) / Math.max(1, apps.length)))
    readonly property int iconSize: Math.round(cell * 0.72)
    readonly property int pad: 14

    implicitWidth: panel.width + 80
    implicitHeight: panel.height + 80
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: reveal.shown
    WlrLayershell.namespace: "qs-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Reveal {
        id: reveal
        open: win.shown
        openDuration: Theme.dur
        closeDuration: Theme.durFast
    }

    RectangularShadow {
        anchors.fill: panel
        radius: panel.radius
        blur: 40
        offset.y: 12
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: panel.opacity
        scale: panel.scale
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: row.width + 2 * win.pad
        height: row.height + 2 * win.pad
        radius: 28
        color: Theme.glass
        border.width: 1
        border.color: Theme.borderHi
        opacity: reveal.p
        scale: 0.9 + 0.1 * reveal.p

        Row {
            id: row
            anchors.centerIn: parent

            Repeater {
                model: win.apps

                Item {
                    id: app
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === win.index
                    width: win.cell
                    height: win.cell + 26

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: win.cell
                        height: win.cell
                        radius: 20
                        color: Qt.rgba(1, 1, 1, app.selected ? 0.16 : appMouse.containsMouse ? 0.07 : 0)
                        border.width: app.selected ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (win.cell - win.iconSize) / 2
                        implicitSize: win.iconSize
                        source: app.modelData.icon
                        asynchronous: true
                        mipmap: true
                        scale: app.selected ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                    }

                    // one dot per window, like the dock's running indicators
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.cell - 9
                        spacing: 3
                        visible: app.modelData.windows.length > 1
                        Repeater {
                            model: Math.min(4, app.modelData.windows.length)
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.55)
                            }
                        }
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.cell + 6
                        width: Math.min(implicitWidth, win.cell + 40)
                        horizontalAlignment: Text.AlignHCenter
                        text: app.modelData.name
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        opacity: app.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    }

                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.index = app.index
                        onClicked: {
                            win.index = app.index;
                            win.commit();
                        }
                    }
                }
            }
        }
    }
}
