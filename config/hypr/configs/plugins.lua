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
                panelColor                  = "rgba(14, 14, 20, 0.86)",
                panelBorderColor            = "rgba(255, 255, 255, 0.12)",
                panelBorderWidth            = 1,
                panelHeight                 = 220,
                reservedArea                = 0,
                workspaceMargin             = 14,
                workspaceActiveBackground   = "rgba(30, 32, 44, 0.75)",
                workspaceInactiveBackground = "rgba(18, 18, 26, 0.65)",
                workspaceActiveBorder       = "rgba(173, 198, 255, 0.95)",
                workspaceInactiveBorder     = "rgba(255, 255, 255, 0.14)",
                workspaceBorderSize         = 2,
                onBottom                    = false,
                centerAligned               = true,
                hideBackgroundLayers        = false,
                hideTopLayers               = true,
                hideOverlayLayers           = true,
                hideRealLayers              = true,
                drawActiveWorkspace         = true,
                affectStrut                 = true,
                overrideGaps                = true,
                gapsIn                      = 12,
                gapsOut                     = 28,
                disableBlur                 = false,
                autoDrag                    = true,
                exitOnClick                 = true,
                exitOnSwitch                = true,
                showNewWorkspace            = true,
                showEmptyWorkspace          = false,
            },
        },
    })
end
