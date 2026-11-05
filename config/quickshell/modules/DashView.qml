pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services
import qs.components

// macOS-style notification center, grown out of the bar's clock: a month
// calendar and a weather widget on the left, the notification history on
// the right. Esc or a click outside closes it.
Item {
    id: root

    property bool open: false
    implicitHeight: left.height + 20

    readonly property int pad: 14

    function focusIn(): void {
        if (!open)
            return;
        forceActiveFocus();
        cal.month = cal.thisMonth();
    }
    onOpenChanged: focusIn()
    Component.onCompleted: focusIn()
    Keys.onEscapePressed: ShellState.closeAll()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function ago(id: int): string {
        const t = Notifs.times[id];
        if (!t)
            return "";
        const m = Math.floor((clock.date.getTime() - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + "m ago" : m < 24 * 60 ? Math.floor(m / 60) + "h ago"
            : Qt.formatDateTime(new Date(t), "ddd HH:mm");
    }

    // ---------------- left: calendar + weather ----------------
    Column {
        id: left
        x: root.pad
        y: 6
        width: 288
        spacing: 10

        Rectangle {
            id: cal
            width: parent.width
            height: grid.y + grid.height + 10
            radius: 20
            color: Theme.glassHi
            border.width: 1
            border.color: Theme.border

            property date month: thisMonth()
            readonly property int firstDow: 1   // weeks start on Monday
            readonly property bool current: month.getFullYear() === clock.date.getFullYear() && month.getMonth() === clock.date.getMonth()

            function thisMonth(): date {
                return new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
            }
            function step(n: int): void {
                month = new Date(month.getFullYear(), month.getMonth() + n, 1);
            }

            readonly property var cells: {
                const y = month.getFullYear(), m = month.getMonth();
                const off = (new Date(y, m, 1).getDay() - firstDow + 7) % 7;
                const now = clock.date;
                const out = [];
                for (let i = 0; i < 42; i++) {
                    const d = new Date(y, m, 1 - off + i);
                    out.push({
                        day: d.getDate(),
                        inMonth: d.getMonth() === m,
                        today: d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate(),
                        weekend: d.getDay() === 0 || d.getDay() === 6
                    });
                }
                return out;
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => cal.step(e.angleDelta.y > 0 ? -1 : 1)
            }

            // header: month, year, navigation
            Row {
                x: 16
                y: 12
                height: 28
                spacing: 6
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.locale().standaloneMonthName(cal.month.getMonth())
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cal.month.getFullYear()
                    font.pixelSize: 15
                    color: Theme.fgDim
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 12
                height: 28
                spacing: 0
                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !cal.current
                    implicitHeight: 24
                    text: "Today"
                    onClicked: cal.month = cal.thisMonth()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    iconSize: 15
                    icon: "chevron-left"
                    onClicked: cal.step(-1)
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    iconSize: 15
                    icon: "chevron-right"
                    onClicked: cal.step(1)
                }
            }

            // weekday initials
            Row {
                id: dows
                x: 10
                y: 46
                Repeater {
                    model: 7
                    Txt {
                        required property int index
                        readonly property int dow: (cal.firstDow + index) % 7
                        width: (cal.width - 20) / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(dow, Locale.NarrowFormat)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: dow === 0 || dow === 6 ? Theme.fgMuted : Theme.fgDim
                    }
                }
            }

            Grid {
                id: grid
                x: 10
                y: 66
                columns: 7
                Repeater {
                    model: cal.cells
                    Item {
                        id: cell
                        required property var modelData
                        width: (cal.width - 20) / 7
                        height: 30
                        Rectangle {
                            anchors.centerIn: parent
                            width: 27
                            height: 27
                            radius: 13.5
                            visible: cell.modelData.today
                            color: Theme.accent
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: cell.modelData.day
                            font.pixelSize: 12
                            font.weight: cell.modelData.today ? Font.Bold : Font.DemiBold
                            color: cell.modelData.today ? Theme.accentFg
                                : !cell.modelData.inMonth ? Qt.rgba(1, 1, 1, 0.22)
                                : cell.modelData.weekend ? Theme.fgDim : Theme.fg
                        }
                    }
                }
            }
        }

        // ---- weather widget (iOS medium-widget style) ----
        ClippingRectangle {
            id: wx
            width: parent.width
            height: 138
            radius: 20
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            scale: wxMouse.pressed ? 0.98 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

            Rectangle {
                anchors.fill: parent
                opacity: 0.8
                gradient: Gradient {
                    GradientStop { position: 0; color: Weather.palette[0] }
                    GradientStop { position: 1; color: Weather.palette[1] }
                }
            }
            // sun / moon glow on clear skies
            Rectangle {
                visible: Weather.skyFamily === "clear" || Weather.skyFamily === "partly"
                x: parent.width - 90
                y: -50
                width: 150
                height: 150
                radius: 75
                color: Weather.palette[2]
                opacity: Weather.isDay ? 0.45 : 0.2
                layer.enabled: visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                }
            }

            Column {
                x: 14
                y: 12
                spacing: -2
                Row {
                    spacing: 5
                    Txt {
                        text: Weather.place || "Weather"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Weather.autoLocation
                        icon: "navigation"
                        size: 10
                    }
                }
                Txt {
                    text: Weather.tempText
                    font.pixelSize: 36
                    font.weight: Font.Light
                }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 14
                spacing: 2
                MIcon {
                    anchors.right: parent.right
                    icon: Weather.icon
                    size: 20
                    color: Weather.current ? Weather.iconColor(Weather.current.code, Weather.isDay) : Theme.fg
                }
                Txt {
                    anchors.right: parent.right
                    text: Weather.condition || "Unavailable"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Txt {
                    anchors.right: parent.right
                    visible: Weather.daily.length > 0
                    text: Weather.daily.length > 0 ? `H:${Weather.deg(Weather.daily[0].hi)} L:${Weather.deg(Weather.daily[0].lo)}` : ""
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.75)
                }
            }

            // next hours
            Row {
                x: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                Repeater {
                    model: Weather.hours.slice(0, 6)
                    Column {
                        id: hr
                        required property var modelData
                        width: (wx.width - 16) / 6
                        spacing: 2
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hr.modelData.label
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Qt.rgba(1, 1, 1, 0.75)
                        }
                        MIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: Weather.iconFor(hr.modelData.code, hr.modelData.day)
                            size: 14
                            color: Weather.iconColor(hr.modelData.code, hr.modelData.day)
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.deg(hr.modelData.temp)
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            MouseArea {
                id: wxMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleWeather()
            }
        }
    }

    // ---------------- right: notifications ----------------
    Item {
        id: right
        x: left.x + left.width + 14
        y: 6
        width: root.width - x - root.pad
        height: left.height

        Item {
            id: head
            width: parent.width
            height: 30
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                spacing: 8
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.history.length > 0
                    width: Math.max(20, countTxt.implicitWidth + 12)
                    height: 18
                    radius: 9
                    color: Theme.glassHover
                    Txt {
                        id: countTxt
                        anchors.centerIn: parent
                        text: Notifs.history.length
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    iconSize: 14
                    icon: ShellState.dnd ? "bell-off" : "bell"
                    active: ShellState.dnd
                    onClicked: ShellState.dnd = !ShellState.dnd
                }
                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.history.length > 0
                    implicitHeight: 26
                    text: "Clear"
                    icon: "trash-2"
                    onClicked: Notifs.clearAll()
                }
            }
        }

        ListView {
            id: list
            y: head.height + 8
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: Notifs.history
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast }
                NumberAnimation { property: "x"; to: 40; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedAccel }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
            }

            delegate: Rectangle {
                id: card
                required property Notification modelData
                readonly property bool critical: modelData?.urgency === NotificationUrgency.Critical
                readonly property var defaultAction: (modelData?.actions ?? []).find(a => a.identifier === "default") ?? null
                readonly property var buttons: (modelData?.actions ?? []).filter(a => a.identifier !== "default")
                readonly property bool hovered: hover.containsMouse || closeHover.hovered

                width: list.width
                height: body.implicitHeight + 22
                radius: 16
                color: hovered ? Theme.glassHover : Theme.glassHi
                border.width: 1
                border.color: critical ? Theme.danger : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: e => {
                        if (e.button === Qt.LeftButton && card.defaultAction) {
                            card.defaultAction.invoke();
                            ShellState.closeAll();
                        } else if (e.button === Qt.RightButton) {
                            card.modelData.dismiss();
                        }
                    }
                }

                Row {
                    id: body
                    x: 11
                    y: 11
                    width: parent.width - 22
                    spacing: 10

                    ClippingRectangle {
                        id: img
                        width: 34
                        height: 34
                        radius: 9
                        color: Theme.surfaceHi
                        readonly property string src: card.modelData?.image
                            || (card.modelData?.appIcon ? (card.modelData.appIcon.startsWith("/") ? "file://" + card.modelData.appIcon : Quickshell.iconPath(card.modelData.appIcon, true)) : "")
                        readonly property bool isImage: src !== "" && src === card.modelData?.image

                        Image {
                            anchors.fill: parent
                            visible: img.isImage
                            source: img.isImage ? img.src : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 96
                            asynchronous: true
                        }
                        IconImage {
                            anchors.fill: parent
                            anchors.margins: 5
                            visible: img.src !== "" && !img.isImage
                            source: img.isImage ? "" : img.src
                            asynchronous: true
                        }
                        MIcon {
                            anchors.centerIn: parent
                            visible: img.src === ""
                            icon: "bell"
                            size: 16
                        }
                    }

                    Column {
                        width: parent.width - img.width - 10
                        spacing: 2

                        Item {
                            width: parent.width
                            height: 14
                            Txt {
                                width: parent.width - when.width - 8
                                text: (card.modelData?.appName ?? "").toUpperCase()
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Theme.fgMuted
                            }
                            Txt {
                                id: when
                                anchors.right: parent.right
                                anchors.rightMargin: card.hovered ? 22 : 0
                                text: root.ago(card.modelData?.id ?? -1)
                                font.pixelSize: 10
                                color: Theme.fgMuted
                                Behavior on anchors.rightMargin { NumberAnimation { duration: Theme.durFast } }
                            }
                        }
                        Txt {
                            width: parent.width
                            text: card.modelData?.summary ?? ""
                            font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.modelData?.body ?? ""
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.fgDim
                            linkColor: Theme.fg
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                        Row {
                            visible: card.buttons.length > 0
                            topPadding: 6
                            spacing: 6
                            Repeater {
                                model: card.buttons
                                Pill {
                                    required property NotificationAction modelData
                                    implicitHeight: 26
                                    text: modelData?.text ?? ""
                                    onClicked: modelData?.invoke()
                                }
                            }
                        }
                    }
                }

                IconButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    implicitWidth: 22
                    implicitHeight: 22
                    icon: "x"
                    iconSize: 12
                    opacity: card.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    onClicked: card.modelData.dismiss()
                    HoverHandler { id: closeHover }
                }
            }
        }

        // empty state
        Column {
            anchors.centerIn: list
            visible: Notifs.history.length === 0
            spacing: 8
            MIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: ShellState.dnd ? "bell-off" : "bell"
                size: 30
                color: Theme.fgMuted
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No Notifications"
                font.weight: Font.DemiBold
                color: Theme.fgDim
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ShellState.dnd
                text: "Do Not Disturb is on"
                font.pixelSize: 11
                color: Theme.fgMuted
            }
        }
    }
}
