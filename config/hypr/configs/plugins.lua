-- Hyprland Plugin Configurations (loaded via `hyprpm reload -n`)

if hl.plugin.hypr_edgehover ~= nil then
    hl.config({
        plugin = {
            hypr_edgehover = {
                enabled             = 1,
                edges               = "lrtb",
                inset               = 1,
                max_distance        = 0,
                keyboard_focus      = -1,
                gap_pass            = "hover,click,scroll,keyboard",
                layer_pass          = "hover,keyboard",
                layer_namespaces    = "",
                overhang_pass       = "hover,keyboard",
                overhang_threshold  = 8,
                overhang_edge_width = 0,
                steal_edge_width    = 2,
                zones_top           = "0-100",
                zones_bottom        = "0-100",
                zones_left          = "0-100",
                zones_right         = "0-100",
            },
        },
    })
end

if hl.plugin.confined_floats ~= nil then
    hl.window_rule({
        match = { float = true, fullscreen = false },
        ["confined-floats:confine"] = true,
    })
end

if hl.plugin.hyprcapture ~= nil then
    hl.config({
        plugin = {
            hyprcapture = {
                screenshot_notification = false,
                show_thumbnail          = false,
            },
        },
    })
end

if hl.plugin.overview ~= nil then
    hl.config({
        plugin = {
            overview = {
                panelColor                  = "rgba(17, 17, 27, 0.92)",
                panelBorderColor            = "rgba(203, 166, 247, 0.35)",
                panelBorderWidth            = 1,
                panelHeight                 = 260,
                reservedArea                = 38,
                workspaceActiveBackground   = "rgba(49, 50, 68, 0.85)",
                workspaceInactiveBackground = "rgba(24, 24, 37, 0.70)",
                workspaceActiveBorder       = "rgb(203, 166, 247)",
                workspaceInactiveBorder     = "rgba(255, 255, 255, 0.12)",
                workspaceBorderSize         = 2,
                onBottom                    = false,
                centerAligned               = true,
                autoDrag                    = true,
                exitOnClick                 = true,
                exitOnSwitch                = true,
                showNewWorkspace            = true,
                showEmptyWorkspace          = false,
            },
        },
    })
end
