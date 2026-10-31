-- Monitors — https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Laptop panel (same as GNOME: 165 Hz, 125 %)
hl.monitor({ output = "eDP-1", mode = "1920x1200@165", position = "auto", scale = 1.25 })
-- Anything else (the AOC 144 Hz monitors etc.): highest refresh, placed to the right
hl.monitor({ output = "", mode = "highrr", position = "auto-right", scale = 1 })
