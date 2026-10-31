pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.services
import qs.components

// Wi-Fi network picker that unfolds in the control center under the Wi-Fi tile.
Item {
    id: root

    property bool shown: false
    property var pskTarget: null    // secured network waiting for a password
    property string failName: ""
    property string failMsg: ""

    readonly property var dev: Sys.wifiDev
    // Signal is bucketed so the list doesn't reshuffle on every scan.
    readonly property var networks: (dev?.networks?.values ?? [])
        .filter(n => n.name !== "")
        .sort((a, b) => (b.connected - a.connected)
            || (Math.round(b.signalStrength * 4) - Math.round(a.signalStrength * 4))
            || a.name.localeCompare(b.name))

    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
    }
    implicitHeight: Math.round(card.height * reveal)
    visible: reveal > 0.01
    clip: true

    onShownChanged: {
        pskTarget = null;
        failName = "";
    }

    // Scan only while the list is on screen.
    Binding {
        when: root.shown && root.dev !== null
        target: root.dev
        property: "scannerEnabled"
        value: true
        restoreMode: Binding.RestoreBindingOrValue
    }

    function isSecured(n: var): bool {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function isEnterprise(n: var): bool {
        return [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192,
            WifiSecurityType.Leap, WifiSecurityType.DynamicWep].includes(n.security);
    }

    function activate(n: var): void {
        failName = "";
        if (n.connected) {
            n.disconnect();
            return;
        }
        if (n.known || !isSecured(n)) {
            pskTarget = null;
            n.connect();
            return;
        }
        if (isEnterprise(n)) {
            ShellState.closeAll();
            Quickshell.execDetached(["nm-connection-editor"]);
            return;
        }
        pskTarget = pskTarget === n ? null : n;
    }

    function submit(n: var, psk: string): void {
        if (psk.length < 8 && n.security !== WifiSecurityType.StaticWep)
            return;
        failName = "";
        pskTarget = null;
        n.connectWithPsk(psk);
    }

    function failed(n: var, reason: int): void {
        failName = n.name;
        failMsg = reason === ConnectionFailReason.NoSecrets ? (n.known ? "Wrong password" : "Password required")
            : reason === ConnectionFailReason.WifiAuthTimeout ? "Authentication timed out"
            : reason === ConnectionFailReason.WifiNetworkLost ? "Network lost"
            : "Couldn't connect";
        if ((reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
                && isSecured(n) && !isEnterprise(n))
            pskTarget = n;
    }

    function status(n: var): string {
        if (n.name === failName)
            return failMsg;
        if (n.state === ConnectionState.Connecting)
            return "Connecting…";
        if (n.state === ConnectionState.Disconnecting)
            return "Disconnecting…";
        if (n.connected)
            return "Connected";
        if (n.known)
            return "Saved";
        return isSecured(n) ? "Secured" : "Open";
    }

    Rectangle {
        id: card
        width: parent.width
        height: body.implicitHeight + 12
        radius: Theme.radius
        color: Theme.glassHi
        opacity: root.reveal
        y: (1 - root.reveal) * -10

        Column {
            id: body
            x: 6
            y: 6
            width: parent.width - 12

            // ---------- header ----------
            Item {
                width: parent.width
                height: 34

                Txt {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Networks"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.fgDim
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "wifi-cog"
                    iconSize: 15
                    onClicked: {
                        ShellState.closeAll();
                        Quickshell.execDetached(["nm-connection-editor"]);
                    }
                }
            }

            // ---------- empty states ----------
            Txt {
                visible: !Sys.wifiOn || root.networks.length === 0
                width: parent.width
                height: 44
                horizontalAlignment: Text.AlignHCenter
                text: !Sys.wifiOn ? "Wi-Fi is off" : !root.dev ? "No Wi-Fi adapter" : "Searching…"
                font.pixelSize: 12
                color: Theme.fgDim
            }

            // ---------- networks ----------
            ListView {
                id: list
                visible: Sys.wifiOn
                width: parent.width
                height: Math.min(contentHeight, 46 * 5.5)
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: Sys.wifiOn ? root.networks : []
                }

                move: Transition {
                    NumberAnimation { property: "y"; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool asking: root.pskTarget === modelData
                    readonly property bool busy: modelData.state === ConnectionState.Connecting
                        || modelData.state === ConnectionState.Disconnecting
                    readonly property bool failedHere: modelData.name === root.failName

                    width: list.width
                    height: 44 + (asking ? 44 : 0)
                    clip: true
                    Behavior on height { NumberAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standard } }

                    onAskingChanged: if (asking) {
                        psk.text = "";
                        psk.forceActiveFocus();
                    }

                    Connections {
                        target: row.modelData
                        function onConnectionFailed(reason: int): void {
                            root.failed(row.modelData, reason);
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: Theme.radiusSm
                        color: rowMouse.containsMouse ? Theme.glassHover
                            : row.modelData.connected || row.asking ? Theme.glassHi : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }

                    MouseArea {
                        id: rowMouse
                        width: parent.width
                        height: 44
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(row.modelData)
                    }

                    MIcon {
                        id: sigIcon
                        x: 12
                        y: 22 - height / 2
                        icon: Sys.wifiIcon(row.modelData.signalStrength)
                        size: 17
                        color: row.modelData.connected ? Theme.fg : Theme.fgDim
                    }

                    Column {
                        anchors.left: sigIcon.right
                        anchors.leftMargin: 12
                        anchors.right: trailing.left
                        anchors.rightMargin: 8
                        y: 22 - height / 2
                        spacing: 0

                        Txt {
                            width: parent.width
                            text: row.modelData.name
                            font.weight: row.modelData.connected ? Font.Bold : Font.Medium
                        }
                        Txt {
                            width: parent.width
                            text: root.status(row.modelData)
                            font.pixelSize: 11
                            color: row.failedHere ? Theme.danger : Theme.fgDim
                        }
                    }

                    Row {
                        id: trailing
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        y: 22 - height / 2
                        spacing: 4

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.known && (rowMouse.containsMouse || hovered)
                            readonly property bool hovered: forgetHover.hovered
                            implicitWidth: 28
                            implicitHeight: 28
                            icon: "trash-2"
                            iconSize: 14
                            onClicked: row.modelData.forget()
                            HoverHandler { id: forgetHover }
                        }
                        Spinner {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.busy
                            size: 15
                        }
                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.connected && !row.busy
                            icon: "check"
                            size: 15
                        }
                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.isSecured(row.modelData)
                            icon: "lock"
                            size: 13
                            color: Theme.fgMuted
                        }
                        Item { width: 4; height: 1 }
                    }

                    // ---------- password ----------
                    Rectangle {
                        x: 8
                        y: 46
                        width: parent.width - 16
                        height: 34
                        radius: Theme.radiusSm
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: psk.activeFocus ? Theme.borderHi : Theme.border
                        visible: row.asking || row.height > 44

                        TextInput {
                            id: psk
                            property bool reveal: false
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: pskBtns.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            selectionColor: Theme.borderHi
                            echoMode: reveal ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            clip: true
                            onAccepted: root.submit(row.modelData, text)
                            Keys.onEscapePressed: root.pskTarget = null

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: psk.text === ""
                                text: "Password"
                                color: Theme.fgMuted
                            }
                        }

                        Row {
                            id: pskBtns
                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            IconButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                icon: psk.reveal ? "eye-off" : "eye"
                                iconSize: 14
                                onClicked: psk.reveal = !psk.reveal
                            }
                            IconButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                icon: "arrow-right"
                                iconSize: 15
                                active: psk.text.length >= 8
                                onClicked: root.submit(row.modelData, psk.text)
                            }
                        }
                    }
                }
            }
        }
    }

    component Spinner: MIcon {
        id: spin
        icon: "loader-circle"
        RotationAnimation on rotation {
            running: spin.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }
}
