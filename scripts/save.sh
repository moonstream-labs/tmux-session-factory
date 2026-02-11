#!/usr/bin/env bash

# save.sh — Prompt user for a template name, then snapshot the current session.
# This is a thin wrapper around command-prompt → _snapshot.sh.
# command-prompt runs asynchronously: it displays the prompt and returns
# immediately, executing the provided command only when the user presses Enter.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

tmux command-prompt -p "  Save session as template:" \
    "run-shell \"$CURRENT_DIR/_snapshot.sh '%%'\""
