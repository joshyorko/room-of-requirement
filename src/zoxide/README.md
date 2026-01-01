# zoxide Feature

A smarter `cd` command that learns your habits. Quickly navigate to directories you've visited before using fuzzy matching.

## What is zoxide?

[zoxide](https://github.com/ajeetdsouza/zoxide) is a blazing-fast alternative to `cd` that:

- **Learns your habits**: Tracks your most-used directories
- **Fuzzy matching**: Jump with partial path names
- **Cross-shell**: Works with ZSH, Bash, Fish, Nushell, and more
- **Fast**: Written in Rust for instant responses

## Installation

```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1.0.0": {}
  }
}
```

## Configuration

### Feature Options

#### `version` (string)

zoxide version to install.

**Default**: `latest`

**Examples**:
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1.0.0": {
      "version": "v0.9.4"
    }
  }
}
```

## Usage

### Basic Commands

```bash
# Jump to a directory matching "workspace"
z workspace

# Jump to a directory matching multiple terms
z ror spec    # Matches: /path/to/room-of-requirement/specs

# Interactive selection (requires fzf)
zi

# Add current directory to database
zoxide add .

# List stored directories
zoxide query --list
```

### Shell Integration

The feature adds zoxide initialization to the default `.zshrc`. For manual setup:

```bash
# ZSH
eval "$(zoxide init zsh)"

# Bash
eval "$(zoxide init bash)"

# With custom alias
eval "$(zoxide init zsh --cmd j)"  # Use 'j' instead of 'z'
```

### Advanced Usage

```bash
# Query without jumping
zoxide query workspace

# Remove a directory from database
zoxide remove /path/to/remove

# Import from other tools
zoxide import --from autojump /path/to/autojump/db
zoxide import --from z /path/to/z/data
```

### Scoring

zoxide ranks directories by "frecency" (frequency × recency):

- **Frequently visited**: Higher score
- **Recently visited**: Higher score
- **Old, rarely visited**: Lower score

## Troubleshooting

### Directory not found

zoxide needs to learn directories first. Visit a directory with `cd` before using `z`:
```bash
cd /path/to/project
# Now zoxide knows about it
z project
```

### Fuzzy search not matching

Check the database:
```bash
zoxide query --list
```

Add directories manually:
```bash
zoxide add /path/to/important/project
```

### Interactive mode not working

Install `fzf` for interactive selection:
```bash
brew install fzf
zi  # Now works!
```

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1": {}
  }
}
```

### Override Patterns

**Specific zoxide version:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1.0.0": {
      "version": "v0.9.2"
    }
  }
}
```

## See Also

- [zoxide Documentation](https://github.com/ajeetdsouza/zoxide)
- [Shell Completions](https://github.com/ajeetdsouza/zoxide#step-3-add-zoxide-to-your-shell)

## Related Features

- **ror-core**: Meta-Feature bundling zoxide with mise and Starship
- **nushell**: Alternative shell with native zoxide integration
