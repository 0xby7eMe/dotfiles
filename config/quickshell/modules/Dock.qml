pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// Bottom taskbar: GNOME favorites (kept in sync via gsettings) + running apps.
PanelWindow {
    id: dock

    required property ShellScreen modelData
    screen: modelData

    readonly property int dockHeight: 45
    readonly property int gap: 8
    readonly property int iconSize: 30

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 130
    exclusiveZone: dockHeight + gap
    color: "transparent"
    WlrLayershell.namespace: "qs-dock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: pill }

    // ---------- model ----------
    // byId()/heuristicLookup() aren't reactive and entries are scanned async, so
    // touch `applications.values` to re-run bindings once the scan (re)completes.
    function entry(id: string): DesktopEntry {
        void DesktopEntries.applications.values;
        return DesktopEntries.byId(id);
    }

    function appIdFor(t: var): string {
        void DesktopEntries.applications.values;
        const e = DesktopEntries.heuristicLookup(t.appId);
        return e ? e.id : t.appId;
    }

    readonly property var windowsById: {
        const m = {};
        for (const t of ToplevelManager.toplevels.values) {
            const id = appIdFor(t);
            (m[id] = m[id] ?? []).push(t);
        }
        return m;
    }

    readonly property var ids: {
        const pinned = ShellState.pinned.filter(id => dock.entry(id) !== null);
        const extra = Object.keys(windowsById).filter(id => !pinned.includes(id));
        return pinned.concat(extra);
    }

    function iconFor(id: string): string {
        const icon = dock.entry(id)?.icon ?? id;
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.iconPath(icon, "application-x-executable");
    }

    function launch(id: string): void {
        const e = dock.entry(id);
        if (e)
            e.execute();
    }

    function clickApp(id: string): void {
        const wins = windowsById[id] ?? [];
        if (wins.length === 0) {
            launch(id);
            return;
        }
        const i = wins.findIndex(t => t.activated);
        wins[i < 0 ? 0 : (i + 1) % wins.length].activate();
    }

    // ---------- ui ----------
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.gap
        height: dock.dockHeight
        width: apps.width + sep.width + gridBtn.width + 24
        radius: 20
        color: Theme.glass
        border.width: 1
        border.color: Theme.border

        Behavior on width {
            NumberAnimation { duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized }
        }

        ListView {
            id: apps
            x: 10
            height: parent.height
            width: contentWidth
            orientation: ListView.Horizontal
            interactive: false
            spacing: 2
            model: ScriptModel {
                values: dock.ids
            }

            add: Transition {
                NumberAnimation { property: "scale"; from: 0; to: 1; duration: Theme.durSlow; easing.type: Easing.OutBack }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
            }
            remove: Transition {
                NumberAnimation { property: "scale"; to: 0; duration: Theme.dur; easing.type: Easing.InBack }
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur }
            }
            displaced: Transition {
                NumberAnimation { property: "x"; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized }
                NumberAnimation { properties: "scale,opacity"; to: 1; duration: Theme.dur }
            }

            delegate: Item {
                id: item
                required property string modelData
                readonly property var wins: dock.windowsById[modelData] ?? []
                readonly property bool running: wins.length > 0
                readonly property bool focused: wins.some(t => t.activated)
                readonly property string name: dock.entry(modelData)?.name ?? modelData

                width: dock.iconSize + 4
                height: dock.dockHeight

                IconImage {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (dock.dockHeight - dock.iconSize) / 2 - 2 - (mouse.containsMouse ? 4 : 0)
                    implicitSize: dock.iconSize
                    source: dock.iconFor(item.modelData)
                    asynchronous: true
                    scale: mouse.pressed ? 1.05 : mouse.containsMouse ? 1.2 : 1
                    transformOrigin: Item.Bottom
                    mipmap: true

                    Behavior on y { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                }

                // running / focused indicator
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    height: 2
                    radius: 2
                    width: item.focused ? 16 : item.running ? 5 : 0
                    opacity: item.running ? 1 : 0
                    color: item.focused ? Theme.fg : Theme.fgDim
                    Behavior on width { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    Behavior on color { ColorAnimation { duration: Theme.dur } }
                }

                // tooltip
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: mouse.containsMouse && !menu.visible ? -42 : -34
                    opacity: mouse.containsMouse && !menu.visible ? 1 : 0
                    width: tip.implicitWidth + 20
                    height: 26
                    radius: 13
                    color: Theme.glass
                    border.width: 1
                    border.color: Theme.borderHi
                    Behavior on y { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    Txt {
                        id: tip
                        anchors.centerIn: parent
                        text: item.name
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: e => {
                        if (e.button === Qt.LeftButton)
                            dock.clickApp(item.modelData);
                        else if (e.button === Qt.MiddleButton)
                            dock.launch(item.modelData);
                        else
                            menu.openFor(item, item.modelData);
                    }
                }
            }
        }

        Rectangle {
            id: sep
            anchors.left: apps.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 28
            color: Theme.borderHi
        }

        IconButton {
            id: gridBtn
            anchors.left: sep.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 30
            implicitHeight: 30
            radius: 14
            icon: "gamepad-directional"
            iconSize: 20
            active: ShellState.launcherOpen
            onClicked: ShellState.toggleLauncher("apps")
        }
    }

    // ---------- context menu ----------
    PopupWindow {
        id: menu

        property string appId: ""
        readonly property bool pinned: ShellState.pinned.includes(appId)
        readonly property var wins: dock.windowsById[appId] ?? []

        function openFor(target: Item, id: string): void {
            appId = id;
            anchor.item = target;
            visible = true;
        }

        anchor.window: dock
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -6
        implicitWidth: 200
        implicitHeight: menuCol.implicitHeight + 12
        color: "transparent"
        visible: false

        HyprlandFocusGrab {
            active: menu.visible
            windows: [menu]
            onCleared: menu.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Theme.bg
            border.width: 1
            border.color: Theme.borderHi

            Column {
                id: menuCol
                x: 6
                y: 6
                width: parent.width - 12

                Repeater {
                    model: [
                        { t: "New window", i: "plus", a: "new", show: true },
                        { t: menu.pinned ? "Unpin" : "Pin to dock", i: "pin", a: "pin", show: true },
                        { t: menu.wins.length > 1 ? "Close all" : "Close", i: "x", a: "close", show: menu.wins.length > 0 }
                    ]

                    Rectangle {
                        id: mi
                        required property var modelData
                        visible: modelData.show
                        width: menuCol.width
                        height: 36
                        radius: 10
                        color: miMouse.containsMouse ? Theme.surfaceHi : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 10
                            MIcon { icon: mi.modelData.i; size: 18 }
                            Txt { text: mi.modelData.t }
                        }

                        MouseArea {
                            id: miMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const a = mi.modelData.a;
                                if (a === "new")
                                    dock.launch(menu.appId);
                                else if (a === "pin")
                                    ShellState.togglePin(menu.appId);
                                else
                                    for (const t of menu.wins) t.close();
                                menu.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
