-- ~/.config/hypr/look.lua
---- LOOK AND FEEL ----
local colors = { active = "rgba(FFFFFFFF)", inactive = "rgba(33333366)" }
local ok, c = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/colors.lua")
if ok and type(c) == "table" then colors = c end

hl.config({ render = { expand_undersized_textures = false}})
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = {
            top = 5,
            right = 8,
            bottom = 8,
            left = 8,
        },
        border_size = 1,
        col = {
            active_border   = colors.active,
            inactive_border = colors.inactive,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

-- speed é medido em décimos de segundo: 2.5 = 250 ms.
hl.curve("easeOut", { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })

-- "global" também vale para o que não tem valor próprio, como o rofi e os menus.
hl.animation({ leaf = "global",     enabled = true, speed = 3,   bezier = "easeOut" })
hl.animation({ leaf = "windows",    enabled = true, speed = 2.5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 2.5, bezier = "easeOut" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2,   bezier = "easeOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "easeOut", style = "slidefadevert" }) -- styles: "slide", "slidefade", "slidevert", "slidefadevert"

