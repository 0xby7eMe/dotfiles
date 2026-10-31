pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Pill-style workspace indicator: active workspace stretches into a bar.
Item {
    id: root

    required property HyprlandMonitor monitor
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var wsList: Hyprland.workspaces.values
    readonly property int count: {
        let m = 5;
        for (const w of wsList)
            if (w.id > m && w.id <= 20)
                m = w.id;
        return Math.max(m, activeId);
    }

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 24

    MouseArea {
        anchors.fill: parent
        onWheel: e => ShellState.focusWorkspace(e.angleDelta.y > 0 ? "r-1" : "r+1")
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.count

            Rectangle {
                id: pill
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: root.wsList.find(w => w.id === wsId) ?? null
                readonly property bool active: wsId === root.activeId
                readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0

                anchors.verticalCenter: parent.verticalCenter
                width: active ? 28 : 8
                height: 8
                radius: 4
                color: active ? Theme.fg
                    : hover.containsMouse ? Theme.fgDim
                    : occupied ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.18)

                Behavior on width {
                    NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }
                Behavior on color { ColorAnimation { duration: Theme.dur } }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.focusWorkspace(String(pill.wsId))
                }
            }
        }
    }
}
