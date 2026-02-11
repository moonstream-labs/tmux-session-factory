#!/usr/bin/env bash

# _snapshot.sh — Core capture logic: snapshot the active session to a JSON template.
# Called by save.sh (via command-prompt) and _edit_save.sh.
#
# Usage: _snapshot.sh <template_name> [session_name] [output_file]
#
# If session_name is omitted, uses the current client's active session.
# If output_file is omitted, derives it from the sanitized template name.

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_NAME="${1:-}"
SESSION_NAME="${2:-}"
OUTPUT_FILE="${3:-}"

# Validate template name
if [[ -z "$TEMPLATE_NAME" ]]; then
    display_message "  Template name cannot be empty."
    exit 1
fi

# Default session name to the current client's active session
if [[ -z "$SESSION_NAME" ]]; then
    SESSION_NAME="$(tmux display-message -p '#{session_name}')"
fi

# Default output file to template dir + sanitized name
if [[ -z "$OUTPUT_FILE" ]]; then
    TEMPLATE_DIR="$(get_template_dir)"
    mkdir -p "$TEMPLATE_DIR"
    SAFE_NAME="$(sanitize_name "$TEMPLATE_NAME")"
    if [[ -z "$SAFE_NAME" ]]; then
        display_message "  Template name produced an empty filename."
        exit 1
    fi
    OUTPUT_FILE="$TEMPLATE_DIR/$SAFE_NAME.json"
fi

# Snapshot the session
snapshot_session "$SESSION_NAME" "$TEMPLATE_NAME" "$OUTPUT_FILE"

display_message "  Template saved: $TEMPLATE_NAME"
