#!/usr/bin/env bash

# ── Template storage directory ──
template_dir_option="@session-factory-dir"
template_dir_default="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/session-templates"

# ── Process restore whitelist ──
# Space-separated list of TUI application names that should be
# automatically restarted when applying a template.
# If a pane was running one of these commands at save time, the
# command will be re-launched in the corresponding directory.
# Commands not on this list (and shell processes like zsh/bash/fish)
# result in a plain shell in the captured working directory.
restore_processes_option="@session-factory-restore-processes"
restore_processes_default="btop yazi"

# ── Future v2 options (not yet implemented) ──
# @session-factory-key-new           # Override prefix + n
# @session-factory-key-new-template  # Override prefix + C-n
# @session-factory-key-save          # Override prefix + S
# @session-factory-key-manage        # Override prefix + M
# @session-factory-popup-width       # Override popup width
# @session-factory-popup-height      # Override popup height
# @session-factory-fzf-opts          # Additional fzf flags
