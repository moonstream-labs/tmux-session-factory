# tmux-session-factory — Reference Implementation Document

## 1. Overview

`tmux-session-factory` is a TPM-compatible tmux plugin that provides session templating: the ability to snapshot a running session's window/pane layout, save it as a named template, and stamp out new sessions from saved templates. It also provides interactive template editing, template browsing with preview, and template deletion.

### 1.1 What This Plugin Does

- **Save** a running tmux session's layout (windows, panes, geometry, working directories, running TUI applications) as a named JSON template.
- **Create** a new tmux session from a saved template, prompting for a session name.
- **Create** a new blank tmux session with a name prompt.
- **Browse** saved templates with preview, and delete unwanted ones.
- **Edit** a saved template interactively by instantiating it in a temporary session, allowing the user to rearrange it using normal tmux operations, then re-saving.

### 1.2 What This Plugin Does NOT Do

- It does not replace `tmux-resurrect`. Resurrect persists live state for crash/reboot recovery. This plugin creates reusable layout templates for stamping out new sessions on demand.
- It does not replace `sesh`. Sesh is a session switcher integrating tmux + zoxide + fzf. Sesh cannot snapshot pane geometry. The two are complementary.
- It does not manage session switching, navigation, or lifecycle beyond creation.

### 1.3 Why Not sesh?

`sesh` (github.com/joshmedeski/sesh) is a "smart session manager" that integrates tmux, zoxide, and fzf for fast session navigation and connection. Its TOML configuration supports named sessions with startup commands and multiple windows, but it **cannot**:

- Capture a live session's pane split geometry (tmux layout strings like `d235,209x50,0,0{139x50,0,0,0,69x50,140,0,1}`)
- Snapshot which pane was active, or what TUI applications were running
- Replay an arbitrary pane arrangement from a saved state

`sesh` solves "how do I switch between sessions quickly." `tmux-session-factory` solves "how do I define a reusable workspace layout and instantiate it repeatedly."

---

## 2. Dependencies

| Dependency | Purpose | Install (Arch) |
|------------|---------|----------------|
| `tmux` ≥ 3.2 | `display-popup` support | `pacman -S tmux` |
| `jq` | JSON template read/write | `pacman -S jq` |
| `fzf` | Fuzzy picker in popup modals | `pacman -S fzf` |
| `bash` ≥ 4.0 | Plugin scripts | (pre-installed) |
| TPM | Plugin manager | github.com/tmux-plugins/tpm |

---

## 3. Environment Context

This plugin is being developed for and initially deployed in the following environment. The reference document includes the full keybinding chain for this environment, but the plugin itself must remain environment-agnostic — it only registers tmux key bindings and has no knowledge of keyd or Ghostty.

### 3.1 Keybinding Chain

Physical keyboard input passes through three layers before reaching tmux:

```
Physical Key → keyd (kernel-level remap) → Ghostty (terminal keybinds) → tmux (prefix sequences)
```

**keyd remapping summary** (from `/etc/keyd/default.conf`):
- Physical `Super` (Meta) → sends `Ctrl` (`layer(control)`)
- Physical `Ctrl` → sends `Super` (`leftmeta`)
- Physical `Alt` → sends `Alt` (`layer(alt)`)
- Physical `CapsLock` → `Esc` (tap) / `Hyper` layer (hold)

**tmux prefix:** `C-a` (hex `\x01`), mapped to physical `Super+A` → keyd → `Ctrl+A`.

### 3.2 Plugin Keybindings — Full Chain

The plugin registers four tmux bindings. Reaching them from the physical keyboard requires corresponding Ghostty keybinding entries that send the appropriate prefix + key escape sequences.

#### Binding 1: New Session (blank or template)

| Layer | Value |
|-------|-------|
| Physical keys | `Super+N` |
| keyd output | `Ctrl+N` |
| Ghostty logical key | `control+n` |
| Ghostty sends | `\x01n` (prefix, then `n`) |
| tmux binding | `bind-key n` → `scripts/new_session.sh` |

#### Binding 2: New Session from Template (skip blank option)

| Layer | Value |
|-------|-------|
| Physical keys | `Super+Shift+N` |
| keyd output | `Ctrl+Shift+N` |
| Ghostty logical key | `shift+control+n` |
| Ghostty sends | `\x01\x0e` (prefix, then `C-n`) |
| tmux binding | `bind-key C-n` → `scripts/new_session.sh --template-only` |

#### Binding 3: Save Current Session as Template

| Layer | Value |
|-------|-------|
| Physical keys | `Super+Shift+S` |
| keyd output | `Ctrl+Shift+S` |
| Ghostty logical key | `shift+control+s` |
| Ghostty sends | `\x01S` (prefix, then `S`) |
| tmux binding | `bind-key S` → `scripts/save.sh` |

#### Binding 4: Manage Templates (browse / preview / edit / delete)

| Layer | Value |
|-------|-------|
| Physical keys | `Super+Shift+M` |
| keyd output | `Ctrl+Shift+M` |
| Ghostty logical key | `shift+control+m` |
| Ghostty sends | `\x01M` (prefix, then `M`) |
| tmux binding | `bind-key M` → `scripts/manage.sh` |

### 3.3 Ghostty Keybinding Changes Required

