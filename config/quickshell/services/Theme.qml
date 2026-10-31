pragma Singleton
import QtQuick
import Quickshell

// Monochrome palette matching kitty (pure black / white) and Colloid-Dark.
Singleton {
    readonly property color bg: "#000000"
    readonly property color surface: "#0e0e0e"
    readonly property color surfaceHi: "#171717"
    readonly property color hover: "#232323"
    readonly property color border: Qt.rgba(1, 1, 1, 0.07)
    readonly property color borderHi: Qt.rgba(1, 1, 1, 0.14)
    readonly property color fg: "#ffffff"
    readonly property color fgDim: "#a0a0a0"
    readonly property color fgMuted: "#5a5a5a"
    readonly property color accent: "#ffffff"
    readonly property color accentFg: "#000000"
    readonly property color danger: "#ff6b6b"
    // Frosted panels: alpha must stay above the qs-bar layer rule's
    // ignore_alpha (0.6) so Hyprland blurs what's behind them.
    readonly property color glass: Qt.rgba(0, 0, 0, 0.6)
    readonly property color glassHi: Qt.rgba(2, 2, 2, 0.07)
    readonly property color glassHover: Qt.rgba(1, 1, 1, 0.12)
    // Backdrop tint of the fullscreen overlays (overview, cheat sheet). Its
    // alpha must stay above the qs-overlay-blur rule's ignore_alpha (0.05).
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.05)

    readonly property string font: "Manrope"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property FontLoader lucide: FontLoader { source: Qt.resolvedUrl("../assets/lucide.ttf") }
    readonly property string icons: lucide.name

    readonly property int barHeight: 30      // pill height
    readonly property int barGap: 6          // space around the floating pills
    readonly property int barZone: barGap + barHeight
    readonly property int corner: 10        // inverted screen / panel corners
    readonly property int radius: 10
    readonly property int radiusSm: 10
    readonly property int fontSize: 13

    // Motion (Material 3 curves)
    readonly property list<real> emphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
    readonly property int durFast: 180
    readonly property int dur: 300
    readonly property int durSlow: 480
}
