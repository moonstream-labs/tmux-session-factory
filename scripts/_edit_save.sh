#!/usr/bin/env bash

# _edit_save.sh — Re-snapshot the temporary edit session back to the original template.
# Called when user presses prefix+S during edit mode.
#
# If the current session is NOT a _factory_edit__* session, falls through
# to normal save.sh behavior (since bindings are global).

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

SESSION_NAME="$(tmux display-message -p '#{session_name}')"

# ── Guard: only act if we're in an edit session ──
if [[ "$SESSION_NAME" != _factory_edit__* ]]; then
    # Not in edit mode — fall through to normal save
    exec "$CURRENT_DIR/save.sh"
fi

# ── Read edit state from environment ──
TEMPLATE_FILE="$(tmux show-environment -g _factory_edit_file 2>/dev/null | sed 's/^[^=]*=//')" || true
TEMPLATE_NAME="$(tmux show-environment -g _factory_edit_name 2>/dev/null | sed 's/^[^=]*=//')" || true
RETURN_SESSION="$(tmux show-environment -g _factory_edit_return 2>/dev/null | sed 's/^[^=]*=//')" || true

if [[ -z "$TEMPLATE_FILE" || -z "$TEMPLATE_NAME" ]]; then
    display_message "  Edit state not found. Aborting."
    exit 1
fi

# ── Re-snapshot the edit session ──
snapshot_session "$SESSION_NAME" "$TEMPLATE_NAME" "$TEMPLATE_FILE"

# ── Return to previous session ──
# Check if the return session still exists
if [[ -n "$RETURN_SESSION" ]] && session_exists "$RETURN_SESSION"; then
    tmux switch-client -t "=$RETURN_SESSION"
else
    # Find any non-edit session to switch to
    FALLBACK="$(tmux list-sessions -F '#{session_name}' | grep -v '^_factory_edit__' | head -1)"
    if [[ -n "$FALLBACK" ]]; then
        tmux switch-client -t "=$FALLBACK"
    else
        # No other sessions — create a default one
        tmux new-session -d -s "default"
        tmux switch-client -t "default"
    fi
fi

# ── Kill the temporary edit session ──
tmux kill-session -t "=$SESSION_NAME" 2>/dev/null || true

# ── Restore original key bindings ──
KEY_SAVE="$(get_tmux_option "$key_save_option" "$key_save_default")"
tmux bind-key "$KEY_SAVE" run-shell "$CURRENT_DIR/save.sh"
tmux unbind-key Q 2>/dev/null || true

# ── Clean up environment variables ──
tmux set-environment -gu _factory_edit_file 2>/dev/null || true
tmux set-environment -gu _factory_edit_name 2>/dev/null || true
tmux set-environment -gu _factory_edit_return 2>/dev/null || true

display_message "  Template updated: $TEMPLATE_NAME"
