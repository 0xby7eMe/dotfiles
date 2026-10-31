-- Hyprland config — monochrome rice with a Quickshell bar, launcher and dock.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
--
-- Everything lives in ./modules, one file per concern. Order matters where
-- noted (e.g. plugins use curves defined in animations).

require("modules.monitors")     -- outputs, modes, scaling
require("modules.environment")  -- env vars, hybrid-GPU setup
require("modules.autostart")    -- programs launched with Hyprland
require("modules.appearance")   -- gaps, borders, rounding, shadows, blur, misc
require("modules.animations")   -- curves + animation leaves
require("modules.plugins")      -- hyprpm plugins (after animations)
require("modules.input")        -- keyboard, mouse, touchpad, gestures
require("modules.keybindings")  -- all binds (programs come from modules/programs.lua)
require("modules.rules")        -- window + layer rules
