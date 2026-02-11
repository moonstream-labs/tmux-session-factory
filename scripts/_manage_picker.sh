#!/usr/bin/env bash

# _manage_picker.sh — Internal: fzf picker for template management.
# Called from manage.sh inside a tmux display-popup.
#
# Actions via --expect:
#   Enter   — close (preview is shown during browsing)
#   ctrl-e  — edit template interactively
#   ctrl-d  — delete template

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_DIR="$(get_template_dir)"

FZF_COLOR_SCHEME="$(get_tmux_option "$fzf_colors_option" "$fzf_colors_default")"
FZF_COLORS="--color=$FZF_COLOR_SCHEME"

# ── Build fzf input ──
# Format: <filename>\t<display_text>

INPUT=""

for file in "$TEMPLATE_DIR"/*.json; do
    [[ -f "$file" ]] || continue

    FILENAME="$(basename "$file" .json)"
    NAME="$(jq -r '.name // empty' "$file" 2>/dev/null)" || continue
    [[ -z "$NAME" ]] && continue

    WIN_COUNT="$(jq '.windows | length' "$file" 2>/dev/null)" || continue
    PANE_COUNT="$(jq '[.windows[].panes | length] | add // 0' "$file" 2>/dev/null)" || continue
    CREATED="$(jq -r '.created // "" | split("T")[0]' "$file" 2>/dev/null)" || CREATED=""

    INPUT+="${FILENAME}	  ${NAME}  ${WIN_COUNT}w ${PANE_COUNT}p  ${CREATED}"$'\n'
done

INPUT="${INPUT%$'\n'}"

if [[ -z "$INPUT" ]]; then
    echo "  No templates found."
    sleep 1
    exit 0
fi

# ── Build preview command ──
# The preview receives the selected line; we extract the filename from field 1.

PREVIEW_CMD='
    FILE="'"$TEMPLATE_DIR"'/"$(echo {} | cut -f1)".json"
    if [[ ! -f "$FILE" ]]; then
        echo "  File not found."
        exit 0
    fi
    echo ""
    jq -r "\"  Template: \(.name)\"" "$FILE"
    jq -r "\"  Source:   \(.source_session)\"" "$FILE"
    jq -r "\"  Created:  \(.created | split(\"T\")[0])\"" "$FILE"
    echo ""
    echo "  Windows:"
    jq -r ".windows[] | \"    \(.index). \(.name)  (\(.panes | length) panes)\"" "$FILE"
    echo ""
    echo "  Pane detail:"
    jq -r ".windows[] | . as \$w | .panes[] | \"    \(\$w.name):\(.index) -> \(.path | split(\"/\") | .[-2:] | join(\"/\"))  [\(.command)]\"" "$FILE"
'

# ── Run fzf ──

RESULT="$(echo "$INPUT" | fzf \
    --ansi \
    --no-multi \
    --delimiter=$'\t' \
    --with-nth=2 \
    --header="  Enter: close  |  Ctrl-E: edit  |  Ctrl-D: delete" \
    --no-info \
    --reverse \
    --margin=1,2 \
    --expect="ctrl-d,ctrl-e" \
    --preview="$PREVIEW_CMD" \
    --preview-window="right:50%:wrap" \
    $FZF_COLORS \
)" || exit 0

# ── Parse result ──
# With --expect, fzf outputs:
#   Line 1: the key pressed (empty string for Enter)
#   Line 2: the selected entry

ACTION="$(echo "$RESULT" | head -1)"
SELECTED="$(echo "$RESULT" | tail -1)"
SELECTED_KEY="$(echo "$SELECTED" | cut -f1)"
TEMPLATE_FILE="$TEMPLATE_DIR/${SELECTED_KEY}.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "  Template file not found."
    sleep 1
    exit 1
fi

TEMPLATE_DISPLAY_NAME="$(jq -r '.name' "$TEMPLATE_FILE")"

case "$ACTION" in
    "ctrl-d")
        # ── Delete template ──
        echo ""
        printf "  Delete template '%s'? [y/N]: " "$TEMPLATE_DISPLAY_NAME"
        read -r CONFIRM

        case "$CONFIRM" in
            [yY]|[yY][eE][sS])
                rm -f "$TEMPLATE_FILE"
                echo "  Deleted: $TEMPLATE_DISPLAY_NAME"
                sleep 1
                ;;
            *)
                echo "  Cancelled."
                sleep 1
                ;;
        esac
        ;;
    "ctrl-e")
        # ── Edit template interactively ──
        # Close popup first (it closes when this script exits),
        # then launch edit.sh via tmux run-shell so it runs outside the popup.
        tmux run-shell "$CURRENT_DIR/edit.sh '$TEMPLATE_FILE'"
        ;;
    *)
        # Enter — just close the popup (preview was visible during browsing)
        exit 0
        ;;
esac
