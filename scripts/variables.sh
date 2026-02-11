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

# ── Keybindings ──
# Users can override the default key for each action via tmux options.
# Values should be valid tmux key names (e.g., "n", "C-n", "S", "M", "F5").
key_new_option="@session-factory-key-new"
key_new_default="n"

key_new_template_option="@session-factory-key-new-template"
key_new_template_default="C-n"

key_save_option="@session-factory-key-save"
key_save_default="S"

key_manage_option="@session-factory-key-manage"
key_manage_default="M"

# ── Popup dimensions ──
# Separate defaults for new-session and manage popups.
# A single override option applies to both; per-popup overrides are not exposed
# to keep configuration simple.
popup_width_option="@session-factory-popup-width"
popup_height_option="@session-factory-popup-height"
popup_width_new_default="60%"
popup_height_new_default="50%"
popup_width_manage_default="80%"
popup_height_manage_default="70%"

# ── Additional fzf options ──
# Appended to the fzf invocation in both pickers.
# Example: set -g @session-factory-fzf-opts "--exact --no-sort"
fzf_opts_option="@session-factory-fzf-opts"
fzf_opts_default=""
