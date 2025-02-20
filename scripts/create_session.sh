#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$CURRENT_DIR")"
TEMPLATES_DIR="$PARENT_DIR/templates"

source "$CURRENT_DIR/helpers.sh"

# Function to list available templates using fzf
select_template() {
    local templates_dir="$1"
    find "$templates_dir" -name "*.yml" -exec basename {} .yml \; | \
        fzf --prompt "Select template: " --preview "cat {}"
}

# Function to get session name from user
get_session_name() {
    local prompt="Enter session name: "
    tmux command-prompt -p "$prompt" "run-shell \"$CURRENT_DIR/create_session.sh '%%' '$1'\""
}

# Main function to create session from template
create_session_from_template() {
    local session_name="$1"
    local template_name="$2"
    local template_file="$TEMPLATES_DIR/${template_name}.yml"

    # Create new session
    tmux new-session -d -s "$session_name"

    # Read template and create windows
    local window_index=0
    while IFS= read -r window_name; do
        create_window "$session_name" "$window_name" "$window_index"
        ((window_index++))
    done < <(parse_yaml "$template_file")

    # Switch to the new session
    tmux switch-client -t "$session_name"
}

# Main execution
if [ "$#" -eq 0 ]; then
    # No arguments, show template selection
    template_name=$(select_template "$TEMPLATES_DIR")
    [ -n "$template_name" ] && get_session_name "$template_name"
elif [ "$#" -eq 2 ]; then
    # Session name and template provided
    create_session_from_template "$1" "$2"
fi