-- monitors.lua (universal)
-- https://wiki.hypr.land/Configuring/Monitors/
-- Works on any laptop/desktop with no hardcoded output names.
-- Find your monitor names with:  hyprctl monitors

-- 1. Catch-all rule: every connected output (eDP-1, HDMI-A-1, DP-*, ...)
--    uses its highest resolution, is placed automatically, scale 1.
--    Hotplugged monitors are covered too.
hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1 })

-- Laptop panel. Hyprland needs whole logical sizes: 2560x1600 rejects 1.5 and
-- silently falls back to 1.6, the closest valid scale (1600x1000).
hl.monitor({ output = "eDP-1", mode = "highres", position = "auto", scale = 1.6 })

-- X11 apps (Steam and its games) get the real resolution instead of a reduced
-- one upscaled by the compositor, which is what makes them look jagged.
hl.config({ xwayland = { force_zero_scaling = true } })

-- 2. Optional per-machine overrides written by the Quickshell display settings.
--    The file may define the global MONITOR1 and extra hl.monitor() rules.
--    It is optional: if missing or broken, the defaults above still apply.
local home = os.getenv("HOME")
if home then
    local path = home .. "/.config/quickshell/state/display.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        pcall(dofile, path)
    end
end

-- 3. Workspaces: every output has its own set, so no shortcut pulls focus to another monitor.
--    The main output (MONITOR1, or the laptop panel) uses 1-10. Every other connector has a fixed
--    block (HDMI-A-1 uses 51-60 on this laptop), so its windows find their way back on replug.
local outputs = {}
local connectors = io.popen("ls /sys/class/drm 2>/dev/null")
if connectors then
    for entry in connectors:lines() do
        local name = entry:match("^card%d+%-(.+)$")
        if name and not name:match("^Writeback") then
            table.insert(outputs, name)
        end
    end
    connectors:close()
end
table.sort(outputs)

local function main_output()
    if MONITOR1 and MONITOR1 ~= "" then return MONITOR1 end
    for _, name in ipairs(outputs) do
        if name:match("^eDP") then return name end
    end
    return outputs[1]
end

function workspace_base(name)
    if name == main_output() then return 0 end
    for index, output in ipairs(outputs) do
        if output == name then return index * 10 end
    end
    return 0
end

-- Workspace `index` (1-10) of the focused monitor.
function monitor_workspace(index)
    local monitor = hl.get_active_monitor()
    return workspace_base(monitor and monitor.name) + index
end

-- The workspace `delta` steps away on the focused monitor, wrapping inside its own block.
function monitor_workspace_step(delta)
    local monitor = hl.get_active_monitor()
    local base = workspace_base(monitor and monitor.name)
    local workspace = hl.get_active_workspace()
    local index = workspace and workspace.id - base or 1
    if index < 1 or index > 10 then index = 1 end
    return base + (index - 1 + delta) % 10 + 1
end

for _, name in ipairs(outputs) do
    local base = workspace_base(name)
    for index = 1, 10 do
        hl.workspace_rule({
            workspace = tostring(base + index),
            monitor = name,
            default = index == 1,
            -- Only the main output keeps empty workspaces around: rules for a monitor
            -- that isn't connected must not create workspaces on the others.
            persistent = base == 0 and index <= 4,
        })
    end
end

-- hl.workspace_rule({ workspace = "name:gaming", monitor = MONITOR1, default = true })
