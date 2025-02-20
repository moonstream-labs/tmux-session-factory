#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper functions
source "$CURRENT_DIR/scripts/helpers.sh"

# Define default key binding (can be changed in .tmux.conf)
default_key_binding="T"

tmux_option="@session-factory-key"
key_binding=$(get_tmux_option "$tmux_option" "$default_key_binding")

# Set up the key binding
tmux bind-key "$key_binding" run-shell "$CURRENT_DIR/scripts/create_session.sh"