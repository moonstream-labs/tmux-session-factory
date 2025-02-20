#!/usr/bin/env bash

# Enable debug mode
set -x

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$CURRENT_DIR")"
TEMPLATES_DIR="$PARENT_DIR/templates"

# Debug output
echo "CURRENT_DIR: $CURRENT_DIR" >&2
echo "PARENT_DIR: $PARENT_DIR" >&2
echo "TEMPLATES_DIR: $TEMPLATES_DIR" >&2

source "$CURRENT_DIR/helpers.sh"

# Function to list available templates using fzf
select_template() {
    local templates_dir="$1"
    find "$templates_dir" -name "*.yml" -exec basename {} .yml \; | \
        fzf --height 40% --reverse --prompt="Select template: " 2>/dev/null
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
    
    echo "Creating session: $session_name from template: $template_file" >&2
    
    # Check if template exists
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file not found: $template_file" >&2
        return 1
    fi

    # Create new session
    tmux new-session -d -s "$session_name"
    
    # Check if session was created
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "Error: Failed to create session: $session_name" >&2
        return 1
    fi

    # Read template and create windows
    local window_index=0
    while IFS= read -r window_name; do
        echo "Creating window: $window_name (index: $window_index)" >&2
        create_window "$session_name" "$window_name" "$window_index"
        ((window_index++))
    done < <(parse_yaml "$template_file")

    # Switch to the new session
    tmux switch-client -t "$session_name"
}

# Main execution
if [ "$#" -eq 0 ]; then
    echo "No arguments provided, showing template selection" >&2
    template_name=$(select_template "$TEMPLATES_DIR")
    [ -n "$template_name" ] && get_session_name "$template_name"
elif [ "$#" -eq 2 ]; then
    echo "Creating session with name: $1 and template: $2" >&2
    create_session_from_template "$1" "$2"
fi