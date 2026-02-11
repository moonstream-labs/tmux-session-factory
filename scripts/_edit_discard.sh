#!/usr/bin/env bash

# _edit_discard.sh — Discard edit changes and clean up.
# Called when user presses prefix+Q during edit mode.
#
# If the current session is NOT a _factory_edit__* session, does nothing
# (Q is not a standard tmux binding, so there's no fallback).

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

SESSION_NAME="$(tmux display-message -p '#{session_name}')"

# ── Guard: only act if we're in an edit session ──
if [[ "$SESSION_NAME" != _factory_edit__* ]]; then
    display_message "  Not in edit mode."
    exit 0
fi

# ── Read edit state from environment ──
TEMPLATE_NAME="$(tmux show-environment -g _factory_edit_name 2>/dev/null | sed 's/^[^=]*=//')" || true
RETURN_SESSION="$(tmux show-environment -g _factory_edit_return 2>/dev/null | sed 's/^[^=]*=//')" || true

# ── Return to previous session ──
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
tmux bind-key S run-shell "$CURRENT_DIR/save.sh"
tmux unbind-key Q 2>/dev/null || true

# ── Clean up environment variables ──
tmux set-environment -gu _factory_edit_file 2>/dev/null || true
tmux set-environment -gu _factory_edit_name 2>/dev/null || true
tmux set-environment -gu _factory_edit_return 2>/dev/null || true

display_message "  Edit discarded."
