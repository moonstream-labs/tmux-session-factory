#!/usr/bin/env bash

# apply.sh — Create a new tmux session from a saved JSON template.
# Called by new_session.sh and edit.sh. Not bound to a key directly.
#
# Usage: apply.sh <template_file_path> <session_name> [--no-switch]
#
# --no-switch: Create the session but don't switch the client to it.
#              Used by edit.sh which handles switching itself.

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_PATH="${1:-}"
SESSION_NAME="${2:-}"
NO_SWITCH=0

# Parse optional flags
for arg in "$@"; do
    case "$arg" in
        --no-switch) NO_SWITCH=1 ;;
    esac
done

# Validate arguments
if [[ -z "$TEMPLATE_PATH" || -z "$SESSION_NAME" ]]; then
    display_message "  Usage: apply.sh <template_file> <session_name>"
    exit 1
fi

if [[ ! -f "$TEMPLATE_PATH" ]]; then
    display_message "  Template file not found: $TEMPLATE_PATH"
    exit 1
fi

# Validate JSON
if ! jq empty "$TEMPLATE_PATH" 2>/dev/null; then
    display_message "  Template file is not valid JSON."
    exit 1
fi

# Read the restore processes whitelist
RESTORE_PROCESSES="$(get_tmux_option "$restore_processes_option" "$restore_processes_default")"

# Get total window count
WIN_COUNT="$(jq '.windows | length' "$TEMPLATE_PATH")"

if [[ "$WIN_COUNT" -eq 0 ]]; then
    # Template has no windows — create a blank session
    tmux new-session -d -s "$SESSION_NAME"
    if [[ "$NO_SWITCH" -eq 0 ]]; then
        tmux switch-client -t "$SESSION_NAME"
    fi
    exit 0
fi

# Read base-index and pane-base-index once
BASE_INDEX="$(tmux show-option -gqv base-index)"
BASE_INDEX="${BASE_INDEX:-0}"
PANE_BASE="$(tmux show-option -gqv pane-base-index)"
PANE_BASE="${PANE_BASE:-0}"

# ── Create the session with the first window ──

FIRST_WIN_NAME="$(jq -r '.windows[0].name' "$TEMPLATE_PATH")"
FIRST_WIN_LAYOUT="$(jq -r '.windows[0].layout' "$TEMPLATE_PATH")"
FIRST_PANE_PATH="$(jq -r '.windows[0].panes[0].path' "$TEMPLATE_PATH")"
FIRST_PANE_COUNT="$(jq '.windows[0].panes | length' "$TEMPLATE_PATH")"

# Fall back to $HOME if the directory doesn't exist
if [[ ! -d "$FIRST_PANE_PATH" ]]; then
    FIRST_PANE_PATH="$HOME"
fi

# Create session with first window — this window gets index = BASE_INDEX
# tput may fail when run from tmux run-shell (no tty), so provide fallbacks
COLS="$(tput cols 2>/dev/null || echo 200)"
ROWS="$(tput lines 2>/dev/null || echo 50)"
tmux new-session -d -s "$SESSION_NAME" -n "$FIRST_WIN_NAME" -c "$FIRST_PANE_PATH" -x "$COLS" -y "$ROWS"

FIRST_WIN_IDX="$BASE_INDEX"

# Create additional panes for the first window (use index-based targeting)
for (( p = 1; p < FIRST_PANE_COUNT; p++ )); do
    PANE_PATH="$(jq -r ".windows[0].panes[$p].path" "$TEMPLATE_PATH")"
    if [[ ! -d "$PANE_PATH" ]]; then
        PANE_PATH="$HOME"
    fi
    tmux split-window -t "${SESSION_NAME}:${FIRST_WIN_IDX}" -c "$PANE_PATH"
done

# Apply layout to first window
if [[ -n "$FIRST_WIN_LAYOUT" && "$FIRST_WIN_LAYOUT" != "null" ]]; then
    tmux select-layout -t "${SESSION_NAME}:${FIRST_WIN_IDX}" "$FIRST_WIN_LAYOUT" 2>/dev/null || true
fi

# ── Create subsequent windows ──

