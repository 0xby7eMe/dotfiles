pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Session lock (ext-session-lock): replaces hyprlock. hypridle's lock_cmd and
// `loginctl lock-session` (Super+L) end up in `qs ipc call lock lock`.
// Every monitor gets a LockContent; the password is shared between them, so
// typing works on whichever screen has focus.
//
// `qs ipc call lock preview` shows the same UI in a normal window without
// locking (Esc closes it) — handy for checking the look and your password.
//
// If Quickshell ever dies while locked, Hyprland keeps the session locked;
// from a TTY run: hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs")'
// (misc.allow_session_lock_restore lets the new instance take over).
Scope {
    id: root

    property bool preview: false

    // ---------- shared state ----------
    property string text: ""
    property bool busy: false
    property bool failed: false
    property bool unlocking: false   // success animation playing
    property string focusedAtLock: ""
    signal failure

    readonly property bool active: sessionLock.locked || preview

    function reset(): void {
        text = "";
        busy = false;
        failed = false;
        unlocking = false;
    }

    function lockNow(): void {
        if (sessionLock.locked)
            return;
        reset();
        ShellState.closeAll();
        focusedAtLock = ShellState.focusedScreen;
        preview = false;
        sessionLock.locked = true;
    }

    function submit(): void {
        if (busy || unlocking || text === "")
            return;
        busy = true;
        failed = false;
        if (!pam.start()) {
            busy = false;
            failed = true;
            failure();
        }
    }

    function cancelPreview(): void {
        if (preview && !unlocking)
            preview = false;
    }

    PamContext {
        id: pam
        // same stack hyprlock uses (includes login → system-auth)
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired)
                respond(root.text);
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.unlocking = true;
                finishTimer.start();
            } else {
                root.text = "";
                root.failed = true;
                root.failure();
            }
        }
        onError: err => {
            console.warn("lock: PAM error", PamError.toString(err));
            root.busy = false;
            root.text = "";
            root.failed = true;
            root.failure();
        }
    }

    // let the unlock animation play before the surfaces go away
    Timer {
        id: finishTimer
        interval: Theme.durSlow
        onTriggered: {
            sessionLock.locked = false;
            root.preview = false;
            root.reset();
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: "black"

            LockContent {
                anchors.fill: parent
                lock: root
                screen: surface.screen
            }
        }
    }

    // preview: same UI, normal overlay window on the focused monitor
    Loader {
        active: root.preview
        sourceComponent: PanelWindow {
            id: pv
            screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen) ?? Quickshell.screens[0]
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "qs-lock-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockContent {
                anchors.fill: parent
                lock: root
                screen: pv.screen
                preview: true
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lockNow();
        }
        function preview(): void {
            if (sessionLock.locked)
                return;
            root.reset();
            ShellState.closeAll();
            root.focusedAtLock = ShellState.focusedScreen;
            root.preview = !root.preview;
        }
        function isLocked(): bool {
            return sessionLock.locked;
        }
    }
}
