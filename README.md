# Tmux Session Factory

A minimal tmux plugin that provides a simple key binding to toggle the status bar on and off.

## Features

- Toggle the tmux status bar with a single key binding
- Works without requiring the tmux prefix key
- Customizable key binding
- Preserves status bar settings between toggles
- Compatible with other status bar customization plugins
- Defaults to Alt+s to avoid common keybinding conflicts

## Installation

### Using TPM (recommended)

1. Add this line to your `~/.tmux.conf`:
```bash
set -g @plugin 'moonstream-labs/tmux-status-signal'
```

2. Press `prefix` + <kbd>I</kbd> to fetch and install the plugin.

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/moonstream-labs/tmux-status-signal ~/.tmux/plugins/tmux-status-signal
```

2. Add this line to your `~/.tmux.conf`:
```bash
run-shell ~/.tmux/plugins/tmux-status-signal/tmux-status-signal.tmux
```

3. Reload tmux environment:
```bash
tmux source-file ~/.tmux.conf
```

## Configuration

By default, the status bar toggle is bound to <kbd>Ctrl</kbd> + <kbd>s</kbd>.

You can customize the key binding in your `~/.tmux.conf`:
```bash
set -g @toggle-status-key 'M-t'  # Changes binding to Alt+t
```

Common key binding prefixes:
- `M-` for Alt/Meta key
- `C-` for Control key

Note: When choosing a key binding, be mindful of potential conflicts with your shell or editor keybindings.

## Usage

1. Press <kbd>Alt</kbd> + <kbd>s</kbd> (or your custom key binding) to toggle the status bar
2. The status bar will toggle between visible and hidden states
3. No prefix key is required

## Compatibility

- Works with tmux version 2.1 and later
- Compatible with most tmux themes and status line customization plugins
- Designed to work alongside common terminal emulators and shell configurations

## License

MIT

## Author

[MoonStream Labs](https://github.com/moonstream-labs)