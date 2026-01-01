# mise-en-place Feature

A polyglot runtime version manager for seamless management of Node.js, Python, Go, and hundreds of other tools. This feature integrates mise-en-place into the Room of Requirement container for unified, project-specific tool version management.

## What is mise?

[mise](https://mise.jdx.dev) is a polyglot version manager that:

- **Manages language runtimes**: Node.js, Python, Go, Ruby, Rust, Java, and more
- **Provides unified configuration**: Single `.mise.toml` file per project
- **Enables fast switching**: <500ms version switches via shims
- **Handles tasks**: Define and run project-specific build/test tasks
- **Integrates with direnv**: Optional environment switching on `cd`

## Installation

The feature installs mise and optionally pre-installs default tools:

```json
{
  "features": {
    "ghcr.io/joshyorko/ror/mise:1.0.0": {}
  }
}
```

## Configuration

### Feature Options

#### `defaultTools` (string)

Comma-separated list of tools to pre-install during feature installation.

**Default**: `node@lts,python@latest,go@latest`

**Examples**:
```json
{
  "features": {
    "ghcr.io/joshyorko/ror/mise:1.0.0": {
      "defaultTools": "node@20,python@3.11"
    }
  }
}
```

Set to `"none"` to skip pre-installation:
```json
{
  "features": {
    "ghcr.io/joshyorko/ror/mise:1.0.0": {
      "defaultTools": "none"
    }
  }
}
```

#### `shimPath` (string)

Path where mise shims will be configured.

**Default**: `/usr/local/share/mise/shims`

This directory is added to `$PATH` for automatic command resolution.

### Project Configuration (`.mise.toml`)

Create a `.mise.toml` in your project root to declare required tool versions:

```toml
[tools]
node = "20"          # Use Node.js 20.x
python = "3.11"      # Use Python 3.11
go = "1.22"          # Use Go 1.22

[tasks.dev]
description = "Start development server"
run = "npm run dev"

[tasks.test]
description = "Run tests"
run = "npm test && python -m pytest"
```

### Shell Integration

Add mise activation to your shell configuration (`.zshrc`, `.bashrc`, etc.):

```bash
eval "$(mise activate bash)"     # For Bash
eval "$(mise activate zsh)"      # For ZSH
```

The feature's default `.zshrc` includes this automatically.

## Usage

### Install Project Tools

Run mise install to set up all tools declared in `.mise.toml`:

```bash
mise install
```

### Check Installed Tools

```bash
mise list                  # List all installed tools
mise list node             # List installed Node versions
mise which node            # Show active Node.js path
```

### Switch Versions

```bash
mise use node@22          # Switch to Node.js 22 (project scope)
mise use --global python@3.12  # Switch globally
```

### Run Tasks

Define reusable tasks in `.mise.toml`:

```bash
mise run dev              # Run the 'dev' task
mise run test             # Run the 'test' task
```

### Local Tool Installation

Install tools for a specific project only (no `--global` flag):

```bash
mise install node@20 python@3.11
```

### Global Tool Installation

Install tools system-wide:

```bash
mise install --global node@lts python@latest
```

## Examples

### Node.js Project

```toml
# .mise.toml
[tools]
node = "20"
pnpm = "9"

[tasks.dev]
run = "pnpm dev"

[tasks.build]
run = "pnpm build"
```

```bash
mise install        # Install Node 20 and pnpm 9
mise run dev        # Start dev server
```

### Python Data Science Project

```toml
# .mise.toml
[tools]
python = "3.11"

[tasks.test]
run = "pytest tests/"

[tasks.lint]
run = "ruff check ."
```

```bash
mise install        # Install Python 3.11
mise run test       # Run tests
```

### Polyglot Project

```toml
# .mise.toml
[tools]
node = "20"
python = "3.11"
go = "1.22"
rust = "1.75"

[tasks.build]
run = "npm run build && go build ./..."

[tasks.ci]
run = "npm ci && npm test && go test ./..."
```

## Environment Variables

The feature sets:

| Variable | Value | Purpose |
|----------|-------|---------|
| `MISE_CONFIG_DIR` | `/home/vscode/.config/mise` | Configuration directory |
| `MISE_CACHE_DIR` | `/home/vscode/.cache/mise` | Cache directory for downloads |

## Caching

The feature mounts a volume at `/home/vscode/.cache/mise` to persist tool downloads across container rebuilds. This significantly speeds up subsequent `mise install` runs.

## Troubleshooting

### Tools not found

Ensure mise is activated in your shell:
```bash
eval "$(mise activate zsh)"
```

### Version already installed but not active

Check your `.mise.toml` tool specifications and run:
```bash
mise install
```

### Permission denied errors

The feature configures proper permissions for the `vscode` user. If you encounter issues, reset with:
```bash
mkdir -p /home/vscode/.config/mise /home/vscode/.cache/mise
chown -R vscode:vscode /home/vscode/.config/mise /home/vscode/.cache/mise
```

### Download failures

Check your internet connection and verify the tool version exists:
```bash
mise list-remote node       # List available Node versions
mise list-remote python     # List available Python versions
```

## Performance

- **First install**: ~30-60 seconds per tool (depending on size)
- **Version switch**: <500ms via shims
- **Activation**: <100ms in shell startup

## See Also

- [mise Documentation](https://mise.jdx.dev)
- [Supported Tools](https://mise.jdx.dev/tools.html)
- [Task Runner Guide](https://mise.jdx.dev/tasks.html)
- [direnv Integration](https://mise.jdx.dev/direnv.html)

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/mise:1": {}
  }
}
```

### Override Patterns

**Override default tools:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "defaultTools": "node@18.19.0,python@3.9.18"
    }
  }
}
```

**Disable pre-installation:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "defaultTools": "none"
    }
  }
}
```

**Custom shim path:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/mise:1.0.0": {
      "shimPath": "/home/vscode/.local/bin/mise-shims"
    }
  }
}
```

## Related Features

- **ror-core**: Meta-Feature bundling mise with Starship and zoxide
- **ror-cli-tools**: Homebrew-based CLI tool management (complementary to mise)
