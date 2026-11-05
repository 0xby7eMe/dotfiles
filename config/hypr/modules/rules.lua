-- Window and layer rules

---- Windows ----

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name  = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Utility windows float, centered
hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(org.pulseaudio.pavucontrol|pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Calculator|hyprpolkitagent|org.gnome.FileRoller|xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
})
hl.window_rule({
    name  = "pavucontrol-size",
    match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" },
    size  = { 760, 520 },
})
hl.window_rule({
    name   = "float-dialogs",
    match  = { title = "^(Open File|Open Folder|Save As|Save File|Choose Files?|File Upload|Select a File).*" },
    float  = true,
    center = true,
    size   = { "monitor_w * 0.55", "monitor_h * 0.6" },
})
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin   = true,
    size  = { 480, 270 },
    move  = { "monitor_w - window_w - 24", "monitor_h - window_h - 90" },
    keep_aspect_ratio = true,
})

---- Layers ----

-- Quickshell draws its own animations; don't let Hyprland animate those layers too.
hl.layer_rule({
    name    = "qs-no-anim",
    match   = { namespace = "^qs-.*" },
    no_anim = true,
})
hl.layer_rule({
    name  = "qs-blur",
    match = { namespace = "^qs-(bar|dock|launcher|control|weather|notifications|osd|traymenu|switcher)$" },
    blur  = true,
    ignore_alpha = 0.6,
})
-- Fullscreen overlays: blur everything behind their tinted backdrop, on every
-- monitor (qs-backdrop covers the screens the overlay isn't on).
hl.layer_rule({
    name  = "qs-overlay-blur",
    match = { namespace = "^qs-(overview|cheatsheet|polkit|backdrop)$" },
    blur  = true,
    ignore_alpha = 0.05,
})
hl.layer_rule({
    name    = "selection-no-anim",
    match   = { namespace = "^(selection|hyprpicker)$" },
    no_anim = true,
})
