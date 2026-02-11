#!/usr/bin/env bash

# new_session.sh — fzf picker: create a new blank session or from a template.
# Trigger: prefix + n (all options) or prefix + C-n (--template-only)
#
# This script opens a tmux display-popup containing an fzf picker.
# It delegates the picker logic to _new_session_picker.sh to avoid
# quoting issues with inline scripts.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --template-only) TEMPLATE_ONLY=1 ;;
    esac
done

TEMPLATE_DIR="$(get_template_dir)"

# Check if there are any templates
TEMPLATE_COUNT="$(ls "$TEMPLATE_DIR"/*.json 2>/dev/null | wc -l)"

if [[ "$TEMPLATE_ONLY" -eq 1 && "$TEMPLATE_COUNT" -eq 0 ]]; then
    display_message "  No templates found."
    exit 0
fi

# Read popup styling and dimension options
POPUP_STYLE="$(get_tmux_option "$popup_style_option" "$popup_style_default")"
POPUP_BORDER_STYLE="$(get_tmux_option "$popup_border_style_option" "$popup_border_style_default")"
POPUP_BORDER_LINES="$(get_tmux_option "$popup_border_lines_option" "$popup_border_lines_default")"
POPUP_WIDTH="$(get_tmux_option "$popup_width_option" "$popup_width_new_default")"
POPUP_HEIGHT="$(get_tmux_option "$popup_height_option" "$popup_height_new_default")"

# Open the picker in a popup
tmux display-popup -E -w "$POPUP_WIDTH" -h "$POPUP_HEIGHT" \
    -s "$POPUP_STYLE" -S "$POPUP_BORDER_STYLE" -b "$POPUP_BORDER_LINES" \
    -T " New Session " \
    "$CURRENT_DIR/_new_session_picker.sh $TEMPLATE_ONLY"
