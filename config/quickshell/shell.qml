//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Grey-Dark
import QtQuick
import Quickshell
import qs.modules

ShellRoot {
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        Dock {}
    }

    Variants {
        model: Quickshell.screens
        OverlayBackdrop {}
    }

    ControlCenter {}
    Osd {}
    Overview {}
    Cheatsheet {}
    PolkitPrompt {}
    Lock {}
    AppSwitcher {}
}
