import QtQuick
import qs.services

// macOS-style password pill: masked input, placeholder, a round submit arrow
// that turns into a spinner while checking, and a shake for a wrong password.
// Used by the lock screen and the polkit prompt.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Password"
    property bool busy: false
    property bool reveal: false   // show the typed text (polkit prompts that echo)
    property bool error: false
    signal submitted(string text)
    signal cancelled

    function focusInput(): void {
        input.forceActiveFocus();
    }
    function clear(): void {
        input.text = "";
    }
    function shake(): void {
        shakeAnim.restart();
    }

    implicitWidth: 240
    implicitHeight: 36
    radius: height / 2
    color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.14 : 0.1)
    border.width: 1
    border.color: error ? Theme.danger : Qt.rgba(1, 1, 1, input.activeFocus ? 0.24 : 0.14)
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    transform: Translate { id: shift }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shift; property: "x"; to: -11; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: shift; property: "x"; to: 9; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shift; property: "x"; to: -6; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shift; property: "x"; to: 3; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shift; property: "x"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: go.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        echoMode: root.reveal ? TextInput.Normal : TextInput.Password
        passwordCharacter: "●"
        passwordMaskDelay: 0
        font.family: Theme.font
        font.pixelSize: root.reveal ? 13 : 11
        font.letterSpacing: root.reveal ? 0 : 2.5
        font.weight: Font.Medium
        color: Theme.fg
        selectionColor: Qt.rgba(1, 1, 1, 0.3)
        selectedTextColor: Theme.fg
        clip: true
        readOnly: root.busy
        cursorDelegate: Rectangle {
            width: 2
            color: Theme.fg
            radius: 1
            visible: input.activeFocus && !root.busy
        }

        onAccepted: if (text !== "" && !root.busy) root.submitted(text)
        onTextChanged: root.error = false
        Keys.onEscapePressed: root.cancelled()

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: root.placeholder
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 13
        }
    }

    // submit arrow / spinner
    Rectangle {
        id: go
        readonly property bool armed: input.text !== "" || root.busy
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 10
        height: width
        radius: width / 2
        color: armed ? Qt.rgba(1, 1, 1, goMouse.containsMouse ? 1 : 0.9) : Qt.rgba(1, 1, 1, 0.12)
        scale: goMouse.pressed ? 0.9 : 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }

        MIcon {
            anchors.centerIn: parent
            visible: !root.busy
            icon: "arrow-right"
            size: 15
            color: go.armed ? "#111111" : Qt.rgba(1, 1, 1, 0.5)
        }
        MIcon {
            anchors.centerIn: parent
            visible: root.busy
            icon: "loader-circle"
            size: 15
            color: "#111111"
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        MouseArea {
            id: goMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: go.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (input.text !== "" && !root.busy) root.submitted(input.text)
        }
    }
}
