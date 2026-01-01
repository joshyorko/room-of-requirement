# Room of Requirement Core Meta-Feature

## Overview

**ror-core** is a Meta-Feature that aggregates the essential Room of Requirement development tools into a single, convenient feature reference. Instead of specifying three separate features, developers can add `ror-core` once and get the complete core tool stack.

## What is a Meta-Feature?

A Meta-Feature uses the `dependsOn` field in `devcontainer-feature.json` to declare hard dependencies on other atomic features. When you reference a Meta-Feature:

1. The DevContainer platform automatically resolves all dependencies
2. Each dependent feature is installed in order with specified options
3. All configuration is centralized in one place
4. Tool versions are consistent across projects

## Included Tools

The **ror-core** Meta-Feature brings together three core tools:

### 1. **mise** - Polyglot Version Manager
- Manages Node.js, Python, Go, and 400+ other tools
- Automatic version switching per project (`.mise.toml`)
- Pre-installs LTS Node, latest Python, latest Go
- See [mise Feature](../mise/README.md) for advanced configuration

### 2. **Starship** - Modern Shell Prompt
- Blazing-fast prompt rendering (<100ms)
- Git status, command duration, error codes
- Minimal configuration, works out-of-the-box
- See [Starship Feature](../starship/README.md) for customization

### 3. **zoxide** - Smart Directory Navigation
- Learns your most-used directories automatically
- Quick jumps: `z workspace` → navigates to recently-used "workspace" dir
- Interactive selection: `z -i` for fuzzy search
- See [zoxide Feature](../zoxide/README.md) for options

## Usage

### Option 1: Reference Meta-Feature (Recommended)

```json
{
  "features": {
    "ghcr.io/joshyorko/ror-features/ror-core:latest": {}
  }
}
```

With default configuration for all three tools.

### Option 2: Individual Features (Advanced)

If you need custom options for specific tools, reference them separately:

```json
{
  "features": {
    "ghcr.io/joshyorko/ror-features/mise:latest": {
      "defaultTools": "node@20,python@3.11"
    },
    "ghcr.io/joshyorko/ror-features/starship:latest": {},
    "ghcr.io/joshyorko/ror-features/zoxide:latest": {}
  }
}
```

## Quick Start

### After Container Creation

```bash
# Verify tools installed
mise --version
starship --version
zoxide --version

# Initialize mise in your shell (optional, automatic in default .zshrc)
eval "$(mise activate zsh)"

# Try zoxide
cd ~/workspace
z -i  # Fuzzy find recent directories

# Check your shell prompt
# Starship should show git status, execution time, etc.
```

### Project-Specific Configuration

Create `.mise.toml` in your project root:

```toml
[tools]
node = "20"      # Pin Node to v20
python = "3.11"  # Pin Python to 3.11
go = "1.21"      # Pin Go to 1.21

[tasks.setup]
run = "npm install && pip install -e ."

[tasks.dev]
run = "npm run dev"
```

Then:

```bash
cd /path/to/project
mise install      # Installs specified versions
mise run setup    # Runs setup task
```

## Architecture

```
ror-core (Meta-Feature v1.0.0)
├─ id: "ror-core"
├─ dependsOn:
│  ├─ mise (with defaultTools: node@lts, python@latest, go@latest)
│  ├─ starship (with version: latest)
│  └─ zoxide (default options)
```

When installed, the DevContainer platform:
1. Installs mise with pre-configured language runtimes
2. Installs Starship prompt configured for containers
3. Installs zoxide for directory navigation
4. All tools configured and ready to use

## Troubleshooting

### Tool not found after installation

Check that feature installation completed:

```bash
# Verify installations
command -v mise && echo "✓ mise installed" || echo "✗ mise missing"
command -v starship && echo "✓ starship installed" || echo "✗ starship missing"
command -v zoxide && echo "✓ zoxide installed" || echo "✗ zoxide missing"
```

### PATH issues with mise

Ensure mise is activated in your shell:

```bash
# Add to .zshrc or .bashrc:
eval "$(mise activate bash)"  # for bash
eval "$(mise activate zsh)"   # for zsh
```

### Starship prompt not showing

Verify Starship configuration:

```bash
starship config  # Shows config file location
starship check   # Validates configuration
starship bug-report  # Detailed diagnostic info
```

## Design Patterns

The ror-core Meta-Feature demonstrates:

1. **Aggregation**: Combining multiple atomic features into one logical unit
2. **Versioning**: All dependencies pinned to specific versions
3. **Configuration**: Default options suitable for 90% of use cases
4. **Extensibility**: Users can override options or add additional features

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/ror-core:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/ror-core:1": {}
  }
}
```

### Override Patterns for Meta-Feature

**Override dependent feature options:**

Since ror-core declares dependencies with default options, you can override them by also including the atomic feature:

```json
{
  "features": {
    // Meta-feature with defaults
    "ghcr.io/joshyorko/room-of-requirement/ror-core:1.0.0": {},

    // Override mise with custom tools (takes precedence)
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "defaultTools": "node@18,python@3.9,go@1.20"
    }
  }
}
```

**Use individual features instead of meta-feature:**

For maximum control, reference atomic features directly:

```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "defaultTools": "node@20.10.0"
    },
    "ghcr.io/joshyorko/room-of-requirement/starship:1.0.0": {
      "version": "v1.17.0"
    },
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1.0.0": {}
  }
}
```

**Skip specific tools:**

If you don't want a specific tool from ror-core, use atomic features:

```json
{
  "features": {
    // Only mise and zoxide, no starship
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {},
    "ghcr.io/joshyorko/room-of-requirement/zoxide:1.0.0": {}
  }
}
```

## Related Documentation

- **Dependencies**:
  - [mise Feature](../mise/README.md) — Language runtime management
  - [Starship Feature](../starship/README.md) — Prompt customization
  - [zoxide Feature](../zoxide/README.md) — Navigation options

- **Project Information**:
  - [Room of Requirement Main Spec](../../001-modular-devcontainer-architecture/spec.md)
  - [Architecture Overview](../../001-modular-devcontainer-architecture/data-model.md)
