-- Default programs, shared by autostart.lua and keybindings.lua.

return {
    terminal    = "kitty",
    fileManager = "nautilus --new-window",
    browser     = "gtk-launch org.mozilla.firefox",
    shell       = "qs ipc call shell", -- Quickshell IPC (bar, launcher, control center)
}
