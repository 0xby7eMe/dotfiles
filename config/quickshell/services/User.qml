pragma Singleton
import QtQuick
import Quickshell

// The logged-in user, for the lock screen and authentication prompts.
Singleton {
    readonly property string login: Quickshell.env("USER") ?? ""
    readonly property string name: login.charAt(0).toUpperCase() + login.slice(1)
    // shared with hyprlock
    readonly property string avatar: "file://" + Quickshell.env("HOME") + "/.config/hypr/assets/avatar.png"
}
