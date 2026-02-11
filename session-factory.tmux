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

# Register key bindings
tmux bind-key n   run-shell "$CURRENT_DIR/scripts/new_session.sh"
tmux bind-key C-n run-shell "$CURRENT_DIR/scripts/new_session.sh --template-only"
tmux bind-key S   run-shell "$CURRENT_DIR/scripts/save.sh"
tmux bind-key M   run-shell "$CURRENT_DIR/scripts/manage.sh"
