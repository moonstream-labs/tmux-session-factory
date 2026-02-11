#!/usr/bin/env bash

# Shared utility functions for tmux-session-factory.
# Sourced by all scripts — do NOT set -euo pipefail here.

# ── Guard against double-sourcing ──
[[ -n "${_SESSION_FACTORY_HELPERS_LOADED:-}" ]] && return
_SESSION_FACTORY_HELPERS_LOADED=1

# ── Read a tmux user option, returning a default if unset ──
# This is the standard TPM pattern for plugin configuration.
#
# Usage: get_tmux_option "@option-name" "default-value"
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value="$(tmux show-option -gqv "$option")"
    if [[ -z "$option_value" ]]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# ── Display a message in the tmux status line for a fixed duration ──
# Temporarily overrides display-time, then restores it.
#
# Usage: display_message "message text"
display_message() {
    local message="$1"
    local saved_display_time
    saved_display_time="$(get_tmux_option "display-time" "750")"
    tmux set-option -gq display-time 4000
    tmux display-message "$message"
    tmux set-option -gq display-time "$saved_display_time"
}

# ── Resolve the template storage directory ──
# Sources variables.sh if not already loaded.
get_template_dir() {
    local dir
    dir="$(get_tmux_option "$template_dir_option" "$template_dir_default")"
    # Expand tilde to $HOME
    dir="${dir/#\~/$HOME}"
    echo "$dir"
}

# ── Sanitize a template name for use as a filename ──
# Replace non-alphanumeric/hyphen/underscore with hyphen,
# collapse consecutive hyphens, strip leading/trailing hyphens.
#
# Usage: sanitize_name "My Template Name!"
sanitize_name() {
    local name="$1"
    echo "$name" | tr -cs '[:alnum:]-_' '-' | sed 's/--*/-/g; s/^-//; s/-$//'
}

# ── List template files sorted by modification time (newest first) ──
# Outputs full paths, one per line.
list_template_files() {
    local dir
    dir="$(get_template_dir)"
    ls -t "$dir"/*.json 2>/dev/null
}

# ── Check if a tmux session with the given name already exists ──
# Returns 0 if exists, 1 if not.
session_exists() {
    tmux has-session -t "=$1" 2>/dev/null
}

# ── Snapshot a running session to a JSON template file ──
# This is the core capture logic used by both _snapshot.sh and _edit_save.sh.
#
# Usage: snapshot_session <session_name> <template_name> <output_file>
snapshot_session() {
    local session_name="$1"
    local template_name="$2"
    local output_file="$3"

    local windows_json="[]"

    # Iterate over windows
    while IFS=$'\t' read -r win_idx win_name win_layout win_active; do
        local panes_json="[]"

        # Iterate over panes in this window
        while IFS=$'\t' read -r pane_idx pane_path pane_cmd pane_active; do
            panes_json=$(echo "$panes_json" | jq \
                --arg idx "$pane_idx" \
                --arg path "$pane_path" \
                --arg cmd "$pane_cmd" \
                --arg active "$pane_active" \
                '. + [{
                    index: ($idx | tonumber),
                    path: $path,
                    command: $cmd,
                    active: ($active == "1")
                }]')
        done < <(tmux list-panes -t "${session_name}:${win_idx}" \
            -F '#{pane_index}	#{pane_current_path}	#{pane_current_command}	#{pane_active}')

        windows_json=$(echo "$windows_json" | jq \
            --arg idx "$win_idx" \
            --arg name "$win_name" \
            --arg layout "$win_layout" \
            --arg active "$win_active" \
            --argjson panes "$panes_json" \
            '. + [{
                index: ($idx | tonumber),
                name: $name,
                layout: $layout,
                active: ($active == "1"),
                panes: $panes
            }]')
    done < <(tmux list-windows -t "$session_name" \
        -F '#{window_index}	#{window_name}	#{window_layout}	#{window_active}')

    # Assemble final JSON
    jq -n \
        --arg name "$template_name" \
        --arg created "$(date -Iseconds)" \
        --arg source "$session_name" \
        --argjson windows "$windows_json" \
        '{
            name: $name,
            created: $created,
            source_session: $source,
            windows: $windows
        }' > "$output_file"
}
