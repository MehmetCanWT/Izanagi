#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# Izanagi Setup & Installation Script (Hyprland + Quickshell + Matugen)
# ===================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Setting up Izanagi from: $SCRIPT_DIR"

mkdir -p "$HOME/.local/bin" "$HOME/.config"

for pkg in quickshell matugen; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        if command -v pacman >/dev/null 2>&1; then
            echo "==> Installing $pkg via pacman..."
            sudo pacman -S --needed "$pkg"
        else
            echo "!! '$pkg' not found. Please install $pkg manually." >&2
        fi
    fi
done

# Sync bundled wallpapers
WP_DEST="$HOME/Pictures/Wallpapers"
mkdir -p "$WP_DEST"
if [ -d "$SCRIPT_DIR/assets/wallpapers" ]; then
    echo "==> Copying bundled wallpapers to $WP_DEST..."
    cp -n "$SCRIPT_DIR/assets/wallpapers/"* "$WP_DEST/" 2>/dev/null || true
fi

# Install bundled fonts (0xProto Nerd Font)
if [ -d "$SCRIPT_DIR/assets/fonts" ]; then
    echo "==> Installing bundled fonts to ~/.local/share/fonts..."
    mkdir -p "$HOME/.local/share/fonts"
    cp -rf "$SCRIPT_DIR/assets/fonts/"* "$HOME/.local/share/fonts/"
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f || true
fi

# Install helper scripts
for script in game-run apply-wallpaper we-auto-pause; do
    if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
        install -Dm755 "$SCRIPT_DIR/scripts/$script" "$HOME/.local/bin/$script"
    fi
done

link_config() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "==> Backing up existing $dst to ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    echo "==> Linked $dst -> $src"
}

echo "==> Linking configs..."
link_config "$SCRIPT_DIR/config/fontconfig" "$HOME/.config/fontconfig"
link_config "$SCRIPT_DIR/config/ghostty"    "$HOME/.config/ghostty"
link_config "$SCRIPT_DIR/config/hypr"       "$HOME/.config/hypr"
link_config "$SCRIPT_DIR/config/matugen"    "$HOME/.config/matugen"
link_config "$SCRIPT_DIR/config/quickshell" "$HOME/.config/quickshell"
link_config "$SCRIPT_DIR/config/rustfetch"  "$HOME/.config/rustfetch"
link_config "$SCRIPT_DIR/config/swayimg"    "$HOME/.config/swayimg"
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
link_config "$SCRIPT_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
link_config "$SCRIPT_DIR/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

# Ensure fallback hyprlock-colors.conf exists before first matugen run
touch "$SCRIPT_DIR/config/hypr/configs/hyprlock-colors.conf"

# Install & enable Hyprland plugins via hyprpm
if command -v hyprpm >/dev/null 2>&1; then
    echo "==> Installing Hyprland plugins via hyprpm..."
    hyprpm update || true
    for spec in \
        "https://github.com/gfhdhytghd/hypr-edgehover|hypr-edgehover" \
        "https://github.com/gfhdhytghd/HyprCapture|hyprcapture" \
        "https://github.com/mennemann/hyprland-confined-floats|confined-floats" \
        "https://github.com/KZDKM/Hyprspace|Hyprspace"
    do
        repo="${spec%%|*}"
        plugin="${spec##*|}"
        yes | hyprpm add "$repo" || true
        hyprpm enable "$plugin" || true
    done
    hyprpm reload -n || true
fi

echo "==> Izanagi installation complete!"
