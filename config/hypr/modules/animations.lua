-- Motion: springy windows, smooth Material-style easing everywhere else.

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("emphasized",      { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}    } })
hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3, 0},    {0.8, 0.15} } })
hl.curve("standard",        { type = "bezier", points = { {0.2, 0},    {0, 1}      } })
hl.curve("linear",          { type = "bezier", points = { {0, 0},      {1, 1}      } })
hl.curve("soft",            { type = "spring", mass = 1, stiffness = 210, dampening = 22 })
hl.curve("snappy",          { type = "spring", mass = 1, stiffness = 320, dampening = 28 })

hl.animation({ leaf = "global",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "windows",          enabled = true, speed = 5,   spring = "soft" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4.5, spring = "soft",            style = "popin 88%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 2,   bezier = "emphasizedAccel", style = "popin 88%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 5,   spring = "snappy" })
hl.animation({ leaf = "border",           enabled = true, speed = 4,   bezier = "standard" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 2.5, bezier = "standard" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 2,   bezier = "emphasizedAccel" })
hl.animation({ leaf = "fade",             enabled = true, speed = 3,   bezier = "standard" })
hl.animation({ leaf = "layers",           enabled = true, speed = 3.5, bezier = "emphasized" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3.5, bezier = "emphasized",      style = "fade" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2,   bezier = "emphasizedAccel", style = "fade" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4.5, bezier = "emphasized",      style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "emphasized",      style = "slidevert" })
hl.animation({ leaf = "zoomFactor",       enabled = true, speed = 5,   bezier = "standard" })