for (( w = 1; w < WIN_COUNT; w++ )); do
    WIN_NAME="$(jq -r ".windows[$w].name" "$TEMPLATE_PATH")"
    WIN_LAYOUT="$(jq -r ".windows[$w].layout" "$TEMPLATE_PATH")"
    PANE_COUNT="$(jq ".windows[$w].panes | length" "$TEMPLATE_PATH")"
    WIN_FIRST_PANE_PATH="$(jq -r ".windows[$w].panes[0].path" "$TEMPLATE_PATH")"

    if [[ ! -d "$WIN_FIRST_PANE_PATH" ]]; then
        WIN_FIRST_PANE_PATH="$HOME"
    fi

    # Create new window — tmux assigns the next available index
    tmux new-window -t "$SESSION_NAME" -n "$WIN_NAME" -c "$WIN_FIRST_PANE_PATH"

    # The new window gets index BASE_INDEX + w (since we create them in order
    # and renumber-windows is on)
    WIN_IDX="$(( BASE_INDEX + w ))"

    # Create additional panes (use index-based targeting)
    for (( p = 1; p < PANE_COUNT; p++ )); do
        PANE_PATH="$(jq -r ".windows[$w].panes[$p].path" "$TEMPLATE_PATH")"
        if [[ ! -d "$PANE_PATH" ]]; then
            PANE_PATH="$HOME"
        fi
        tmux split-window -t "${SESSION_NAME}:${WIN_IDX}" -c "$PANE_PATH"
    done

    # Apply layout
    if [[ -n "$WIN_LAYOUT" && "$WIN_LAYOUT" != "null" ]]; then
        tmux select-layout -t "${SESSION_NAME}:${WIN_IDX}" "$WIN_LAYOUT" 2>/dev/null || true
    fi
done

# ── Set working directories and restore processes ──

for (( w = 0; w < WIN_COUNT; w++ )); do
    PANE_COUNT="$(jq ".windows[$w].panes | length" "$TEMPLATE_PATH")"
    WIN_IDX="$(( BASE_INDEX + w ))"

    for (( p = 0; p < PANE_COUNT; p++ )); do
        PANE_PATH="$(jq -r ".windows[$w].panes[$p].path" "$TEMPLATE_PATH")"
        PANE_CMD="$(jq -r ".windows[$w].panes[$p].command" "$TEMPLATE_PATH")"
        PANE_ACTIVE="$(jq -r ".windows[$w].panes[$p].active" "$TEMPLATE_PATH")"

        if [[ ! -d "$PANE_PATH" ]]; then
            PANE_PATH="$HOME"
        fi

        ACTUAL_PANE_INDEX="$(( PANE_BASE + p ))"
        PANE_TARGET="${SESSION_NAME}:${WIN_IDX}.${ACTUAL_PANE_INDEX}"

        # Set working directory and clear
        tmux send-keys -t "$PANE_TARGET" "cd $(printf '%q' "$PANE_PATH") && clear" Enter

        # Check if command should be restored
        case "$PANE_CMD" in
            bash|zsh|fish|sh|dash)
                # Shell — already in the right directory, nothing more to do
                ;;
            *)
                # Check if command is on the restore whitelist
                if echo " $RESTORE_PROCESSES " | grep -qF " $PANE_CMD "; then
                    tmux send-keys -t "$PANE_TARGET" "$PANE_CMD" Enter
                fi
                # Not on whitelist — treat as shell pane (no action)
                ;;
        esac

        # Select the active pane
        if [[ "$PANE_ACTIVE" == "true" ]]; then
            tmux select-pane -t "$PANE_TARGET"
        fi
    done

    # Select the active window
    WIN_ACTIVE="$(jq -r ".windows[$w].active" "$TEMPLATE_PATH")"
    if [[ "$WIN_ACTIVE" == "true" ]]; then
        tmux select-window -t "${SESSION_NAME}:${WIN_IDX}"
    fi
done

# ── Switch client to the new session ──

if [[ "$NO_SWITCH" -eq 0 ]]; then
    tmux switch-client -t "$SESSION_NAME"
fi
