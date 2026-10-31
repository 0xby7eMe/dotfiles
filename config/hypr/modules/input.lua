-- Input: keyboard, mouse, touchpad and gestures.

hl.config({
    input = {
        kb_layout = "de",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
    gestures = {
        workspace_swipe_cancel_ratio = 0.15,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up",   action = "fullscreen" })
