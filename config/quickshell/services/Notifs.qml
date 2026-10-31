pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Popups are shown in the bar's center pill (NotificationView).
Singleton {
    id: root

    readonly property var list: server.trackedNotifications
    readonly property int count: server.trackedNotifications.values.length
    // Monitor whose center pill shows the popups. Picked when the first one
    // arrives, so a burst doesn't jump between screens as focus moves.
    property string screen: ""

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            if (ShellState.dnd && n.urgency !== NotificationUrgency.Critical)
                return;
            if (root.count === 0)
                root.screen = ShellState.focusedScreen || (Quickshell.screens[0]?.name ?? "");
            n.tracked = true;
        }
    }
}
