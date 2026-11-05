pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Every notification stays tracked (the history in the
// notification center, DashView) until it is dismissed there or the app
// closes it; `popups` is the subset currently shown as toasts in the bar's
// center pill (NotificationView). Tracked ones survive shell reloads.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications
    // newest first
    readonly property var history: [...server.trackedNotifications.values].reverse()
    property var popups: []
    readonly property int count: popups.length
    // Monitor whose center pill shows the popups. Picked when the first one
    // arrives, so a burst doesn't jump between screens as focus moves.
    property string screen: ""
    // arrival time per notification id (lost on reload: shown without a time)
    property var times: ({})

    readonly property int maxHistory: 60

    function hidePopup(n: var): void {
        popups = popups.filter(p => p !== n);
        // transient ones aren't meant to linger in the history
        if (n?.transient)
            n.expire();
    }

    function clearPopups(): void {
        for (const n of popups)
            if (n?.transient)
                n.expire();
        popups = [];
    }

    function clearAll(): void {
        for (const n of [...server.trackedNotifications.values])
            n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: Date.now() });
            n.closed.connect(() => root.popups = root.popups.filter(p => p !== n));

            const all = server.trackedNotifications.values;
            if (all.length > root.maxHistory)
                all[0].dismiss();

            // silenced, or the list is already open: straight to the history
            if ((ShellState.dnd && n.urgency !== NotificationUrgency.Critical) || ShellState.dashOpen)
                return;
            if (root.popups.length === 0)
                root.screen = ShellState.focusedScreen || (Quickshell.screens[0]?.name ?? "");
            root.popups = [...root.popups, n];
        }
    }
}
