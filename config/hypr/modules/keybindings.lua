-- Keybindings
--
-- Every bind has a description of the form "Category: what it does". The
-- Quickshell cheat sheet (Super+/) reads them back via `hyprctl binds -j`,
-- grouped by category; binds sharing a description are merged into one row.

local programs = require("modules.programs")
local terminal, fileManager, browser, shell = programs.terminal, programs.fileManager, programs.browser, programs.shell

local mod = "SUPER"

-- Shell (Quickshell IPC)
hl.bind(mod .. " + Super_L",   hl.dsp.exec_cmd(shell .. " launcher"),        { release = true, description = "Shell: App launcher" })
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd(shell .. " launcher"),        { description = "Shell: App launcher" })
hl.bind(mod .. " + A",         hl.dsp.exec_cmd(shell .. " launcher"),        { description = "Shell: App launcher" })
hl.bind(mod .. " + Tab",       hl.dsp.exec_cmd(shell .. " overview"),        { description = "Shell: Workspace overview" })
hl.bind(mod .. " + K",     hl.dsp.exec_cmd(shell .. " cheatsheet"),      { description = "Shell: Keyboard shortcuts" })
hl.bind(mod .. " + S",         hl.dsp.exec_cmd(shell .. " control"),         { description = "Shell: Control center" })
hl.bind(mod .. " + V",         hl.dsp.exec_cmd(shell .. " clipboard"),       { description = "Shell: Clipboard history" })
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(shell .. " wallpaper"),       { description = "Shell: Wallpaper picker" })
hl.bind(mod .. " + CTRL + W",  hl.dsp.exec_cmd(shell .. " randomWallpaper"), { description = "Shell: Random wallpaper" })
hl.bind(mod .. " + CTRL + R",  hl.dsp.exec_cmd("pkill -x qs; qs"),           { description = "Shell: Restart Quickshell" })

-- Apps
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal),    { description = "Apps: Terminal" })
hl.bind(mod .. " + T",      hl.dsp.exec_cmd(terminal),    { description = "Apps: Terminal" })
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(fileManager), { description = "Apps: File manager" })
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(browser),     { description = "Apps: Browser" })
hl.bind(mod .. " + L",      hl.dsp.exec_cmd("loginctl lock-session"), { description = "Apps: Lock screen" })
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"),      { description = "Apps: Color picker" })

-- Screenshots (GNOME-style keys)
-- screenshot.sh copies + saves, then notifies with Edit (satty) / Open actions
local shot = "~/.config/quickshell/scripts/screenshot.sh"
hl.bind("Print",                hl.dsp.exec_cmd(shot .. " region"), { description = "Screenshots: Region" })
hl.bind(mod .. " + SHIFT + S",  hl.dsp.exec_cmd(shot .. " region"), { description = "Screenshots: Region" })
hl.bind("SHIFT + Print",        hl.dsp.exec_cmd(shot .. " output"), { description = "Screenshots: Whole screen" })
hl.bind("ALT + Print",          hl.dsp.exec_cmd(shot .. " window"), { description = "Screenshots: Active window" })

