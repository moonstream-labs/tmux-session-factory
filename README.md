# Tmux Session Factory

A tmux plugin for creating sessions from YAML templates.

## Prerequisites

- [tmux](https://github.com/tmux/tmux)
- [fzf](https://github.com/junegunn/fzf)
- [yq](https://github.com/mikefarah/yq)

## Installation

### Using TPM

Add this line to your `~/.tmux.conf`:

```bash
set -g @plugin 'username/tmux-session-factory'
```

Press `prefix + I` to install the plugin.

### Manual Installation

```bash
git clone https://github.com/username/tmux-session-factory ~/.tmux/plugins/tmux-session-factory
```

Add this line to your `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-session-factory/session-factory.tmux
```

## Usage

1. Press `prefix + T` (default) to open the template selector
2. Use fzf to select a template
3. Enter a name for your new session
4. The session will be created with the configured windows

## Configuration

### Custom Key Binding

```bash
set -g @session-factory-key "F"
```

### Templates

Templates are stored in YAML format in the `templates` directory. Example:

```yaml
---
name: development
windows:
  - name: editor
  - name: server
  - name: tests
  - name: shell
```
