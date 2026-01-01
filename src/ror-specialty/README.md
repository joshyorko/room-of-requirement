# Room of Requirement Specialty Tools Feature

Specialty development tools not available in Homebrew, installed via direct binary downloads with SHA256 checksum verification.

## What's Included

| Tool | Version | Description |
|------|---------|-------------|
| `action-server` | v2.14.0 | Sema4.AI AI automation server |
| `rcc` | v18.5.0 | Robocorp Control Center CLI |
| `dagger` | latest | CI/CD engine with container pipelines |
| `container-use` | latest | MCP server for sandboxed development |

## Installation

```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {}
  }
}
```

## Configuration

### Feature Options

#### `installActionServer` (boolean)

Install Sema4.AI action-server for AI automation.

**Default**: `true`

#### `installRcc` (boolean)

Install Robocorp RCC for automation workflows.

**Default**: `true`

#### `installDagger` (boolean)

Install Dagger CLI for CI/CD pipelines.

**Default**: `false`

#### `installContainerUse` (boolean)

Install container-use MCP for sandboxed environments.

**Default**: `false`

### Configuration Examples

**All tools:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {
      "installActionServer": true,
      "installRcc": true,
      "installDagger": true,
      "installContainerUse": true
    }
  }
}
```

**Only Sema4.AI tools:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {
      "installActionServer": true,
      "installRcc": true,
      "installDagger": false,
      "installContainerUse": false
    }
  }
}
```

**Only Dagger:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {
      "installActionServer": false,
      "installRcc": false,
      "installDagger": true,
      "installContainerUse": false
    }
  }
}
```

## Usage

### Sema4.AI Tools

```bash
# Check versions
action-server version
rcc version

# Create new action project
action-server new my-action

# Run automation
rcc run -r robot.yaml -t my-task
```

### Dagger

```bash
# Initialize Dagger project
dagger init

# Run pipeline
dagger call build

# Interactive shell
dagger shell
```

### Container-Use

```bash
# Check version
container-use version

# List environments
container-use list

# Add to Claude MCP
claude mcp add container-use -- container-use stdio
```

## Security

All binaries are verified with SHA256 checksums before installation:

```bash
# Example verification in install.sh
EXPECTED_SHA256="abc123..."
ACTUAL_SHA256=$(sha256sum binary.tar.gz | cut -d' ' -f1)
if [ "$EXPECTED_SHA256" != "$ACTUAL_SHA256" ]; then
  echo "Checksum verification failed!"
  exit 1
fi
```

Checksums are maintained by the Room of Requirement maintenance robot and updated when new versions are released.

## Troubleshooting

### Binary not found

Check installation location:
```bash
which action-server
which rcc
which dagger
```

Expected location: `/usr/local/bin/`

### Permission denied

Fix binary permissions:
```bash
sudo chmod +x /usr/local/bin/action-server
sudo chmod +x /usr/local/bin/rcc
```

### Download failure

The feature downloads from official sources:
- Sema4.AI: `downloads.robocorp.com`
- Dagger: `github.com/dagger/dagger`
- container-use: `github.com/anthropics/container-use`

Check network connectivity:
```bash
curl -I https://downloads.robocorp.com
curl -I https://github.com
```

## Version Pinning (T087)

Pin to specific Feature versions for reproducible environments:

```json
{
  "features": {
    // Exact version (recommended for production)
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {},

    // Major version only (auto-receive minor/patch updates)
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1": {}
  }
}
```

### Override Patterns

**Select specific tools:**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {
      "installActionServer": true,
      "installRcc": false,
      "installDagger": true,
      "installContainerUse": false
    }
  }
}
```

**Disable all tools (feature only for future use):**
```json
{
  "features": {
    "ghcr.io/joshyorko/room-of-requirement/ror-specialty:1.0.0": {
      "installActionServer": false,
      "installRcc": false,
      "installDagger": false,
      "installContainerUse": false
    }
  }
}
```

## See Also

- [Sema4.AI Documentation](https://sema4.ai/docs/)
- [Robocorp RCC Documentation](https://robocorp.com/docs/rcc)
- [Dagger Documentation](https://docs.dagger.io/)
- [container-use Documentation](https://github.com/anthropics/container-use)

## Related Features

- **ror-cli-tools**: Homebrew-based CLI tools (kubectl, helm, jq, etc.)
- **ror-core**: Core development tools (mise, Starship, zoxide)
- **mise**: Language runtime management
