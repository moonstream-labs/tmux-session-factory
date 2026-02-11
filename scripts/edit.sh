#!/usr/bin/env bash

# edit.sh — Interactive template editing.
# Instantiates a template as a temporary session, lets the user rearrange it
# using normal tmux operations, then re-saves or discards.
#
# Trigger: Ctrl-E from manage picker, or directly: edit.sh <template_file_path>
#
# While in edit mode:
#   prefix + S → re-snapshot and save (handled by _edit_save.sh)
#   prefix + Q → discard changes (handled by _edit_discard.sh)

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_FILE="${1:-}"

# Validate
if [[ -z "$TEMPLATE_FILE" || ! -f "$TEMPLATE_FILE" ]]; then
    display_message "  Template file not found."
    exit 1
fi

if ! jq empty "$TEMPLATE_FILE" 2>/dev/null; then
    display_message "  Template file is not valid JSON."
    exit 1
fi

# ── Guard: only one edit at a time ──
EXISTING_EDIT="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^_factory_edit__' | head -1)" || true
if [[ -n "$EXISTING_EDIT" ]]; then
    EXISTING_NAME="$(tmux show-environment -g _factory_edit_name 2>/dev/null | sed 's/^[^=]*=//')" || true
    if [[ -z "$EXISTING_NAME" ]]; then
        EXISTING_NAME="${EXISTING_EDIT#_factory_edit__}"
    fi
    display_message "  Already editing: $EXISTING_NAME. Save or discard first."
    exit 0
fi

# Read template name
TEMPLATE_NAME="$(jq -r '.name' "$TEMPLATE_FILE")"

# Generate temporary session name (use __ as separator; colon is a tmux target delimiter)
SAFE_EDIT_NAME="$(sanitize_name "$TEMPLATE_NAME")"
EDIT_SESSION="_factory_edit__${SAFE_EDIT_NAME}"

# If a stale edit session with this exact name exists (e.g., from a crash), kill it
if session_exists "$EDIT_SESSION"; then
    tmux kill-session -t "=$EDIT_SESSION" 2>/dev/null || true
fi

# Record the current session (to return to after edit)
RETURN_SESSION="$(tmux display-message -p '#{session_name}')"

# Store state in tmux environment variables for _edit_save.sh and _edit_discard.sh
tmux set-environment -g _factory_edit_file "$TEMPLATE_FILE"
tmux set-environment -g _factory_edit_name "$TEMPLATE_NAME"
tmux set-environment -g _factory_edit_return "$RETURN_SESSION"

# Instantiate the template as a temporary session
# Use --no-switch because we'll switch manually after setting up bindings
"$CURRENT_DIR/apply.sh" "$TEMPLATE_FILE" "$EDIT_SESSION" --no-switch

# Override key bindings for edit mode
# These are global (tmux doesn't support per-session bindings),
# so _edit_save.sh and _edit_discard.sh check the session name
# before proceeding.
KEY_SAVE="$(get_tmux_option "$key_save_option" "$key_save_default")"
tmux bind-key "$KEY_SAVE" run-shell "$CURRENT_DIR/_edit_save.sh"
tmux bind-key Q run-shell "$CURRENT_DIR/_edit_discard.sh"

# Switch to the edit session
tmux switch-client -t "=$EDIT_SESSION"

# Display instructions
display_message "  Editing: $TEMPLATE_NAME  —  prefix+$KEY_SAVE to save, prefix+Q to discard"
