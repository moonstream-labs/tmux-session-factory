#!/usr/bin/env bash

# manage.sh — Browse, preview, edit, and delete saved templates.
# Trigger: prefix + M
#
# Opens a tmux display-popup with an fzf picker. Actions:
#   Enter   — close (preview is visible during browsing)
#   Ctrl-E  — edit template interactively
#   Ctrl-D  — delete template

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_DIR="$(get_template_dir)"

# Check if there are any templates
TEMPLATE_COUNT="$(ls "$TEMPLATE_DIR"/*.json 2>/dev/null | wc -l)"

if [[ "$TEMPLATE_COUNT" -eq 0 ]]; then
    display_message "  No templates to manage."
    exit 0
fi

# Open the manage picker in a popup
tmux display-popup -E -w 80% -h 70% -T "  Manage Templates" \
    "$CURRENT_DIR/_manage_picker.sh"