The following changes must be applied to `~/.config/ghostty/keybindings`. These are listed as precise before/after diffs.

**Change 1: Replace `control+n=new_window` with session factory binding**

```
# REMOVE:
keybind = control+n=new_window

# ADD:
# New session (blank or from template)
# Physical SUPER+N → keyd → Ctrl+N → Ghostty: control+n
# Sends: prefix (C-a) then n → session-factory new session picker
keybind = control+n=text:\x01n
```

**Change 2: Add `shift+control+n` for template-only picker**

```
# ADD (new binding, does not replace anything):
# New session from template (skip blank option)
# Physical SUPER+SHIFT+N → keyd → Ctrl+Shift+N → Ghostty: shift+control+n
# Sends: prefix (C-a) then C-n → session-factory template picker
keybind = shift+control+n=text:\x01\x0e
```

**Change 3: Reassign `shift+control+s` from resurrect-save to template-save**

```
# REMOVE:
keybind = shift+control+s=text:\x01\x13

# ADD:
# Save current session as template
# Physical SUPER+SHIFT+S → keyd → Ctrl+Shift+S → Ghostty: shift+control+s
# Sends: prefix (C-a) then S → session-factory save template
keybind = shift+control+s=text:\x01S
```

**Change 4: Add `control+s` for resurrect-save (relocated)**

```
# ADD (new binding, relocates resurrect-save from shift+control+s):
# Save session (tmux-resurrect) — relocated to SUPER+S
# Physical SUPER+S → keyd → Ctrl+S → Ghostty: control+s
# Sends: prefix (C-a) then Ctrl-S → resurrect save
keybind = control+s=text:\x01\x13
```

**Change 5: Add `shift+control+m` for template manager**

```
# ADD (new binding):
# Manage templates (browse / preview / edit / delete)
# Physical SUPER+SHIFT+M → keyd → Ctrl+Shift+M → Ghostty: shift+control+m
# Sends: prefix (C-a) then M → session-factory manage templates
keybind = shift+control+m=text:\x01M
```

### 3.4 Existing Keybinding Conflicts — Audit

Before finalizing, verify none of the new tmux bindings collide with existing prefix bindings:

| tmux binding | Status |
|---|---|
| `prefix + n` | **Safe.** Not used by tmux natively or in the current `tmux.conf`. |
| `prefix + C-n` | **Safe.** Not used by tmux natively or in the current `tmux.conf`. |
| `prefix + S` | **Safe.** Uppercase `S` is not bound. (Lowercase `s` is bound to session picker via `\x01s` in Ghostty.) |
| `prefix + M` | **Safe.** Not used by tmux natively or in the current `tmux.conf`. |

No conflicts with existing tmux-resurrect, tmux-pain-control, tmux-yank, tmux-continuum, or catppuccin bindings.

---

## 4. Plugin Architecture

### 4.1 Directory Structure

Following the TPM convention established by tmux-resurrect and other official tmux-plugins:

```
tmux-session-factory/
├── session-factory.tmux        # TPM entry point — sources helpers, registers bindings
├── scripts/
│   ├── helpers.sh              # Shared utilities: get_tmux_option, display_message, snapshot_session
│   ├── variables.sh            # Option names and default values
│   ├── save.sh                 # Thin wrapper: command-prompt → _snapshot.sh
│   ├── _snapshot.sh            # Core capture logic: session → JSON template
│   ├── apply.sh                # Apply a template to create a new session
│   ├── new_session.sh          # fzf picker: blank or template → create session
│   ├── manage.sh               # fzf picker: browse / preview / edit / delete templates
│   ├── edit.sh                 # Interactive edit: instantiate temp session, set up bindings
│   ├── _edit_save.sh           # Edit mode: re-snapshot temp session, restore bindings, cleanup
│   └── _edit_discard.sh        # Edit mode: discard changes, restore bindings, cleanup
├── README.md                   # User-facing documentation
└── LICENSE                     # License file
```

Scripts prefixed with `_` are internal — called by other scripts, not directly by the user or by tmux key bindings.

### 4.2 TPM Entry Point: `session-factory.tmux`

This is the file TPM executes on load. It must:

1. Be executable (`chmod +x`).
2. Have the shebang `#!/usr/bin/env bash`.
3. Determine its own directory via `CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"`.
4. Source helper scripts.
5. Read user options (with defaults) via `get_tmux_option`.
6. Ensure the template storage directory exists.
7. Register all tmux key bindings.

**Skeleton:**

```bash
#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/helpers.sh"
source "$CURRENT_DIR/scripts/variables.sh"

# Ensure template directory exists
TEMPLATE_DIR="$(get_tmux_option "$template_dir_option" "$template_dir_default")"
mkdir -p "$TEMPLATE_DIR"

# Register key bindings
tmux bind-key n   run-shell "$CURRENT_DIR/scripts/new_session.sh"
tmux bind-key C-n run-shell "$CURRENT_DIR/scripts/new_session.sh --template-only"
tmux bind-key S   run-shell "$CURRENT_DIR/scripts/save.sh"
tmux bind-key M   run-shell "$CURRENT_DIR/scripts/manage.sh"
```

### 4.3 helpers.sh

Following the tmux-resurrect convention, this file provides shared utility functions used across all scripts.

**Required functions:**

