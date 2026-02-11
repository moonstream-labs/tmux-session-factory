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
restore_processes_default="btop yazi lazygit"

# ── Popup styling ──
# Monochrome defaults matching a dark terminal (bg #080909, fg #dadada).
# Users can override via the corresponding @session-factory-* tmux options.
popup_style_option="@session-factory-popup-style"
popup_style_default="bg=#080909,fg=#dadada"

popup_border_style_option="@session-factory-popup-border-style"
popup_border_style_default="fg=#dadada"

popup_border_lines_option="@session-factory-popup-border-lines"
popup_border_lines_default="rounded"

# ── fzf colors ──
# Monochrome palette: white pointer on active, transparent gutter on inactive,
# muted gray prompt/header, bold differentiation on selected item.
fzf_colors_option="@session-factory-fzf-colors"
fzf_colors_default="bg:#080909,fg:#dadada,bg+:#080909,fg+:#dadada:bold,hl:#dadada:underline,hl+:#ffffff:bold:underline,pointer:#dadada,prompt:#808080,header:#595959,gutter:#080909,marker:#dadada,info:#595959,border:#dadada,preview-bg:#080909,preview-fg:#dadada"

# ── Future v2 options (not yet implemented) ──
# @session-factory-key-new           # Override prefix + n
# @session-factory-key-new-template  # Override prefix + C-n
# @session-factory-key-save          # Override prefix + S
# @session-factory-key-manage        # Override prefix + M
# @session-factory-popup-width       # Override popup width
# @session-factory-popup-height      # Override popup height
# @session-factory-fzf-opts          # Additional fzf flags
