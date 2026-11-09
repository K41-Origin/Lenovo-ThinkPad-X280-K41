-- K41 Obsidian Minimalism — appearance overlay.
-- Keep the compositor cursor theme aligned with GTK and Caelestia.
hl.env("XCURSOR_THEME", "Adwaita")
-- Loaded at the end of the existing Hyprland Lua config by the apply script.
-- Keep this module limited to visual settings; do not redefine keybinds or input.

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 14,
        border_size = 1,
        col = {
            active_border = "rgba(c4c4c9ff)",
            inactive_border = "rgba(29292eff)",
        },
    },
    decoration = {
        rounding = 8,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 3,
            render_power = 2,
            color = 0x66000000,
        },
        blur = {
            enabled = false,
        },
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})