```bash
#!/usr/bin/env bash

# Read a tmux user option, returning a default if unset.
# This is the standard TPM pattern for plugin configuration.
#
# Usage: get_tmux_option "@option-name" "default-value"
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value="$(tmux show-option -gqv "$option")"
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Display a message in the tmux status line for a fixed duration.
# Temporarily overrides display-time, then restores it.
#
# Usage: display_message "message text"
display_message() {
    local message="$1"
    local saved_display_time
    saved_display_time="$(get_tmux_option "display-time" "750")"
    tmux set-option -gq display-time 4000
    tmux display-message "$message"
    tmux set-option -gq display-time "$saved_display_time"
}

# Resolve the template storage directory.
# Sources variables.sh if not already loaded.
get_template_dir() {
    local dir
    dir="$(get_tmux_option "$template_dir_option" "$template_dir_default")"
    # Expand ~ and environment variables
    dir="$(eval echo "$dir")"
    echo "$dir"
}

# List template files sorted by modification time (newest first).
# Outputs full paths, one per line.
list_template_files() {
    local dir
    dir="$(get_template_dir)"
    ls -t "$dir"/*.json 2>/dev/null
}

# Check if a tmux session with the given name already exists.
# Returns 0 if exists, 1 if not.
session_exists() {
    tmux has-session -t "=$1" 2>/dev/null
}
```

### 4.4 variables.sh

Centralizes all option names and their defaults. Every configurable aspect of the plugin is defined here.

```bash
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
```

---

## 5. Template Format

Templates are stored as JSON files in the template directory. One file per template, named `<sanitized-name>.json`.

### 5.1 Schema

```json
{
  "name": "string — Display name of the template (as entered by user)",
  "created": "string — ISO 8601 timestamp of creation",
  "source_session": "string — Name of the session this was captured from",
  "windows": [
    {
      "index": "number — 1-based window index within the session",
      "name": "string — Window name",
      "layout": "string — tmux layout string from #{window_layout}",
      "active": "boolean — Whether this window was the active window",
      "panes": [
        {
          "index": "number — 0-based pane index within the window",
          "path": "string — Absolute path of pane working directory",
          "command": "string — Process running in pane (e.g. 'zsh', 'btop', 'yazi')",
          "active": "boolean — Whether this pane was the active pane in its window"
        }
      ]
    }
  ]
}
```

### 5.2 Example

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

### 5.3 Filename Sanitization

The user-entered template name is sanitized for use as a filename:
- Replace any character that is not alphanumeric, hyphen, or underscore with a hyphen.
- Collapse consecutive hyphens.
- Strip leading and trailing hyphens.
- The `.json` extension is appended.

The original display name is preserved in the JSON `name` field.

---

## 6. Feature Specifications

### 6.1 Save Template (`scripts/save.sh`)

**Trigger:** `prefix + S`

**Flow:**

1. Use `tmux command-prompt` to ask the user for a template name.
2. The entered name is passed to the snapshot logic.
3. Capture the current session's state using tmux format strings.
4. Build the JSON template using `jq`.
5. Write the file to the template directory.
6. Display a confirmation message.

**tmux format strings to capture:**

For windows (`tmux list-windows`):
- `#{window_index}` — Window number
- `#{window_name}` — Window name
- `#{window_layout}` — Layout geometry string
- `#{window_active}` — Whether this is the active window

For panes (`tmux list-panes -t <session>:<window>`):
- `#{pane_index}` — Pane number within window
- `#{pane_current_path}` — Working directory
- `#{pane_current_command}` — Running process name
- `#{pane_active}` — Whether this is the active pane

**Overwrite behavior:** If a template with the same sanitized filename already exists, overwrite it silently. The user explicitly chose the name, and this matches the "re-save after edit" workflow (Section 6.5).

**Edge cases:**
- Empty template name → display error message, abort.
- Session with no windows → should not occur in practice; handle gracefully.

**Implementation approach:**

The `save.sh` script itself should be a thin wrapper that calls `tmux command-prompt`, passing the entered name to an internal `_snapshot.sh` (or inline function) that does the actual capture. This separation is necessary because `command-prompt` runs asynchronously — it displays the prompt and returns immediately, executing the provided command template only when the user presses Enter.

```bash
#!/usr/bin/env bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

tmux command-prompt -p "  Save session as template:" \
    "run-shell \"$CURRENT_DIR/_snapshot.sh '%%'\""
```

The `_snapshot.sh` script performs the actual work:

```bash
#!/usr/bin/env bash
# Usage: _snapshot.sh <template_name>
# Captures the active session and writes the JSON template.

set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/variables.sh"

TEMPLATE_NAME="$1"
TEMPLATE_DIR="$(get_template_dir)"

# Validate
if [[ -z "$TEMPLATE_NAME" ]]; then
    display_message "  Template name cannot be empty."
    exit 1
fi

# Sanitize filename
SAFE_NAME="$(echo "$TEMPLATE_NAME" | tr -cs '[:alnum:]-_' '-' | sed 's/^-//;s/-$//')"
TEMPLATE_FILE="$TEMPLATE_DIR/$SAFE_NAME.json"

SESSION_NAME="$(tmux display-message -p '#{session_name}')"

# Build JSON using jq
# ... (see detailed implementation logic in Section 7.1)

display_message "  Template saved: $TEMPLATE_NAME"
```

