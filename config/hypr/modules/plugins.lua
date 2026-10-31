-- Plugins (built and loaded by hyprpm, see scripts/hyprpm-plugins.sh in the dotfiles repo).
-- Uses curves from animations.lua, so it must be required after it.

-- hyprfocus (only configured once hyprpm has loaded it)
if hl.plugin.hyprfocus ~= nil then
    hl.config({
        plugin = {
            hyprfocus = {
                keyboard_focus_animation = "shrink",
                mouse_focus_animation    = "none",
                shrink_percentage        = 0.985,
            },
        },
    })
    hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 1.8, bezier = "emphasized" })
    hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 2.6, bezier = "standard" })
end
