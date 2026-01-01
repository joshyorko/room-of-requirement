# Room of Requirement CLI Tools Feature

Essential CLI development tools installed via Homebrew. Provides kubectl, helm, k9s, jq, yq, gh, and other commonly-needed development utilities.

## What's Included

This feature installs development tools via Homebrew's `brew bundle`:

| Tool | Description |
|------|-------------|
| `kubectl` | Kubernetes CLI |
| `helm` | Kubernetes package manager |
| `k9s` | Kubernetes TUI dashboard |
| `jq` | JSON processor |
| `yq` | YAML processor |
| `gh` | GitHub CLI |

## Installation

```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-cli-tools:1.0.0": {}
  }
}
```

## Configuration

### Feature Options

#### `installBrewfile` (boolean)

Whether to install CLI tools from Brewfile.

**Default**: `true`

**Examples**:
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-cli-tools:1.0.0": {
      "installBrewfile": false
    }
  }
}
```

### Custom Brewfile

The feature looks for Brewfiles in this order:
1. Workspace `Brewfile` (if exists)
2. Feature's default `Brewfile`

To customize installed tools, create a `Brewfile` in your workspace root:

```ruby
# Brewfile - Project root

# Kubernetes tools
brew "kubectl"
brew "helm"
brew "k9s"
brew "kustomize"

# Data processing
brew "jq"
brew "yq"

# Development
brew "gh"
brew "git-delta"
brew "ripgrep"
brew "fd"

# Database clients
brew "postgresql@15"
brew "redis"
```

## Usage

### After Installation

```bash
# Kubernetes
kubectl version --client
helm version
k9s

# Data processing
echo '{"name":"test"}' | jq '.name'
cat config.yaml | yq '.spec.replicas'

# GitHub
gh auth login
gh repo list
```

### Adding More Tools

Install additional tools with Homebrew:

```bash
# Single tool
brew install awscli

# From tap
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Update all
brew upgrade
```

### Updating Brewfile

Capture currently installed tools:

```bash
brew bundle dump --force
```

## Prerequisites

This feature requires Homebrew to be installed. The Room of Requirement base image includes Homebrew. If using a different base image, ensure Homebrew is available at `/home/linuxbrew/.linuxbrew/bin/brew`.

## Troubleshooting

### Tool not found

Check Homebrew installation:
```bash
brew doctor
```

Check PATH:
```bash
echo $PATH | tr ':' '\n' | grep linuxbrew
```

### Permission errors

Fix Homebrew permissions:
```bash
sudo chown -R $(whoami) /home/linuxbrew/.linuxbrew
```

### Slow installation

Use Homebrew cache volume mount in `devcontainer.json`:
```json
{
  "mounts": [
    {
      "source": "homebrew-cache",
      "target": "/home/linuxbrew/.cache",
      "type": "volume"
    }
  ]
}
```

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/ror-cli-tools:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/ror-cli-tools:1": {}
  }
}
```

### Override Patterns

**Skip default Brewfile:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-cli-tools:1.0.0": {
      "installBrewfile": false
    }
  }
}
```

Then install only what you need:
```bash
brew install kubectl jq
```

**Use workspace Brewfile:**
Create a `Brewfile` in your project root and the feature will use it instead of the default.

## See Also

- [Homebrew Documentation](https://docs.brew.sh/)
- [Brewfile Reference](https://github.com/Homebrew/homebrew-bundle)

## Related Features

- **ror-core**: Core development tools (mise, Starship, zoxide)
- **ror-specialty**: Specialty tools not available in Homebrew
- **mise**: Language runtime management (complementary to CLI tools)
