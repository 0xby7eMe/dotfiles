pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// Themed replacement for the platform menu of system tray items. A layer
// surface (not an xdg popup) so Hyprland's qs-blur rule frosts it like the
// other panels. Submenus open in place with a back row instead of cascading.
PanelWindow {
    id: root

    property QsMenuHandle rootMenu
    property var stack: []      // opened submenu entries
    readonly property QsMenuHandle current: stack.length ? stack[stack.length - 1] : rootMenu

    property bool open: false
    property real centerX: 0    // x of the clicked tray icon's center on screen
    property Item target: null
    property real closedAt: 0

    function openFor(item: Item, menu: QsMenuHandle): void {
        // The click that dismissed the menu shouldn't reopen it right away.
        if (item === target && Date.now() - closedAt < 250)
            return;
        target = item;
        rootMenu = menu;
        stack = [];
        centerX = item.mapToItem(null, item.width / 2, 0).x;
        open = true;
        grabArm.restart();
    }

    function close(): void {
        if (!open)
            return;
        open = false;
        closedAt = Date.now();
    }

    // dbusmenu labels mark access keys with "_" ("__" is a literal underscore).
    function label(t: string): string {
        return t.replace(/__/g, "\x00").replace(/_/g, "").replace(/\x00/g, "_");
    }

    anchors.top: true
    anchors.right: true
    margins.top: Theme.barZone + Theme.barGap
    margins.right: Math.max(Theme.barGap, (screen?.width ?? 0) - centerX - implicitWidth / 2)
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: Math.min(340, Math.max(200, col.naturalWidth + 12))
    implicitHeight: col.implicitHeight + 12
    color: "transparent"
    visible: open || p > 0.002
    mask: Region { item: card }

    WlrLayershell.namespace: "qs-traymenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property real p: open ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: root.open ? Theme.dur : Theme.durFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }

    onCurrentChanged: if (open) swapAnim.restart()

    // Clicking anywhere outside closes the menu. Armed a beat after opening so
    // Hyprland doesn't drop the grab before the surface is mapped.
    HyprlandFocusGrab {
        active: root.open && root.visible && !grabArm.running
        windows: [root]
        onCleared: root.close()
    }
    Timer {
        id: grabArm
        interval: 80
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        y: -(1 - root.p) * 8
        opacity: root.p
        scale: 0.97 + 0.03 * root.p
        transformOrigin: Item.Top
        radius: Theme.radius
        color: Theme.glass
        border.width: 1
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: {
            if (root.stack.length)
                root.stack = root.stack.slice(0, -1);
            else
                root.close();
        }

        Column {
            id: col

            // Reserve a leading column when any entry has an icon or check mark,
            // so labels line up.
            readonly property bool leading: opener.children.values.some(e => e.icon !== "" || e.buttonType !== QsMenuButtonType.None)
            readonly property real naturalWidth: {
                let w = 0;
                for (const c of children)
                    if (c.visible && c.naturalWidth !== undefined)
                        w = Math.max(w, c.naturalWidth);
                return w;
            }

            x: 6
            y: 6
            width: parent.width - 12

            // back row for submenus
            MenuRow {
                visible: root.stack.length > 0
                text: visible ? root.label(root.stack[root.stack.length - 1].text) : ""
                leadIcon: "chevron-left"
                leading: col.leading
                dim: true
                onActivated: root.stack = root.stack.slice(0, -1)
            }
            Separator { visible: root.stack.length > 0 }

            Repeater {
                model: opener.children

                Loader {
                    id: entry
                    required property QsMenuEntry modelData
                    readonly property real naturalWidth: item?.naturalWidth ?? 0
                    width: col.width
                    sourceComponent: modelData?.isSeparator ? sepComp : rowComp

                    Component {
                        id: sepComp
                        Separator {}
                    }

                    Component {
                        id: rowComp
                        MenuRow {
                            readonly property QsMenuEntry e: entry.modelData
                            readonly property int btn: e?.buttonType ?? QsMenuButtonType.None
                            text: root.label(e?.text ?? "")
                            leading: col.leading
                            enabled: e?.enabled ?? false
                            image: btn === QsMenuButtonType.None ? (e?.icon ?? "") : ""
                            leadIcon: btn === QsMenuButtonType.CheckBox ? (e?.checkState === Qt.Checked ? "square-check" : "square")
                                : btn === QsMenuButtonType.RadioButton ? (e?.checkState === Qt.Checked ? "circle-dot" : "circle")
                                : ""
                            checked: e?.checkState === Qt.Checked
                            submenu: e?.hasChildren ?? false
                            onActivated: {
                                if (e.hasChildren) {
                                    root.stack = root.stack.concat([e]);
                                } else {
                                    e.triggered();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: swapAnim
        target: col
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.durFast
    }

    component Separator: Item {
        readonly property real naturalWidth: 0
        width: parent?.width ?? 0
        height: 9
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            width: parent.width - 20
            height: 1
            color: Theme.border
        }
    }

    component MenuRow: Rectangle {
        id: row

        property string text
        property string image       // icon url from the app
        property string leadIcon    // lucide glyph (check marks, back arrow)
        property bool checked
        property bool submenu
        property bool dim
        property bool leading       // align with sibling rows that have icons
        signal activated

        readonly property bool hasLead: leading || leadIcon !== ""
        readonly property real naturalWidth: 12 + (hasLead ? 26 : 0) + lbl.implicitWidth + (submenu ? 28 : 12)

        width: parent?.width ?? 0
        height: 32
        radius: Theme.radiusSm
        color: mouse.containsMouse && enabled ? Theme.glassHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Item {
            id: lead
            visible: row.hasLead
            x: 10
            width: 18
            height: parent.height

            MIcon {
                anchors.centerIn: parent
                visible: row.leadIcon !== ""
                icon: row.leadIcon
                size: 15
                color: !row.enabled ? Theme.fgMuted : row.checked || mouse.containsMouse ? Theme.fg : Theme.fgDim
            }

            IconImage {
                anchors.centerIn: parent
                visible: row.image !== "" && row.leadIcon === ""
                implicitSize: 15
                source: row.image
                opacity: row.enabled ? 1 : 0.4
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: mouse.containsMouse ? 0 : -1
                }
            }
        }

        Txt {
            id: lbl
            anchors.verticalCenter: parent.verticalCenter
            x: row.hasLead ? 38 : 12
            width: parent.width - x - (row.submenu ? 28 : 12)
            text: row.text
            color: !row.enabled ? Theme.fgMuted : row.dim && !mouse.containsMouse ? Theme.fgDim : Theme.fg
        }

        MIcon {
            visible: row.submenu
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            icon: "chevron-right"
            size: 15
            color: mouse.containsMouse ? Theme.fg : Theme.fgDim
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
