pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Polkit
import qs.services
import qs.components

// Polkit authentication agent: the macOS "wants to make changes" sheet, shown
// on the focused monitor over a blurred desktop (other monitors get the
// OverlayBackdrop). Replaces hyprpolkitagent — only one agent can register.
PanelWindow {
    id: win

    PolkitAgent {
        id: agent
    }

    readonly property AuthFlow flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null

    // Copied when a request starts so the sheet can fade out after the flow
    // object is gone.
    property string message: ""
    property string iconName: ""
    property string actionId: ""
    property string who: User.name
    property bool busy: false
    property string error: ""

    property ShellScreen target: Quickshell.screens[0]
    screen: target

    onOpenChanged: {
        ShellState.authOpen = open;
        if (!open)
            return;
        ShellState.closeAll();
        ShellState.overlayScreen = ShellState.focusedScreen;
        target = Quickshell.screens.find(s => s.name === ShellState.focusedScreen) ?? Quickshell.screens[0];
        message = flow.message;
        iconName = flow.iconName ?? "";
        actionId = flow.actionId ?? "";
        const id = flow.selectedIdentity?.displayName ?? "";
        who = id !== "" && id !== User.login ? id : User.name;
        busy = false;
        error = "";
        field.clear();
        Qt.callLater(() => field.focusInput());
    }

    Connections {
        target: win.flow
        function onAuthenticationFailed(): void {
            win.busy = false;
            win.error = "Incorrect password. Try again.";
            field.clear();
            field.error = true;
            field.shake();
            field.focusInput();
        }
        function onIsResponseRequiredChanged(): void {
            if (win.flow.isResponseRequired) {
                win.busy = false;
                field.focusInput();
            }
        }
    }

    function submit(): void {
        if (!flow || busy || field.text === "")
            return;
        busy = true;
        error = "";
        flow.submit(field.text);
    }

    function cancel(): void {
        flow?.cancelAuthenticationRequest();
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: reveal.shown
    WlrLayershell.namespace: "qs-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component SheetButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        signal clicked
        height: 32
        radius: 9
        color: primary ? Qt.rgba(1, 1, 1, btnMouse.containsMouse ? 1 : 0.92)
            : Qt.rgba(1, 1, 1, btnMouse.containsMouse ? 0.16 : 0.1)
        border.width: primary ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        scale: btnMouse.pressed ? 0.97 : 1
        opacity: enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

        Txt {
            anchors.centerIn: parent
            text: btn.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: btn.primary ? "#111111" : Theme.fg
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Reveal {
        id: reveal
        open: win.open
    }

    // tint + blur backdrop (qs-overlay-blur layer rule)
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: reveal.p
    }
    MouseArea {
        anchors.fill: parent
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

    // frosted glass sheet (see GlassPanel)
    GlassPanel {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40 + (1 - reveal.p) * 24
        width: 340
        height: content.implicitHeight + 48
        radius: 26
        opacity: reveal.p
        scale: 0.94 + 0.06 * reveal.p
        layer.enabled: reveal.p < 1
        layer.smooth: true

        Column {
            id: content
            x: 24
            y: 28
            width: parent.width - 48
            spacing: 0

            // app icon with lock badge
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
                        GradientStop { position: 1; color: "#222222" }
                    }
                    visible: !appIcon.visible

                    MIcon {
                        anchors.centerIn: parent
                        icon: "shield-check"
                        size: 30
                    }
                }

                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    source: win.iconName !== "" ? Quickshell.iconPath(win.iconName, true) : ""
                    visible: source.toString() !== "" && status === Image.Ready
                    asynchronous: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -6
                    anchors.bottomMargin: -6
                    width: 28
                    height: 28
                    radius: 14
                    color: "#f2f2f2"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.18)

                    MIcon {
                        anchors.centerIn: parent
                        icon: "lock-keyhole"
                        size: 14
                        color: "#111111"
                    }
                }
            }

            Item { width: 1; height: 18 }

            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Authentication Required"
                font.pixelSize: 15
                font.weight: Font.Bold
            }

            Item { width: 1; height: 6 }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: win.message
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
                lineHeight: 1.15
                color: Theme.fgDim
            }

            Item { width: 1; height: 20 }

            // who is authenticating
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: Theme.surfaceHi
                    Image {
                        anchors.fill: parent
                        source: User.avatar
                        sourceSize.width: 48
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.who
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Item { width: 1; height: 12 }

            PasswordField {
                id: field
                width: parent.width
                placeholder: (win.flow?.inputPrompt ?? "").replace(/:\s*$/, "").trim() || "Password"
                reveal: win.flow?.responseVisible ?? false
                busy: win.busy
                onSubmitted: win.submit()
                onCancelled: win.cancel()
            }

            // error / info line; keeps its height so the sheet doesn't jump
            Txt {
                width: parent.width
                height: 30
                horizontalAlignment: Text.AlignHCenter
                readonly property string info: win.flow?.supplementaryMessage ?? ""
                text: win.error || info
                color: win.error !== "" || (win.flow?.supplementaryIsError ?? false) ? Theme.danger : Theme.fgMuted
                font.pixelSize: 11
                opacity: text !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }

            Row {
                width: parent.width
                spacing: 10

                SheetButton {
                    width: (parent.width - 10) / 2
                    text: "Cancel"
                    onClicked: win.cancel()
                }
                SheetButton {
                    width: (parent.width - 10) / 2
                    text: win.busy ? "Checking…" : "Authenticate"
                    primary: true
                    enabled: field.text !== "" && !win.busy
                    onClicked: win.submit()
                }
            }

            Item { width: 1; height: 14 }

            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: win.actionId !== ""
                text: win.actionId
                font.family: Theme.mono
                font.pixelSize: 9
                color: Qt.rgba(1, 1, 1, 0.28)
            }
        }
    }
}
