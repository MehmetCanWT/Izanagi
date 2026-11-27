-- Hyprland Window & Layer Rules

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Floating utility windows
hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol)$" },
    float = true,
    size  = "800 500",
    center = true,
})

hl.window_rule({
    name  = "float-nm-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "float-polkit-agent",
    match = { class = "^(hyprpolkitagent|org\\.kde\\.polkit-kde-authentication-agent-1)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = "^(Open File|Save File|Select Folder|Dosya Aç|Farklı Kaydet)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name   = "float-luciole",
    match  = { class = "^(luciole|dev\\.noctalia\\.luciole)$" },
    float  = true,
    size   = "1280 720",
    center = true,
})

hl.window_rule({
    name   = "float-swayimg",
    match  = { class = "^(swayimg|swayimg_.*)$" },
    float  = true,
    size   = "1200 760",
    center = true,
})

-- Steam / Proton / Linux Games: tearing + no blur/shadow/anim for low latency
hl.window_rule({
    name      = "games-low-latency",
    match     = { class = "^(steam_app_.*|cs2|dota2|gamescope|Minecraft.*|factorio)$" },
    immediate = true,
    no_anim   = true,
    no_blur   = true,
    no_shadow = true,
})
