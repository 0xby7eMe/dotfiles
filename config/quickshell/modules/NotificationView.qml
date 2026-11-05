pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services
import qs.components

// Notification popups shown inside the bar's center pill, below the clock.
// Click runs the default action, right click dismisses; hover pauses expiry.
// Expired toasts stay in the notification center (DashView).
Item {
    id: root

    // expiry timers only run while the popups are actually on screen
    property bool open: false
    implicitHeight: list.contentHeight + 8

    ListView {
        id: list
        x: 6
        width: parent.width - 12
        height: contentHeight
        spacing: 2
        interactive: false
        model: ScriptModel {
            values: Notifs.popups
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast }
            NumberAnimation { property: "scale"; to: 0.94; duration: Theme.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedAccel }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
        }

        delegate: Rectangle {
            id: toast
            required property Notification modelData
            readonly property bool critical: modelData?.urgency === NotificationUrgency.Critical
            readonly property var defaultAction: (modelData?.actions ?? []).find(a => a.identifier === "default") ?? null
            readonly property var buttons: (modelData?.actions ?? []).filter(a => a.identifier !== "default")
            readonly property bool hovered: hover.containsMouse || close.hovered

            width: list.width
            height: body.implicitHeight + 24
            radius: 20
            color: hovered ? Theme.glassHi : "transparent"
            border.width: critical ? 1 : 0
            border.color: Theme.danger
            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Timer {
                running: root.open && !toast.critical && !toast.hovered
                interval: (toast.modelData?.expireTimeout ?? 0) > 0 ? toast.modelData.expireTimeout : 5500
                // leaves the toast, stays in the notification center
                onTriggered: Notifs.hidePopup(toast.modelData)
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: toast.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: e => {
                    if (e.button === Qt.LeftButton && toast.defaultAction)
                        toast.defaultAction.invoke();
                    else
                        toast.modelData.dismiss();
                }
            }

            Row {
                id: body
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 12

                ClippingRectangle {
                    id: img
                    // screenshots get a wider preview, like the macOS thumbnail
                    readonly property bool shot: isImage && toast.modelData?.appName === "Screenshot"
                    width: shot ? 72 : 40
                    height: shot ? 48 : 40
                    radius: shot ? 9 : 12
                    color: Theme.surfaceHi
                    border.width: shot ? 1 : 0
                    border.color: Theme.borderHi
                    readonly property string src: toast.modelData?.image
                        || (toast.modelData?.appIcon ? (toast.modelData.appIcon.startsWith("/") ? "file://" + toast.modelData.appIcon : Quickshell.iconPath(toast.modelData.appIcon, true)) : "")
                    readonly property bool isImage: src !== "" && src === toast.modelData?.image

                    // pictures fill and crop; icons keep their padding
                    Image {
                        anchors.fill: parent
                        visible: img.isImage
                        source: img.isImage ? img.src : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 160
                        asynchronous: true
                    }
                    IconImage {
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: img.src !== "" && !img.isImage
                        source: img.isImage ? "" : img.src
                        asynchronous: true
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: img.src === ""
                        icon: "bell"
                        size: 20
                    }
                }

                Column {
                    width: parent.width - img.width - 12
                    spacing: 3

                    Row {
                        width: parent.width
                        spacing: 6
                        Txt {
                            width: Math.min(implicitWidth, parent.width - appName.width - 30)
                            text: toast.modelData?.summary ?? ""
                            font.weight: Font.Bold
                        }
                        Txt {
                            id: appName
                            text: toast.modelData?.appName ?? ""
                            font.pixelSize: 11
                            color: Theme.fgMuted
                        }
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.modelData?.body ?? ""
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.fgDim
                        linkColor: Theme.fg
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    Row {
                        visible: toast.buttons.length > 0
                        topPadding: 6
                        spacing: 6
                        Repeater {
                            model: toast.buttons
                            Pill {
                                required property NotificationAction modelData
                                text: modelData?.text ?? ""
                                onClicked: modelData?.invoke()
                            }
                        }
                    }
                }
            }

            IconButton {
                id: close
                readonly property bool hovered: closeHover.hovered
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                implicitWidth: 24
                implicitHeight: 24
                icon: "x"
                iconSize: 14
                opacity: toast.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                onClicked: toast.modelData.dismiss()
                HoverHandler { id: closeHover }
            }
        }
    }
}
