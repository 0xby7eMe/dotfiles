-- Look and feel: gaps, borders, rounding, shadows, blur, misc.

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 1,
        col = {
            active_border   = "rgba(ffffff55)",
            inactive_border = "rgba(ffffff10)",
        },
        resize_on_border = true,
        extend_border_grab_area = 12,
        allow_tearing = false,
        layout = "dwindle",
        snap = {
            enabled = true,
        },
    },

    decoration = {
        rounding       = 14,
        rounding_power = 2.4,   -- smooth "squircle" corners like rounded-window-corners

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 28,
            render_power = 3,
            offset       = "0 6",
            color        = "rgba(00000099)",
            color_inactive = "rgba(00000055)",
        },

        blur = {
            enabled   = true,
            size      = 7,
            passes    = 3,
            vibrancy  = 0.17,
            noise     = 0.01,
            popups    = true,
            special   = true,   -- blur behind the scratchpad / special workspaces
            new_optimizations = true,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        -- lets a restarted Quickshell take over the session lock if it crashed
        allow_session_lock_restore = true,
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        background_color = "rgb(000000)",
        focus_on_activate = true,
        animate_manual_resizes = true,
        animate_mouse_windowdragging = false,
        vrr = 2, -- fullscreen only
    },

    cursor = {
        sync_gsettings_theme = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})
