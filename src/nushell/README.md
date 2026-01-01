# Nushell Feature

A new type of shell - Nushell is a modern shell written in Rust that treats data as structured tables, not strings.

## What is Nushell?

[Nushell](https://www.nushell.sh) is a modern shell that:

- **Structured data**: Pipes pass tables, not strings
- **Built-in data types**: Numbers, strings, dates, durations, file sizes
- **SQL-like queries**: Filter, sort, group data with familiar syntax
- **Cross-platform**: Same syntax on Windows, macOS, Linux
- **Plugin system**: Extend with custom commands

## Installation

```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/nushell:1.0.0": {}
  }
}
```

## Configuration

### Feature Options

#### `version` (string)

Nushell version to install.

**Default**: `latest`

**Examples**:
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/nushell:1.0.0": {
      "version": "0.89.0"
    }
  }
}
```

## Usage

### Starting Nushell

```bash
# Start Nushell
nu

# Or from VS Code terminal profile (if configured)
# Select "nushell" from terminal dropdown
```

### Basic Commands

```bash
# List files with metadata
ls | where size > 1mb

# Parse JSON
open package.json | get dependencies

# System info as table
sys | get host

# Filter processes
ps | where cpu > 10

# Date/time operations
date now | format date "%Y-%m-%d"
```

### Data Manipulation

```bash
# Group files by extension
ls | group-by { get name | path parse | get extension }

# Sort by multiple columns
ls | sort-by -r size modified

# Calculate totals
ls | get size | math sum

# Pivot data
[[name value]; [a 1] [b 2]] | pivot
```

### Pipeline Examples

```bash
# Find large files
ls **/* | where size > 10mb | sort-by -r size

# Git log analysis
git log --oneline | lines | length

# JSON transformation
http get https://api.github.com/repos/nushell/nushell | get stargazers_count
```

## VS Code Integration

The feature configures Nushell as an optional terminal profile in VS Code:

```json
// In devcontainer.json customizations
"terminal.integrated.profiles.linux": {
  "nushell": {
    "path": "/home/linuxbrew/.linuxbrew/bin/nu",
    "args": ["-l"]
  }
}
```

To use: Click the dropdown arrow in the terminal panel and select "nushell".

## Configuration Files

Nushell uses `~/.config/nushell/` for configuration:

- `config.nu` - Main configuration
- `env.nu` - Environment variables
- `login.nu` - Login shell config

### Example config.nu

```nu
# ~/.config/nushell/config.nu

# Prompt configuration
$env.PROMPT_COMMAND = { ||
  $"(ansi green)($env.PWD)(ansi reset) > "
}

# Aliases
alias ll = ls -l
alias la = ls -a
alias .. = cd ..

# Environment
$env.EDITOR = "code --wait"
```

## Troubleshooting

### Command not found

Ensure Homebrew bin is in PATH:
```bash
echo $PATH  # Should include /home/linuxbrew/.linuxbrew/bin
```

### Config not loading

Check config file location:
```bash
nu -c '$nu.config-path'
```

### Integration with mise/zoxide

Initialize tools in `~/.config/nushell/env.nu`:
```nu
# ~/.config/nushell/env.nu

# mise initialization
if (which mise | is-not-empty) {
  mise activate nu | save -f ~/.cache/mise/nushell.nu
  source ~/.cache/mise/nushell.nu
}

# zoxide initialization
if (which zoxide | is-not-empty) {
  zoxide init nushell | save -f ~/.cache/zoxide.nu
  source ~/.cache/zoxide.nu
}
```

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/nushell:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/nushell:1": {}
  }
}
```

### Override Patterns

**Specific Nushell version:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/nushell:1.0.0": {
      "version": "0.88.0"
    }
  }
}
```

## See Also

- [Nushell Book](https://www.nushell.sh/book/)
- [Command Reference](https://www.nushell.sh/commands/)
- [Nushell Cookbook](https://www.nushell.sh/cookbook/)

## Related Features

- **ror-core**: Meta-Feature with mise, Starship, zoxide (ZSH focused)
- **starship**: Cross-shell prompt that works with Nushell
- **zoxide**: Directory navigation with Nushell support
