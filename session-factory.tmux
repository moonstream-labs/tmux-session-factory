#!/usr/bin/env bash

# tmux-session-factory — TPM entry point
# This file is executed by TPM on plugin load.
# It sources helpers, ensures the template directory exists,
# and registers all key bindings.
#
# NOTE: Do NOT use set -euo pipefail here. TPM expects
# the entry point to succeed even if individual commands
# have minor issues.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/helpers.sh"
source "$CURRENT_DIR/scripts/variables.sh"

# Ensure template directory exists
TEMPLATE_DIR="$(get_template_dir)"
mkdir -p "$TEMPLATE_DIR"

# Read configurable key bindings
KEY_NEW="$(get_tmux_option "$key_new_option" "$key_new_default")"
KEY_NEW_TEMPLATE="$(get_tmux_option "$key_new_template_option" "$key_new_template_default")"
KEY_SAVE="$(get_tmux_option "$key_save_option" "$key_save_default")"
KEY_MANAGE="$(get_tmux_option "$key_manage_option" "$key_manage_default")"

# Register key bindings
tmux bind-key "$KEY_NEW"          run-shell "$CURRENT_DIR/scripts/new_session.sh"
tmux bind-key "$KEY_NEW_TEMPLATE" run-shell "$CURRENT_DIR/scripts/new_session.sh --template-only"
tmux bind-key "$KEY_SAVE"         run-shell "$CURRENT_DIR/scripts/save.sh"
tmux bind-key "$KEY_MANAGE"       run-shell "$CURRENT_DIR/scripts/manage.sh"