-- Windows
hl.bind(mod .. " + Q",          hl.dsp.window.close(),                            { description = "Windows: Close" })
hl.bind("ALT + F4",             hl.dsp.window.close(),                            { description = "Windows: Close" })
hl.bind(mod .. " + W",          hl.dsp.window.float({ action = "toggle" }),       { description = "Windows: Toggle floating" })
hl.bind(mod .. " + F",          hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Windows: Fullscreen" })
hl.bind(mod .. " + M",          hl.dsp.window.fullscreen({ mode = "maximized" }),  { description = "Windows: Maximize" })
hl.bind("ALT + F10",            hl.dsp.window.fullscreen({ mode = "maximized" }),  { description = "Windows: Maximize" })
hl.bind(mod .. " + P",          hl.dsp.window.pseudo(),                           { description = "Windows: Pseudo-tile" })
hl.bind(mod .. " + J",          hl.dsp.layout("togglesplit"),                     { description = "Windows: Toggle split direction" })
hl.bind(mod .. " + C",          hl.dsp.window.center(),                           { description = "Windows: Center" })
hl.bind(mod .. " + SHIFT + P",  hl.dsp.window.pin(),                              { description = "Windows: Pin on all workspaces" })
hl.bind(mod .. " + SHIFT + Q",  hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"), { description = "Session: Log out (exit Hyprland)" })

-- macOS-style app switcher (Quickshell modules/AppSwitcher.qml): hold Alt,
-- Tab / Shift+Tab (or ←/→) to pick, release Alt to switch, Esc to cancel.
-- The panel never takes keyboard focus (that would swallow the switch), so
-- Esc / arrows are bound only while switching, and since binds can't see a
-- modifier being released after another key, a key listener watches for it.
local switching = false
local switchKeys = { "ALT + Escape", "ALT + left", "ALT + right" }

local function finishSwitch(action)
    switching = false
    for _, k in ipairs(switchKeys) do
        hl.unbind(k)
    end
    hl.dispatch(hl.dsp.global("quickshell:switcher" .. action))
end

local function switcher(dir)
    return function()
        if not switching then
            switching = true
            hl.bind("ALT + Escape", function() finishSwitch("Cancel") end)
            hl.bind("ALT + left",   hl.dsp.global("quickshell:switcherPrev"), { repeating = true })
            hl.bind("ALT + right",  hl.dsp.global("quickshell:switcherNext"), { repeating = true })
        end
        hl.dispatch(hl.dsp.global("quickshell:switcher" .. dir))
    end
end

hl.bind("ALT + Tab",         switcher("Next"), { repeating = true, description = "Windows: App switcher" })
hl.bind("ALT + SHIFT + Tab", switcher("Prev"), { repeating = true, description = "Windows: App switcher" })

hl.on("input.keyboard.key", function()
    if not switching then
        return
    end
    -- check on the next tick so the key state includes this event
    hl.timer(function()
        if switching and not (hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")) then
            finishSwitch("Commit")
        end
    end, { timeout = 1, type = "oneshot" })
end)

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir,         hl.dsp.focus({ direction = dir }),       { description = "Windows: Move focus" })
    hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.swap({ direction = dir }), { description = "Windows: Swap windows" })
end
local step = 40
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true, description = "Windows: Resize" })
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = step,  y = 0, relative = true }), { repeating = true, description = "Windows: Resize" })
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true, description = "Windows: Resize" })
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0, y = step,  relative = true }), { repeating = true, description = "Windows: Resize" })

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Windows: Move with mouse" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize with mouse" })

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       { description = "Workspaces: Go to workspace" })
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Workspaces: Move window to workspace" })
end
for i = 1, 5 do -- GNOME habit: Alt+1..5
    hl.bind("ALT + " .. i, hl.dsp.focus({ workspace = i }), { description = "Workspaces: Go to workspace" })
end
hl.bind("CTRL + ALT + left",     hl.dsp.focus({ workspace = "r-1" }), { description = "Workspaces: Previous" })
hl.bind("CTRL + ALT + right",    hl.dsp.focus({ workspace = "r+1" }), { description = "Workspaces: Next" })
hl.bind(mod .. " + Page_Up",     hl.dsp.focus({ workspace = "r-1" }), { description = "Workspaces: Previous" })
hl.bind(mod .. " + Page_Down",   hl.dsp.focus({ workspace = "r+1" }), { description = "Workspaces: Next" })
hl.bind(mod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Scroll through used" })
hl.bind(mod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Scroll through used" })

-- Scratchpad
hl.bind(mod .. " + X",         hl.dsp.workspace.toggle_special("scratch"),            { description = "Workspaces: Toggle scratchpad" })
hl.bind(mod .. " + SHIFT + X", hl.dsp.window.move({ workspace = "special:scratch" }), { description = "Workspaces: Send window to scratchpad" })

-- Media / hardware keys (OSD is drawn by Quickshell)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Media: Volume" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Media: Volume" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Media: Mute" })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Media: Mute microphone" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(shell .. " brightnessUp"),   { locked = true, repeating = true, description = "Media: Brightness" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(shell .. " brightnessDown"), { locked = true, repeating = true, description = "Media: Brightness" })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Media: Previous track" })
