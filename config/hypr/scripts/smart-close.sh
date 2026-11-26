#!/usr/bin/env bash
set -euo pipefail

for target in launcher wallpaper clipboard wifi bluetooth audio brightness calendar battery; do
    if [ "$(qs ipc call "$target" closeIfOpen 2>/dev/null || true)" = "true" ]; then
        exit 0
    fi
done

hyprctl dispatch "hl.dsp.window.close()" >/dev/null
