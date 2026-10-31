-- Autostart

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORMTHEME")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
    hl.exec_cmd("qs")                                   -- bar, launcher, dock, notifications, OSD, wallpaper, lock screen, polkit agent
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprpm reload -n")                     -- plugins (see scripts/hyprpm-plugins.sh in the dotfiles repo)
    hl.exec_cmd("[ -x /opt/vesktop/vesktop ] && /opt/vesktop/vesktop --start-minimized")
end)
