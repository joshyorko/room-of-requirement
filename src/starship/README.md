# Starship Feature

The minimal, blazing-fast, and infinitely customizable prompt for any shell. Renders in <100ms with support for ZSH, Bash, Fish, and more.

## What is Starship?

[Starship](https://starship.rs) is a cross-shell prompt that provides:

- **Blazing-fast rendering**: <100ms prompt display
- **Git integration**: Branch, status, stash count
- **Tool version display**: Node.js, Python, Go, Rust versions
- **Command duration**: Shows time for long-running commands
- **Error codes**: Visual feedback on command failures
- **Highly customizable**: TOML configuration

## Installation

```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/starship:1.0.0": {}
  }
}
```

## Configuration

### Feature Options

#### `version` (string)

Starship version to install.

**Default**: `latest`

**Examples**:
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/starship:1.0.0": {
      "version": "v1.17.0"
    }
  }
}
```

#### `configPath` (string)

Path to starship.toml configuration file (relative to feature `config/`).

**Default**: `starship.toml`

## Usage

### Basic Setup

Starship automatically activates if `STARSHIP_CONFIG` is set. The feature configures this to `/home/vscode/.config/starship.toml`.

For manual activation in your shell:

```bash
# ZSH
eval "$(starship init zsh)"

# Bash
eval "$(starship init bash)"
```

### Customization

Edit `~/.config/starship.toml` or create a project-specific config:

```toml
# ~/.config/starship.toml

# Disable slow modules for containers
[container]
disabled = true

[docker_context]
disabled = true

# Configure Git status
[git_status]
style = "bold red"
stashed = "📦"
modified = "📝"

# Show command duration for slow commands
[cmd_duration]
min_time = 500
format = "took [$duration](bold yellow)"

# Node.js version display
[nodejs]
format = "via [⬢ $version](bold green) "
```

### Presets

Apply community presets:

```bash
# Nerd Font preset (requires Nerd Font)
starship preset nerd-font-symbols -o ~/.config/starship.toml

# Plain text preset (no special characters)
starship preset plain-text-symbols -o ~/.config/starship.toml
```

## Container-Optimized Configuration

The feature includes a container-optimized `starship.toml` that:

- Disables `container` and `docker_context` modules (unnecessary in containers)
- Enables `git_status` with visual icons
- Shows `cmd_duration` for commands >500ms
- Uses minimal styling for fast rendering

## Troubleshooting

### Prompt not showing

Ensure Starship is initialized in your shell:
```bash
eval "$(starship init zsh)"
```

### Icons not rendering

Install a [Nerd Font](https://www.nerdfonts.com/) in your terminal emulator:
- VS Code: Set `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"`
- Or use plain text preset: `starship preset plain-text-symbols`

### Slow prompt

Check which modules are slow:
```bash
starship timings
```

Disable slow modules in `starship.toml`:
```toml
[slow_module]
disabled = true
```

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/starship:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/starship:1": {}
  }
}
```

### Override Patterns

**Specific Starship version:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/starship:1.0.0": {
      "version": "v1.16.0"
    }
  }
}
```

**Custom configuration path:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/starship:1.0.0": {
      "configPath": "my-starship.toml"
    }
  }
}
```

## See Also

- [Starship Documentation](https://starship.rs)
- [Configuration Reference](https://starship.rs/config/)
- [Presets Gallery](https://starship.rs/presets/)

## Related Features

- **ror-core**: Meta-Feature bundling Starship with mise and zoxide
- **nushell**: Alternative shell with built-in Starship support
