# AGENTS.md

Repository guidance for AI coding agents (Codewhale, Claude Code, etc.) working on this repository.

## Project Overview

This repository contains the **Codewhale Terminal** Home Assistant add-on (`codewhale-terminal/`): the [Codewhale](https://github.com/Hmbown/CodeWhale) coding agent — a Rust TUI/CLI for DeepSeek, OpenAI-compatible gateways, and 30+ other providers — running in a browser terminal (ttyd + tmux). The design goal is to stay thin — the add-on's job is running Codewhale reliably, not wrapping it in extra UI.

## Development Environment

### Setup
```bash
# Enter the development shell (NixOS/Nix)
nix develop

# Or with direnv (if installed)
direnv allow
```

### Core Commands
- `build-codewhale` - Build the add-on with Podman (`ubuntu:24.04` base)
- `run-codewhale` - Run add-on locally on port 7681 with volume mapping
- `lint-codewhale-dockerfile` - Lint Dockerfile using hadolint

### Manual Commands (without aliases)
```bash
# Build
podman build --build-arg BUILD_FROM=ubuntu:24.04 -t local/codewhale-terminal ./codewhale-terminal

# Run locally
podman run -p 7681:7681 -v $(pwd)/config:/config local/codewhale-terminal

# Lint
hadolint ./codewhale-terminal/Dockerfile
shellcheck -s bash -e SC1091 codewhale-terminal/run.sh codewhale-terminal/scripts/*.sh

# Test endpoint
curl -X GET http://localhost:7681/
```

## Architecture

### Add-on Structure (codewhale-terminal/)
- **config.yaml** - Home Assistant add-on configuration (options schema, ingress, volume maps); `image:` points at `ghcr.io/stevelea/{arch}-addon-codewhale-terminal`
- **Dockerfile** - Ubuntu 24.04 base for both arches (Codewhale's aarch64 binary is glibc ≥ 2.39; the x64 binary is static musl and runs anywhere). Codewhale binaries are fetched from GitHub Releases at build time (no Node/npm), pinned via the `CODEWHALE_VERSION` build arg
- **build.yaml** - Multi-architecture build configuration (amd64, aarch64); images are prebuilt on GHCR and pulled by the Supervisor
- **run.sh** - Plain-bash startup (no s6-overlay/bashio — not available on Ubuntu): options are read from `/data/options.json` with `jq`. `exec ttyd` at the end makes ttyd PID 1
- **scripts/** - Support scripts copied to `/opt/scripts/` (welcome banner, health check, HA context, MCP setup, persist-install, tmux config, shared config writer)

### Container Execution Flow
1. `init_environment` — point HOME/XDG at `/data` (persistent), prepend `/data/home/.local/bin` to PATH, repoint `CODEWHALE_TUI_BIN` at a persistent copy when one exists
2. `write_codewhale_config` — generate `$CODEWHALE_HOME/config.toml` from add-on options (provider, api_key, base_url, model, reasoning_effort, `dangerously_skip_permissions` → `approval_policy = "never"`, plus raw `extra_config` TOML). Regenerates only when the option fingerprint (`.config-hash`) changes
3. `setup_commands` — install `welcome`, `persist-install`, `ha-context`, `codewhale-doctor`, `codewhale-reconfigure` into `/usr/local/bin`
4. `update_codewhale` — seed a persistent copy in `/data`, background `codewhale update`, with a runnability guard (a broken persistent binary must not shadow the bundled copy)
5. `install_persistent_packages` — user-configured apt/pip packages
6. `generate_ha_context` — background `/config/AGENTS.md` generation via Supervisor API
7. `setup_ha_mcp` — register ha-mcp by writing an argv-form entry (command+args+env) into `$CODEWHALE_HOME/mcp.json` — see `scripts/setup-ha-mcp.sh`
8. `start_web_terminal` — `exec ttyd ... tmux new-session -A -s codewhale 'codewhale [flags]'` (or a plain shell when `auto_launch_codewhale: false`)

### Key Design Rules
- **Nothing on the boot path may hit the network or block on input.** Network work (updates, context generation) is backgrounded; packages ship in the image.
- **Everything persistent lives in `/data`** (HOME is `/data/home`, `CODEWHALE_HOME=/data/.codewhale`). The container filesystem is recreated on every restart.
- **Two Codewhale copies exist**: the bundled binaries at `/usr/local/bin` (fallback, frozen at build time) and a persistent copy at `/data/home/.local/bin` (self-updates, wins via PATH — guarded by a runnability check).
- **No custom session UI.** tmux `new-session -A` handles reconnects; Codewhale's own `-c`/`-r` handle continue/resume.
- **Shared config writer**: `scripts/codewhale-config.sh` is sourced by `run.sh` (boot) and `reconfigure.sh` (manual); keep the two `get_option` copies (codewhale-config.sh and setup-ha-mcp.sh) in sync.

## Development Notes

### Local Container Testing
```bash
# Build test version
podman build --build-arg BUILD_FROM=ubuntu:24.04 -t local/codewhale-terminal:test ./codewhale-terminal

# Run test container (options.json lives in /data inside a real add-on)
mkdir -p /tmp/test-data
echo '{"provider": "deepseek", "api_key": "sk-test", "auto_launch_codewhale": false}' > /tmp/test-data/options.json
podman run -d --name test-codewhale-dev -p 7681:7681 \
  -v /tmp/test-config:/config -v /tmp/test-data:/data local/codewhale-terminal:test

# Check logs / test at http://localhost:7681
podman logs -f test-codewhale-dev

# Hot-reload a script without rebuilding
podman cp ./codewhale-terminal/scripts/welcome.sh test-codewhale-dev:/opt/scripts/
podman exec test-codewhale-dev chmod +x /opt/scripts/welcome.sh

# Stop and cleanup
podman stop test-codewhale-dev && podman rm test-codewhale-dev
```

Note: options are read from `/data/options.json` via `jq` (no bashio). Missing options fall back to the defaults in `get_option`.

### Production Testing
- **Local Testing**: `run-codewhale` on localhost:7681
- **Container Health**: `podman logs <container-id>`
- **Diagnostics**: `codewhale-doctor` inside the terminal for environment/network checks
- **Auth check**: `codewhale auth status` should show the configured provider as "config"

### File Conventions
- **Shell Scripts**: plain `#!/bin/bash` everywhere — the Ubuntu image has no bashio/s6. Boot-path scripts use `get_option` (jq) for options; scripts that run inside the user's terminal must not rely on bashio either.
- **Indentation**: 2 spaces for YAML, 4 spaces for shell scripts
- **Error Handling**: log with `[codewhale-terminal]` prefixes; never let a non-essential step kill startup
- **Permissions**: Credential files (config.toml, mcp.json) must have 600 permissions
- **CI**: shellcheck (warning severity) and hadolint (error threshold) run on PRs; keep both clean

### Key Environment Variables (set by run.sh / Dockerfile)
- `HOME=/data/home`
- `CODEWHALE_HOME=/data/.codewhale` (config.toml, mcp.json, sessions)
- `CODEWHALE_TUI_BIN=/usr/local/bin/codewhale-tui` (repointed at the persistent copy when one exists)
- `UV_CACHE_DIR=/tmp/uv-cache` (image env — keeps caches out of HA backups)
- `SUPERVISOR_TOKEN` (injected by the Supervisor) is persisted to `/data/supervisor.token` (mode 600) at boot for in-container tools; it is also carried inside `/data/.codewhale/mcp.json` for ha-mcp

### Important Constraints
- Add-on targets Home Assistant OS; amd64 + aarch64 only. Base image is `ubuntu:24.04` (glibc for the aarch64 Codewhale binary).
- Must handle credential/session persistence across container restarts.
- `/data` is included in HA backups — never let caches or reproducible artifacts accumulate there.
- The GHCR image path in `config.yaml` must match what `publish-images.yml` pushes (`ghcr.io/stevelea/{arch}-addon-codewhale-terminal`).
