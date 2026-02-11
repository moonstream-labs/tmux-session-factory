#!/usr/bin/env bash

# _new_session_picker.sh — Internal: fzf picker for new session creation.
# Called from new_session.sh inside a tmux display-popup.
#
# Usage: _new_session_picker.sh [0|1]
#   0 = show blank + templates (default)
#   1 = templates only

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_ONLY="${1:-0}"
TEMPLATE_DIR="$(get_template_dir)"

FZF_COLOR_SCHEME="$(get_tmux_option "$fzf_colors_option" "$fzf_colors_default")"
FZF_COLORS="--color=$FZF_COLOR_SCHEME"

# ── Build fzf input ──
# Format: <hidden_key>\t<display_text>
# hidden_key is either "__blank__" or the template filename (without .json)

INPUT=""

if [[ "$TEMPLATE_ONLY" -eq 0 ]]; then
    INPUT="__blank__	  New blank session"$'\n'
fi

# Add templates
for file in "$TEMPLATE_DIR"/*.json; do
    [[ -f "$file" ]] || continue

    FILENAME="$(basename "$file" .json)"
    NAME="$(jq -r '.name // empty' "$file" 2>/dev/null)" || continue
    [[ -z "$NAME" ]] && continue

    WIN_COUNT="$(jq '.windows | length' "$file" 2>/dev/null)" || continue
    PANE_COUNT="$(jq '[.windows[].panes | length] | add // 0' "$file" 2>/dev/null)" || continue

    INPUT+="${FILENAME}	  ${NAME}  ${WIN_COUNT}w ${PANE_COUNT}p"$'\n'
done

# Remove trailing newline
INPUT="${INPUT%$'\n'}"

if [[ -z "$INPUT" ]]; then
    echo "No templates found."
    sleep 1
    exit 0
fi

# ── Run fzf ──

SELECTION="$(echo "$INPUT" | fzf \
    --ansi \
    --no-multi \
    --delimiter=$'\t' \
    --with-nth=2 \
    --header="  Select a template or create a blank session" \
    --no-info \
    --reverse \
    --margin=1,2 \
    $FZF_COLORS \
)" || exit 0

# Parse selection
SELECTED_KEY="$(echo "$SELECTION" | cut -f1)"

if [[ "$SELECTED_KEY" == "__blank__" ]]; then
    # ── Blank session ──
    echo ""
    printf "  Session name: "
    read -r SESSION_NAME

    if [[ -z "$SESSION_NAME" ]]; then
        echo "  Cancelled."
        sleep 1
        exit 0
    fi

    if session_exists "$SESSION_NAME"; then
        tmux switch-client -t "=$SESSION_NAME"
        exit 0
    fi

    tmux new-session -d -s "$SESSION_NAME"
    tmux switch-client -t "$SESSION_NAME"
else
    # ── Template session ──
    TEMPLATE_FILE="$TEMPLATE_DIR/${SELECTED_KEY}.json"

    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "  Template file not found."
        sleep 1
        exit 1
    fi

    TEMPLATE_DISPLAY_NAME="$(jq -r '.name' "$TEMPLATE_FILE")"

    echo ""
    printf "  Session name [%s]: " "$TEMPLATE_DISPLAY_NAME"
    read -r SESSION_NAME

    # Default to template name if empty
    if [[ -z "$SESSION_NAME" ]]; then
        SESSION_NAME="$TEMPLATE_DISPLAY_NAME"
    fi

    if session_exists "$SESSION_NAME"; then
        tmux switch-client -t "=$SESSION_NAME"
        exit 0
    fi

    # Apply the template
    "$CURRENT_DIR/apply.sh" "$TEMPLATE_FILE" "$SESSION_NAME"
fi
