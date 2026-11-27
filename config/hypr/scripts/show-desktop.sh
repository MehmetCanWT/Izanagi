#!/usr/bin/env bash
set -euo pipefail

ws=$(hyprctl activeworkspace -j | jq -r '.id')
[ -n "$ws" ] && [ "$ws" != "null" ] || exit 0

special_ws="special:desktop_${ws}"
clients_json=$(hyprctl clients -j)

# If any windows are currently hidden in special:desktop_<ws>, always restore all of them
mapfile -t hidden_wins < <(
    printf '%s' "$clients_json" | jq -r --arg sp "$special_ws" '.[] | select(.workspace.name == $sp) | .address'
)

if [ "${#hidden_wins[@]}" -gt 0 ]; then
    cmds=()
    for addr in "${hidden_wins[@]}"; do
        [ -n "$addr" ] || continue
        cmds+=("dispatch hl.dsp.window.move({ workspace = $ws, silent = true, window = \"address:$addr\" })")
    done
    if [ "${#cmds[@]}" -gt 0 ]; then
        batch=$(IFS=';'; echo "${cmds[*]}")
        hyprctl --batch "$batch" >/dev/null
    fi
    exit 0
fi

# Otherwise hide all mapped windows on the active workspace
mapfile -t current_wins < <(
    printf '%s' "$clients_json" | jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws and .mapped == true and ((.class // "") | test("wallpaperengine"; "i") | not)) | .address'
)

if [ "${#current_wins[@]}" -gt 0 ]; then
    cmds=()
    for addr in "${current_wins[@]}"; do
        cmds+=("dispatch hl.dsp.window.move({ workspace = \"$special_ws\", silent = true, window = \"address:$addr\" })")
    done
    batch=$(IFS=';'; echo "${cmds[*]}")
    hyprctl --batch "$batch" >/dev/null

    # Ensure special workspace does not remain open as an overlay
    open_sp=$(hyprctl monitors -j | jq -r '.[0].specialWorkspace.name // ""')
    if [ "$open_sp" = "$special_ws" ]; then
        hyprctl dispatch "hl.dsp.workspace.toggle_special(\"desktop_${ws}\")" >/dev/null
    fi
fi
