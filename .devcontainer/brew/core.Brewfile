# Core Shell Foundation Tools
# These are baked into the Docker image for immediate availability

# Shell and prompt
brew "starship"            # Cross-shell prompt

# Directory and version management
brew "mise"                # Polyglot version manager (node, python, go, etc.)
brew "zoxide"              # Smart directory navigation (z command)

# Bold Brew TUI for interactive package management
tap "valkyrie00/bbrew"
brew "valkyrie00/bbrew/bbrew"

# =============================================================================
# ROR Toolset (from ror.Brewfile - baked in for faster startup)
# =============================================================================

# Python
brew "uv"                  # Fast Python package installer

# Data and Database Tools
brew "sqlite"              # Lightweight SQL database
brew "duckdb"              # Embedded analytics database

# VCS and Git tools
brew "gh"                  # GitHub CLI

# RCC and Action Server - installed via brew install --cask in Dockerfile
# (brew bundle skips casks on Linux, but brew install --cask works)
tap "joshyorko/tools"
