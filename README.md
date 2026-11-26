# Izanagi

**Hyprland 0.57+ (Native Lua)** + **Quickshell (QtQuick/QML)** + **Matugen (Material You 3)** dotfiles.

## Directory Structure

```text
Izanagi/
├── config/
│   ├── fontconfig/         # 0xProto Nerd Font defaults
│   ├── ghostty/            # Ghostty terminal + dynamic Matugen palette
│   ├── gtk-3.0/            # GTK 3 settings + dynamic colors
│   ├── gtk-4.0/            # GTK 4 settings + dynamic colors
│   ├── hypr/               # Hyprland Lua config, hyprpaper & scripts
│   ├── matugen/            # Material You 3 config & templates (`scheme-fidelity`)
│   ├── quickshell/         # Custom QML shell (Bar, Launcher, WallpaperPicker, Menus, Widgets, LockScreen)
│   └── rustfetch/          # System fetch config & logos
├── scripts/
│   ├── apply-wallpaper     # Hyprpaper + vibrant Matugen theme applier
│   └── game-run            # NVIDIA PRIME + Vulkan offload launcher
├── assets/
│   ├── fonts/              # 0xProto Nerd Font
│   └── wallpapers/         # Bundled wallpapers
└── install.sh              # Setup & symlink script
```

## Quickshell Modules

- **Bar:** Date/time (Calendar & MPRIS), open workspaces, System Tray (`QsMenuAnchor`), Volume/Brightness/Wi-Fi/Bluetooth/Battery/Power.
- **Launcher (`SUPER + Space`):** Live app search & launch (`DesktopEntries`).
- **WallpaperPicker (`SUPER + W`):** Infinite horizontal carousel (`A`/`D`, `←`/`→`, `Space`/`Enter`) + vibrant Matugen theming.
- **ClipboardMenu (`SUPER + V`):** Searchable `cliphist` history with image thumbnail previews.
- **KeybindsMenu (`SUPER + K`):** Live searchable overview parsed from `keybinds.lua`.
- **Control Menus:** Wi-Fi (`nmcli`), Bluetooth (`bluetoothctl`), Audio (`wpctl` sink/mic), Brightness, Battery (`powerprofilesctl` + Acer Nitro 80% lock), Calendar + MPRIS, Power (`Lock`/`Reboot`/`Shutdown`).
- **OSD & Notifications:** Native `NotificationServer` (bottom-right) + Volume/Brightness OSD.
- **Desktop Widgets (`WlrLayer.Bottom`):** Minimal Clock & Date, Now Playing (MPRIS + `sonata:motionArtUrl` MP4 cover + 5-line smooth synced lyrics), Phone Battery (KDE Connect), System Monitor (CPU / RAM / Temp).
- **Session & Switcher:** Quickshell Lock Screen (`SUPER + L` via `WlSessionLock` + PAM), Windows-style live `ScreencopyView` Window Switcher (`ALT + Tab`).

## Installation

```bash
git clone https://github.com/MehmetCanWT/Izanagi.git ~/Code/Izanagi
cd ~/Code/Izanagi && ./install.sh
```

## Keybinds (`SUPER` = Windows Key)

- `SUPER + Space` — Quickshell Launcher
- `SUPER + W` — Quickshell Wallpaper Picker
- `SUPER + V` — Quickshell Clipboard History
- `SUPER + K` — Quickshell Keybinds Menu
- `ALT + Tab` / `ALT + SHIFT + Tab` — Live Window Switcher
- `SUPER + Return` — Ghostty Terminal
- `SUPER + E` — Dolphin File Manager
- `SUPER + B` — Zen Browser
- `SUPER + L` — Quickshell Lock Screen (`WlSessionLock` + PAM)
- `SUPER + Q` — Close Open Shell Overlay or Active Window
- `SUPER + C` — Toggle Floating
- `SUPER + F` — Toggle Fullscreen
- `Print` / `Shift + Print` — Region / Fullscreen Screenshot