### 6.2 New Session (`scripts/new_session.sh`)

**Trigger:** `prefix + n` (all options) or `prefix + C-n` (templates only, via `--template-only` flag)

**Flow:**

1. Build a list of options for fzf:
   - If not `--template-only`: include a "New blank session" entry at the top.
   - List all saved templates with metadata (name, window count, pane count).
2. Open an fzf picker inside `tmux display-popup`.
3. If user selects "New blank session":
   - Prompt for session name (inline in the popup, via `read`).
   - Create a new tmux session with that name.
   - Switch to it.
4. If user selects a template:
   - Prompt for session name (defaulting to template display name).
   - If a session with that name already exists, switch to it instead.
   - Otherwise, call `apply.sh` to instantiate the template.
5. If user presses Escape or selects nothing, close the popup with no action.

**fzf display format:**

Each template entry shows:
```
  <template_name>  <N>w <M>p
```
Where `N` = window count, `M` = total pane count across all windows. The blank option shows:
```
  New blank session
```

The filename is included as a hidden column (using `--delimiter` and `--with-nth`) so fzf displays the pretty name but the script can resolve the file path from the selection.

**fzf color scheme** (matches the user's terminal aesthetic):
```
--color=bg+:-1,fg+:#dadada,hl:#33ccff,hl+:#00ff99,pointer:#00ff99,prompt:#33ccff,header:#595959
```

**Popup dimensions:** `display-popup -E -w 60% -h 50%`

**Error handling:**
- No templates exist and `--template-only` → display message "No templates found," exit.
- Session name already exists → switch to existing session, display message.

### 6.3 Apply Template (`scripts/apply.sh`)

**Trigger:** Called internally by `new_session.sh` and `edit.sh`. Not bound to a key directly.

**Usage:** `apply.sh <template_file_path> <session_name>`

**Flow:**

1. Read and parse the JSON template file.
2. Create the session with the first window:
   ```
   tmux new-session -d -s <session_name> -n <first_window_name> -c <first_pane_path>
   ```
3. For each additional pane in the first window:
   ```
   tmux split-window -t <session>:<window> -c <pane_path>
   ```
4. Apply the saved layout geometry to the first window:
   ```
   tmux select-layout -t <session>:<window> <layout_string>
   ```
5. Repeat steps 3-4 for each subsequent window:
   ```
   tmux new-window -t <session> -n <window_name> -c <first_pane_path>
   ```
6. For each pane, set the working directory:
   ```
   tmux send-keys -t <session>:<window>.<pane> "cd <path> && clear" Enter
   ```
7. For each pane, check if the captured command is on the restore whitelist. If yes:
   ```
   tmux send-keys -t <session>:<window>.<pane> "<command>" Enter
   ```
8. Select the pane that was active in each window.
9. Select the window that was active in the session.
10. Switch the client to the new session:
    ```
    tmux switch-client -t <session_name>
    ```

**Process restore logic (detailed):**

```bash
# Read the global whitelist
RESTORE_PROCESSES="$(get_tmux_option "$restore_processes_option" "$restore_processes_default")"

# For each pane in the template:
PANE_COMMAND="$(jq -r ".windows[$w].panes[$p].command" "$TEMPLATE_PATH")"
PANE_PATH="$(jq -r ".windows[$w].panes[$p].path" "$TEMPLATE_PATH")"

# Check if command is a shell (don't restore — just cd)
case "$PANE_COMMAND" in
    bash|zsh|fish|sh|dash)
        tmux send-keys -t "$PANE_TARGET" "cd $(printf '%q' "$PANE_PATH") && clear" Enter
        ;;
    *)
        # Check if command is on the whitelist
        if echo " $RESTORE_PROCESSES " | grep -q " $PANE_COMMAND "; then
            tmux send-keys -t "$PANE_TARGET" "cd $(printf '%q' "$PANE_PATH") && clear" Enter
            tmux send-keys -t "$PANE_TARGET" "$PANE_COMMAND" Enter
        else
            # Not on whitelist — treat as shell pane
            tmux send-keys -t "$PANE_TARGET" "cd $(printf '%q' "$PANE_PATH") && clear" Enter
        fi
        ;;
esac
```

**Critical implementation detail — pane ordering:**

When splitting panes, tmux assigns indices sequentially. The layout string encodes the exact geometry. The correct approach is:

1. Create the window (this creates pane 0).
2. For panes 1 through N-1: `split-window` (direction doesn't matter because we apply the layout string afterward, which overrides all geometry).
3. Apply the layout: `select-layout <layout_string>`.

The layout string is what guarantees the geometry matches the original. We do NOT need to figure out whether the original splits were horizontal or vertical — the layout string encodes that.

**Edge cases:**
- A working directory in the template no longer exists → fall back to `$HOME`.
- A command on the whitelist is not installed → the shell will show "command not found," which is acceptable. No special handling needed.
- Template has 0 windows → create a blank session (should not happen in practice).

### 6.4 Manage Templates (`scripts/manage.sh`)

**Trigger:** `prefix + M`

**Flow:**

1. List all templates with metadata.
2. Open an fzf picker inside `tmux display-popup`.
3. Support multiple actions via fzf `--expect`:
   - `Enter` → Preview only (fzf's `--preview` shows template details).
   - `ctrl-d` → Delete the selected template.
   - `ctrl-e` → Edit the selected template interactively (calls `edit.sh`).
4. Display confirmation for deletion.

**fzf preview command:**

The preview pane shows a formatted summary of the template. This should be a human-readable rendering, not raw JSON. Use `jq` to format:

```bash
--preview='
    FILE="'"$TEMPLATE_DIR"'/{2}.json"
    echo ""
    jq -r "\"  Template: \\(.name)\"" "$FILE"
    jq -r "\"  Source: \\(.source_session)\"" "$FILE"
    jq -r "\"  Created: \\(.created | split(\"T\")[0])\"" "$FILE"
    echo ""
    echo "  Windows:"
    jq -r ".windows[] | \"    \\(.index). \\(.name)  (\\(.panes | length) panes)\"" "$FILE"
    echo ""
    echo "  Pane detail:"
    jq -r ".windows[] | . as \$w | .panes[] | \"    \\(\$w.name):\\(.index) → \\(.path | split(\"/\") | .[-2:] | join(\"/\"))  [\\(.command)]\"" "$FILE"
'
```

**fzf header:**
```
Enter: preview · Ctrl-E: edit · Ctrl-D: delete
```

**Delete confirmation:** After `ctrl-d`, display the template name and ask for confirmation before removing. Since we're inside a popup script, we can use a simple `read -p` confirmation.

### 6.5 Interactive Edit (`scripts/edit.sh`)

**Trigger:** `ctrl-e` from the manage picker. Also callable directly: `edit.sh <template_file_path>`

**Flow:**

1. Read the template name from the JSON file.
2. Generate a temporary session name: `_factory_edit:<template_name>`.
3. Call `apply.sh` to instantiate the template as a temporary session.
4. Register a *temporary* key binding in tmux that allows the user to signal "done editing":
   - `prefix + S` in this context should re-snapshot the temp session back to the original template file, then clean up.
   - `prefix + Q` should discard changes and clean up.
5. Display a message: `"Editing template: <name> — prefix+S to save & exit, prefix+Q to discard"`
6. Switch the client to the temporary session.

**"Save and exit" handler (re-snapshot):**

When the user presses `prefix + S` while in a `_factory_edit:*` session:

1. Detect that the current session name starts with `_factory_edit:`.
2. Extract the original template name from the session name.
3. Run the snapshot logic (same as `save.sh` / `_snapshot.sh`), writing back to the original template file.
4. Record the previous session name (the one the user was in before editing).
5. Switch the client back to the previous session (or the next available session).
6. Kill the temporary edit session.
7. Display confirmation: `"  Template updated: <name>"`

**"Discard" handler:**

When the user presses `prefix + Q` while in a `_factory_edit:*` session:

1. Record the previous session.
2. Switch back.
3. Kill the temporary session.
4. Display: `"  Edit discarded."`

**Implementation approach for context-sensitive bindings:**

The cleanest approach is to set up the edit-mode bindings when entering edit mode, and tear them down when exiting. This avoids permanently shadowing the user's normal `prefix + S` binding.

```bash
# On entering edit mode:
tmux bind-key S run-shell "$CURRENT_DIR/_edit_save.sh"
tmux bind-key Q run-shell "$CURRENT_DIR/_edit_discard.sh"

# In _edit_save.sh and _edit_discard.sh, after completing the action:
# Restore the original bindings
tmux bind-key S run-shell "$CURRENT_DIR/save.sh"
tmux unbind-key Q
```

**Critical consideration:** The `prefix + S` rebinding is session-global in tmux (bindings are global, not per-session). This means while in edit mode, pressing `prefix + S` in *any* session will trigger the edit-save handler. The edit-save/discard scripts must therefore check whether the *active session* is actually a `_factory_edit:*` session before proceeding. If it's not, the save handler should fall through to normal save behavior.

```bash
# At the top of _edit_save.sh:
SESSION_NAME="$(tmux display-message -p '#{session_name}')"
if [[ "$SESSION_NAME" != _factory_edit:* ]]; then
    # Not in edit mode — fall through to normal save
    exec "$CURRENT_DIR/save.sh"
fi
# Otherwise, proceed with edit-save logic...
```

---

## 7. Detailed Implementation Logic

### 7.1 Snapshot Logic (used by `_snapshot.sh` and `_edit_save.sh`)

This is the core capture logic. It should be implemented as a function in `helpers.sh` or as a standalone script that both `_snapshot.sh` and `_edit_save.sh` can call.

**Function signature:** `snapshot_session <session_name> <template_name> <output_file>`

**Implementation:**

```bash
snapshot_session() {
    local session_name="$1"
    local template_name="$2"
    local output_file="$3"

    local windows_json="[]"

    # Iterate over windows
    while IFS=$'\t' read -r win_idx win_name win_layout win_active; do
        local panes_json="[]"

        # Iterate over panes in this window
        while IFS=$'\t' read -r pane_idx pane_path pane_cmd pane_active; do
            panes_json=$(echo "$panes_json" | jq \
                --arg idx "$pane_idx" \
                --arg path "$pane_path" \
                --arg cmd "$pane_cmd" \
                --arg active "$pane_active" \
                '. + [{
                    index: ($idx | tonumber),
                    path: $path,
                    command: $cmd,
                    active: ($active == "1")
                }]')
        done < <(tmux list-panes -t "${session_name}:${win_idx}" \
            -F '#{pane_index}	#{pane_current_path}	#{pane_current_command}	#{pane_active}')

        windows_json=$(echo "$windows_json" | jq \
            --arg idx "$win_idx" \
            --arg name "$win_name" \
            --arg layout "$win_layout" \
            --arg active "$win_active" \
            --argjson panes "$panes_json" \
            '. + [{
                index: ($idx | tonumber),
                name: $name,
                layout: $layout,
                active: ($active == "1"),
                panes: $panes
            }]')
    done < <(tmux list-windows -t "$session_name" \
        -F '#{window_index}	#{window_name}	#{window_layout}	#{window_active}')

    # Assemble final JSON
    jq -n \
        --arg name "$template_name" \
        --arg created "$(date -Iseconds)" \
        --arg source "$session_name" \
        --argjson windows "$windows_json" \
        '{
            name: $name,
            created: $created,
            source_session: $source,
            windows: $windows
        }' > "$output_file"
}
```

### 7.2 Apply Logic

See Section 6.3 for the detailed flow. Key implementation notes:

- **Window targeting:** After creating a window with `-n <name>`, target it as `<session>:<name>`. However, if two windows share a name, this is ambiguous. Safer to use the window index. After `new-window`, capture the index from `tmux display-message -p -t <session> '#{window_index}'` or simply use the expected index from the template.
- **Layout application timing:** Apply `select-layout` AFTER all panes for that window have been created. The layout string encodes geometry for exactly N panes; applying it with fewer panes will fail or produce wrong results.
- **Pane index stability:** When splitting, tmux assigns the new pane the next available index. After creating all panes and applying the layout, pane indices should be 0, 1, 2, ... in order. Use these for targeting.

### 7.3 New Session Picker Logic

The popup spawns a bash subshell. Within that subshell:

1. Build the fzf input list.
2. Pipe to fzf.
3. Parse the selection.
4. Either create a blank session or call `apply.sh`.

**Important:** The popup runs in a subshell that is NOT inside tmux's `run-shell` context. It's a real terminal inside a `display-popup`. This means:
- `read` works for user input.
- `tmux` commands work normally (the tmux socket is available).
- The popup closes automatically when the subshell exits (due to `-E` flag).

### 7.4 fzf Popup Pattern

All three pickers (new session, manage, edit) use the same structural pattern:

```bash
tmux display-popup -E -w <width> -h <height> -T " <title>" \
    "bash -c '
        # ... inline script or call to external script ...
    '"
```

**Note on quoting:** The inline script is inside single quotes within double quotes. Any single quotes inside the script must be escaped as `'\''`. For complex scripts, it's cleaner to call an external script file:

```bash
tmux display-popup -E -w 60% -h 50% -T " Title" \
    "$CURRENT_DIR/_picker.sh [args]"
```

This avoids quoting hell and makes the code testable independently.

---

## 8. Plugin Options (tmux.conf)

### 8.1 v1 Options

Users configure the plugin by setting tmux options before TPM loads.

```tmux
# Template storage directory (default: $XDG_DATA_HOME/tmux/session-templates)
set -g @session-factory-dir "$HOME/.local/share/tmux/session-templates"

# Process restore whitelist (default: "btop yazi")
# Space-separated list of commands to auto-restart on template apply
set -g @session-factory-restore-processes "btop yazi"
```

### 8.2 Future Options (v2+)

These are not implemented in v1 but the code should be structured to support them easily (i.e., all hardcoded values that could become options should be defined as constants in `variables.sh`):

```
@session-factory-key-new           # Override prefix + n
@session-factory-key-new-template  # Override prefix + C-n
@session-factory-key-save          # Override prefix + S
@session-factory-key-manage        # Override prefix + M
@session-factory-popup-width       # Override popup width
@session-factory-popup-height      # Override popup height
@session-factory-fzf-opts          # Additional fzf flags
```

---

## 9. Integration with tmux.conf

### 9.1 Plugin Declaration

Add to the plugins section of `~/.config/tmux/tmux.conf`:

```tmux
set -g @plugin 'tmux-session-factory'
```

For local development before pushing to a remote:

```tmux
set -g @plugin '/absolute/path/to/local/tmux-session-factory'
```

Or using a local bare git repo as described in the TPM development docs.

### 9.2 Interaction with Existing Plugins

| Plugin | Interaction | Notes |
|--------|-------------|-------|
| tmux-resurrect | Independent. Resurrect saves live state; factory saves templates. | Resurrect-save relocated to `prefix + C-s` via Ghostty rebind. No code-level interaction. |
| tmux-continuum | No interaction. | Continuum auto-saves resurrect state on interval. Unrelated to templates. |
| tmux-pain-control | No conflict. | pain-control uses `-`, `\|`, and vim keys for splits/nav. None overlap with n, C-n, S, M. |
| tmux-yank | No conflict. | yank uses copy-mode bindings only. |
| catppuccin/tmux | No conflict. | Theme plugin, no key bindings. |

---

## 10. UX Flows — Complete Walkthrough

### 10.1 Saving a Template

1. User arranges their session exactly how they want it — windows named, panes split and sized, TUI apps running where desired.
2. User presses physical `Super+Shift+S`.
3. tmux status line shows: `Save session as template: _`
4. User types `fullstack-dev` and presses Enter.
5. Status line flashes: `  Template saved: fullstack-dev`
6. File `~/.local/share/tmux/session-templates/fullstack-dev.json` is created.

### 10.2 Creating a New Session from Template

1. User presses physical `Super+N`.
2. A popup appears with title "  New Session":
   ```
     New blank session
     fullstack-dev  3w 7p
     monitoring  2w 4p
     writing  1w 1p
   ```
3. User fuzzy-searches for "full", selects `fullstack-dev`.
4. Popup shows: `Session name [fullstack-dev]: _`
5. User types `client-abc` and presses Enter.
6. A new session named `client-abc` is created with the exact window/pane layout from the template. `btop` and `yazi` are restarted in their respective panes.
7. Client switches to the new session.

### 10.3 Creating a Blank Session

1. User presses physical `Super+N`.
2. Popup appears. User selects "New blank session."
3. Popup shows: `Session name: _`
4. User types `scratch` and presses Enter.
5. A new session with one window and one pane is created.

### 10.4 Managing Templates

1. User presses physical `Super+Shift+M`.
2. A popup appears with title "  Manage Templates":
   ```
   fullstack-dev  3w 7p  2026-02-10
   monitoring  2w 4p  2026-02-09
   writing  1w 1p  2026-02-08
   ```
3. Preview pane on the right shows template details for the highlighted entry.
4. User presses `Ctrl-D` to delete the `writing` template. Confirmation prompt appears.
5. Or user presses `Ctrl-E` to edit the `fullstack-dev` template interactively.

### 10.5 Interactive Template Editing

1. From the manage picker, user highlights `fullstack-dev` and presses `Ctrl-E`.
2. Popup closes. A temporary session `_factory_edit:fullstack-dev` is created with the template's layout.
3. Status line shows: `"Editing: fullstack-dev — prefix+S to save, prefix+Q to discard"`
4. User rearranges panes, renames a window, adds a split, resizes things.
5. User presses `prefix + S` (physical `Super+Shift+S`).
6. The temporary session is re-snapshotted back to `fullstack-dev.json`.
7. Temporary session is killed. Client switches back to the previous session.
8. Status line flashes: `"  Template updated: fullstack-dev"`

---

## 11. Testing Strategy

### 11.1 Manual Testing Checklist

Each feature should be verified manually against this checklist:

**Save:**
- [ ] Save a single-window, single-pane session.
- [ ] Save a multi-window session with varying pane counts.
- [ ] Save a session with `btop` and `yazi` running in specific panes.
- [ ] Save with a name containing spaces and special characters.
- [ ] Save with a name that already exists (should overwrite).
- [ ] Cancel the name prompt (press Escape) — should abort cleanly.

**Apply / New Session:**
- [ ] Create from a template — verify window names match.
- [ ] Verify pane split geometry matches the original visually.
- [ ] Verify working directories are correct in each pane.
- [ ] Verify `btop` and `yazi` are restarted in the correct panes.
- [ ] Verify a non-whitelisted command (e.g., if `nvim` was running) results in a plain shell.
- [ ] Create a blank session — verify it works.
- [ ] Attempt to create a session with an existing name — should switch to it.
- [ ] Run with `--template-only` when no templates exist — should show message.

**Manage:**
- [ ] Browse templates — verify preview shows correct information.
- [ ] Delete a template — verify file is removed.
- [ ] Delete the only template — verify graceful handling.

**Interactive Edit:**
- [ ] Edit a template — modify pane layout — save — verify JSON is updated.
- [ ] Edit a template — discard — verify JSON is unchanged.
- [ ] While in edit mode, switch to another session and press `prefix + S` — should trigger normal save, not edit-save.
- [ ] Verify the previous session is correctly returned to after edit save/discard.

### 11.2 Edge Cases

- Template directory does not exist → should be auto-created.
- Template JSON is malformed → `jq` will error; handle gracefully with a message.
- Template references a directory that no longer exists → fall back to `$HOME`.
- Template was saved with 3 panes but user manually created more in edit → re-snapshot captures new state.
- tmux server has only one session and user enters edit mode → after save/discard, the edit session is the last one; killing it would exit tmux. Handle by creating a placeholder session if needed, or by checking `tmux list-sessions | wc -l`.

---

## 12. Build Sequence

The coding agent should build the plugin in this order, testing each step before proceeding:

### Phase 1: Scaffold
1. Create the directory structure.
2. Implement `helpers.sh` with `get_tmux_option`, `display_message`, `get_template_dir`, `session_exists`.
3. Implement `variables.sh` with option names and defaults.
4. Implement `session-factory.tmux` entry point with all four `bind-key` calls.
5. Make all `.tmux` and `.sh` files executable.
6. Test: Install via TPM (or `run-shell`), verify bindings are registered (`tmux list-keys | grep -E '^bind-key.*[nSM]'`).

### Phase 2: Save
7. Implement `save.sh` (command-prompt wrapper).
8. Implement `_snapshot.sh` (capture logic).
9. Test: Save a multi-window session, inspect the JSON output, verify it's correct.

### Phase 3: Apply + New Session
10. Implement `apply.sh` (template instantiation).
11. Implement `new_session.sh` (fzf popup, blank and template creation).
12. Test: Create a session from a saved template, verify geometry and directories.
13. Test: Process restore — run `btop` in a pane, save template, create new session, verify `btop` auto-starts.

### Phase 4: Manage
14. Implement `manage.sh` (fzf popup with preview and delete).
15. Test: Browse templates, verify preview, delete a template.

### Phase 5: Interactive Edit
16. Implement `edit.sh` (temp session creation, binding overrides).
17. Implement `_edit_save.sh` (re-snapshot + cleanup + binding restore).
18. Implement `_edit_discard.sh` (cleanup + binding restore).
19. Test: Full edit cycle — edit, modify, save, verify. Edit, discard, verify unchanged.
20. Test: Edge case — prefix+S in non-edit session during edit mode.

### Phase 6: Polish
21. Test all edge cases from Section 11.2.
22. Write README.md.
23. Final review of all scripts for proper error handling, quoting, and cleanup.

---

## 13. Code Style and Conventions

Following the conventions established by tmux-resurrect and the official tmux-plugins:

- **Shebang:** All scripts use `#!/usr/bin/env bash`.
- **`set -euo pipefail`:** All scripts that perform real work (not the thin `command-prompt` wrappers) should set strict mode. Exception: the TPM entry point (`session-factory.tmux`) should NOT use `set -e` because TPM expects it to succeed even if individual commands have minor issues.
- **`CURRENT_DIR`:** Every script that sources other files or references sibling scripts must set `CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"` at the top.
- **Quoting:** All variable expansions must be double-quoted. Use `$(printf '%q' "$var")` when embedding paths in `send-keys` commands to handle spaces and special characters.
- **`local`:** All function-local variables must use `local`.
- **Tab delimiter:** When parsing multi-field tmux format output, use tab (`$'\t'`) as the delimiter, matching tmux-resurrect's convention.
- **No external dependencies beyond jq and fzf:** Do not introduce Python, Node, or other runtime dependencies.
- **Error messages:** Use `display_message` for all user-facing messages. Prefix with appropriate icon ( for success,  for error, for info).

---

## Appendix A: Current Configuration Files (Reference)

These are the user's current configuration files as of the time this document was created. They are included for reference when implementing the Ghostty keybinding changes and verifying tmux.conf integration.

### A.1 Ghostty Config (`~/.config/ghostty/config`)

```
shell-integration = zsh
shell-integration-features = cursor,sudo
scrollback-limit = 100000
font-size = 14
font-family = "CommitMonoLite Nerd Font"
background = 080909
foreground = dadada
cursor-invert-fg-bg = true
cursor-style = bar
cursor-style-blink = true
window-padding-y = 4,0
window-padding-x = 8,0
background-opacity = 0.8
background-blur-radius = 20
window-inherit-working-directory = true
window-save-state = always
window-step-resize = false
confirm-close-surface = false
mouse-hide-while-typing = true
copy-on-select = true
config-file = keybindings
clipboard-read = allow
clipboard-write = allow
link-url = true
```

### A.2 Ghostty Keybindings (`~/.config/ghostty/keybindings`)

See Section 3.3 for the specific changes required.

Key bindings that are CHANGING:
- `control+n=new_window` → `control+n=text:\x01n`
- `shift+control+s=text:\x01\x13` → `shift+control+s=text:\x01S`

Key bindings being ADDED:
- `shift+control+n=text:\x01\x0e`
- `control+s=text:\x01\x13`
- `shift+control+m=text:\x01M`

### A.3 tmux.conf (`~/.config/tmux/tmux.conf`)

Key relevant settings:
- Prefix: `C-a`
- `base-index`: 1
- `pane-base-index`: 1
- `mode-keys`: emacs
- Plugin manager path: `$HOME/.local/share/tmux/plugins`
- Existing plugins: tpm, sensible, pain-control, yank, resurrect, continuum, tmux-status-signal, catppuccin

The plugin should be added to the plugins list BEFORE the `run "$HOME/.local/share/tmux/plugins/tpm/tpm"` line:

```tmux
set -g @plugin 'tmux-session-factory'
```

### A.4 keyd (`/etc/keyd/default.conf`)

Physical Super → Ctrl, Physical Ctrl → Super. See Section 3.1 for the full mapping chain.

---

## Appendix B: Glossary

| Term | Definition |
|------|-----------|
| Template | A JSON file describing a session's window/pane layout, stored in the template directory. |
| Layout string | tmux's internal representation of pane geometry within a window (`#{window_layout}`). Encodes all split positions, sizes, and orientations. |
| Snapshot | The act of capturing a running session's state and writing it as a template. |
| Apply | The act of reading a template and creating a new tmux session from it. |
| Whitelist | The `@session-factory-restore-processes` option — a list of TUI commands that should be auto-restarted when applying a template. |
| Edit mode | A temporary state where a template is instantiated as a `_factory_edit:*` session for interactive modification. |
| TPM | Tmux Plugin Manager. Loads plugins by executing all `*.tmux` files in the plugin directory. |
| keyd | Kernel-level key remapper. In this environment, swaps physical Ctrl and Super. |
| Ghostty | GPU-accelerated terminal emulator. Translates logical key combos to escape sequences sent to tmux. |
