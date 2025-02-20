#!/usr/bin/env bash

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value="$(tmux show-option -gqv "$option")"
    
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Function to parse YAML using yq
parse_yaml() {
    local template_file="$1"
    yq -r '.windows[].name' "$template_file"
}

# Function to create a new tmux window
create_window() {
    local session_name="$1"
    local window_name="$2"
    local window_index="$3"
    
    if [ "$window_index" -eq 0 ]; then
        tmux rename-window -t "$session_name:$window_index" "$window_name"
    else
        tmux new-window -t "$session_name" -n "$window_name"
    fi
}