# tmux-session-factory

Save, restore, and manage reusable session layout templates for tmux.

## What It Does

- **Save** a running session's window/pane layout as a named JSON template
- **Create** new sessions from saved templates — geometry, working directories, and TUI applications are all restored
- **Create** blank named sessions with a quick prompt
- **Browse** saved templates with a live preview pane, and delete unwanted ones
- **Edit** templates interactively — instantiate a template in a temporary session, rearrange it with normal tmux operations, then re-save

## What It Does NOT Do

This plugin is **not** a replacement for [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) or [sesh](https://github.com/joshmedeski/sesh). It solves a different problem.

| Tool | Purpose |
|------|---------|
| **tmux-resurrect** | Persists live session state for crash/reboot recovery. Saves everything once, restores it once. |
| **sesh** | Fast session switching via tmux + zoxide + fzf. Cannot snapshot pane geometry or replay layouts. |
| **session-factory** | Creates reusable layout templates. Snapshot a workspace once, stamp out new sessions from it repeatedly. |

All three are complementary. Use resurrect for crash recovery, sesh for navigation, and session-factory for workspace templating.

## Key Bindings

| Binding | Action |
|---------|--------|
| `prefix + n` | New session — choose a template or create a blank session |
| `prefix + C-n` | New session from template — skips the blank option |
| `prefix + S` | Save the current session as a named template |
| `prefix + M` | Manage templates — browse, preview, edit, or delete |

While in **edit mode** (editing a template interactively):

| Binding | Action |
|---------|--------|
| `prefix + S` | Save changes back to the template and exit edit mode |
| `prefix + Q` | Discard changes and exit edit mode |

## Requirements

| Dependency | Version | Purpose |
|------------|---------|---------|
| [tmux](https://github.com/tmux/tmux) | >= 3.2 | `display-popup` support |
| [jq](https://jqlang.github.io/jq/) | any | JSON template read/write |
| [fzf](https://github.com/junegunn/fzf) | any | Fuzzy picker in popup modals |
| [bash](https://www.gnu.org/software/bash/) | >= 4.0 | Plugin scripts |
| [TPM](https://github.com/tmux-plugins/tpm) | any | Plugin manager |

## Installation

### With TPM (recommended)

Add to your `tmux.conf`:

```tmux
set -g @plugin 'moonstream-labs/tmux-session-factory'
```

Then press `prefix + I` to install.

### Manual

Clone the repository:

```bash
git clone https://github.com/moonstream-labs/tmux-session-factory.git \
    ~/.local/share/tmux/plugins/tmux-session-factory
```

Add to your `tmux.conf`:

```tmux
run-shell ~/.local/share/tmux/plugins/tmux-session-factory/session-factory.tmux
```

Reload tmux:

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

## Configuration

All options are set via `tmux` options in your `tmux.conf`, before TPM is initialized.

### Template storage directory

Where template JSON files are saved. Defaults to `$XDG_DATA_HOME/tmux/session-templates` (typically `~/.local/share/tmux/session-templates`).

```tmux
set -g @session-factory-dir "$HOME/.local/share/tmux/session-templates"
```

### Process restore whitelist

A space-separated list of TUI application names that should be automatically restarted when applying a template. If a pane was running one of these commands at save time, the command will be re-launched in its captured working directory.

Commands **not** on this list — and shell processes like `zsh`, `bash`, or `fish` — result in a plain shell at the correct path.

```tmux
set -g @session-factory-restore-processes "btop yazi"
```

The default whitelist is `btop yazi`. To add more programs:

```tmux
set -g @session-factory-restore-processes "btop yazi nvim lazygit"
```

## Usage

### Saving a template

1. Arrange your session exactly how you want it — name the windows, split and size the panes, start any TUI applications.
2. Press `prefix + S`.
3. Type a template name at the prompt and press Enter.
4. The template is saved. A confirmation message appears in the status line.

The template captures every window's name, pane layout geometry, working directories, and running commands. If a template with the same name already exists, it is overwritten.

### Creating a session from a template

1. Press `prefix + n`.
2. A popup appears with an fzf picker listing all saved templates (with window/pane counts) and a "New blank session" option at the top.
3. Select a template. You'll be prompted for a session name (defaults to the template name).
4. A new session is created with the exact window/pane layout from the template. Whitelisted processes are restarted. The client switches to the new session.

Use `prefix + C-n` to skip the blank session option and go straight to the template list.

If a session with the entered name already exists, the client switches to it instead of creating a duplicate.

### Managing templates

1. Press `prefix + M`.
2. A popup appears listing all saved templates. A preview pane on the right shows details for the highlighted template: name, source session, creation date, window list, and pane details with paths and commands.
3. Use the following actions:
   - **Ctrl-D** — Delete the selected template (with confirmation).
   - **Ctrl-E** — Edit the selected template interactively.
   - **Enter** — Close the popup.

### Editing a template interactively

1. From the manage popup, highlight a template and press **Ctrl-E**.
2. The popup closes. A temporary session is created from the template's layout.
3. Rearrange the session however you like — add or remove panes, resize splits, rename windows, change directories.
4. When you're done:
   - Press `prefix + S` to save the modified layout back to the template.
   - Press `prefix + Q` to discard your changes.
5. The temporary session is killed and you're returned to your previous session.

Edit mode bindings are context-aware: pressing `prefix + S` in a non-edit session triggers the normal save-template prompt, not the edit-save handler.

## Template Format

Templates are stored as JSON files. Here's an example:

```json
{
  "name": "fullstack-dev",
  "created": "2026-02-10T14:30:00-05:00",
  "source_session": "myproject",
  "windows": [
    {
      "index": 1,
      "name": "editor",
      "layout": "d235,209x50,0,0{139x50,0,0,0,69x50,140,0,1}",
      "active": true,
      "panes": [
        {
          "index": 0,
          "path": "/home/user/projects/myapp",
          "command": "zsh",
          "active": true
        },
        {
          "index": 1,
          "path": "/home/user/projects/myapp",
          "command": "zsh",
          "active": false
        }
      ]
    },
    {
      "index": 2,
      "name": "monitor",
      "layout": "a1b2,209x50,0,0{104x50,0,0,2,104x50,105,0,3}",
      "active": false,
      "panes": [
        {
          "index": 0,
          "path": "/home/user/projects/myapp",
          "command": "btop",
          "active": true
        },
        {
          "index": 1,
          "path": "/home/user/projects/myapp/logs",
          "command": "yazi",
          "active": false
        }
      ]
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `name` | Display name of the template (as entered by the user) |
| `created` | ISO 8601 timestamp |
| `source_session` | Name of the session this was captured from |
| `windows[].layout` | tmux layout string — encodes exact pane split positions, sizes, and orientations |
| `windows[].active` | Whether this was the active window |
| `panes[].path` | Absolute working directory of the pane |
| `panes[].command` | Process running in the pane (e.g. `zsh`, `btop`, `yazi`) |
| `panes[].active` | Whether this was the active pane in its window |

The `layout` string is the key to exact geometry restoration. It's tmux's internal representation of pane geometry (`#{window_layout}`), and applying it recreates the precise split arrangement without needing to replay individual split commands.

Template filenames are sanitized versions of the display name (alphanumeric, hyphens, underscores) with a `.json` extension. The original name is preserved in the `name` field.

## How It Works

**Saving** captures tmux format strings (`#{window_layout}`, `#{pane_current_path}`, `#{pane_current_command}`, etc.) for every window and pane in the session, then assembles them into structured JSON via `jq`.

**Applying** creates the session and windows, splits the correct number of panes per window, then applies the saved layout string to each window. The layout string overrides all geometry — so we don't need to figure out whether the original splits were horizontal or vertical. After layout, each pane gets a `cd` to its saved path, and whitelisted commands are sent via `send-keys`.

**Editing** instantiates a template as a temporary `_factory_edit__*` session with overridden key bindings. A guard in the save/discard handlers checks the session name prefix before acting, so the overrides don't interfere with normal sessions. After save or discard, the temp session is killed, bindings are restored, and the client returns to the previous session.

## Related Plugins

| Plugin | Relationship |
|--------|-------------|
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | Crash/reboot recovery. Saves live state. Complementary — use both. |
| [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | Auto-saves resurrect state on an interval. No interaction with session-factory. |
| [sesh](https://github.com/joshmedeski/sesh) | Session switcher (tmux + zoxide + fzf). Cannot snapshot layouts. Complementary. |
| [tmux-pain-control](https://github.com/tmux-plugins/tmux-pain-control) | Pane splits and navigation. No binding conflicts. |

## License

[MIT](LICENSE)
