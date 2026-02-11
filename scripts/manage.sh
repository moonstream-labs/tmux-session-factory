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

# Read popup styling and dimension options
POPUP_STYLE="$(get_tmux_option "$popup_style_option" "$popup_style_default")"
POPUP_BORDER_STYLE="$(get_tmux_option "$popup_border_style_option" "$popup_border_style_default")"
POPUP_BORDER_LINES="$(get_tmux_option "$popup_border_lines_option" "$popup_border_lines_default")"
POPUP_WIDTH="$(get_tmux_option "$popup_width_option" "$popup_width_manage_default")"
POPUP_HEIGHT="$(get_tmux_option "$popup_height_option" "$popup_height_manage_default")"

# Open the manage picker in a popup
tmux display-popup -E -w "$POPUP_WIDTH" -h "$POPUP_HEIGHT" \
    -s "$POPUP_STYLE" -S "$POPUP_BORDER_STYLE" -b "$POPUP_BORDER_LINES" \
    -T " Manage Templates " \
    "$CURRENT_DIR/_manage_picker.sh"
