#!/usr/bin/env bash
set -euo pipefail

ws=$(hyprctl activeworkspace -j | jq -r '.id')
[ -n "$ws" ] && [ "$ws" != "null" ] || exit 0

state_file="${XDG_RUNTIME_DIR:-/tmp}/hypr_show_desktop_${ws}"
special_ws="special:desktop_${ws}"

mapfile -t current_wins < <(
    hyprctl clients -j | jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws and .mapped == true) | .address'
)

if [ "${#current_wins[@]}" -gt 0 ]; then
    printf '%s\n' "${current_wins[@]}" > "$state_file"
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
elif [ -f "$state_file" ]; then
    mapfile -t saved_wins < "$state_file"
    rm -f "$state_file"
    if [ "${#saved_wins[@]}" -gt 0 ]; then
        cmds=()
        for addr in "${saved_wins[@]}"; do
            [ -n "$addr" ] || continue
            cmds+=("dispatch hl.dsp.window.move({ workspace = $ws, silent = true, window = \"address:$addr\" })")
        done
        if [ "${#cmds[@]}" -gt 0 ]; then
            batch=$(IFS=';'; echo "${cmds[*]}")
            hyprctl --batch "$batch" >/dev/null
        fi
    fi
fi
