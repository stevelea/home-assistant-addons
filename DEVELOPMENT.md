# Development Guide

This guide covers local development and testing workflows for the Codewhale Terminal add-on.

## Local Container Testing

### Prerequisites

- **Podman** (or Docker) installed
- **Git** repository cloned locally
- **NixOS development environment** (optional, for `nix develop`)

### Quick Start Testing

The fastest way to test changes without publishing new versions:

```bash
# 1. Build test container (both arches share ubuntu:24.04)
podman build --build-arg BUILD_FROM=ubuntu:24.04 \
  -t local/codewhale-terminal:test ./codewhale-terminal

# 2. Create test configuration (options.json lives in /data inside a real add-on)
mkdir -p /tmp/test-config /tmp/test-data
echo '{"provider": "deepseek", "api_key": "sk-test", "auto_launch_codewhale": false}' \
  > /tmp/test-data/options.json

# 3. Run test container
podman run -d --name test-codewhale-dev \
  -p 7681:7681 \
  -v /tmp/test-config:/config \
  -v /tmp/test-data:/data \
  local/codewhale-terminal:test

# 4. Check startup logs
podman logs test-codewhale-dev

# 5. Test in browser: http://localhost:7681

# 6. Clean up when done
podman stop test-codewhale-dev && podman rm test-codewhale-dev
```

### Development Workflow

#### 1. Iterative Development

```bash
# Make changes to code
vim codewhale-terminal/run.sh

# Rebuild image
podman build --build-arg BUILD_FROM=ubuntu:24.04 \
  -t local/codewhale-terminal:test ./codewhale-terminal

# Stop old container
podman stop test-codewhale-dev && podman rm test-codewhale-dev

# Start new container with changes
podman run -d --name test-codewhale-dev -p 7681:7681 \
  -v /tmp/test-config:/config -v /tmp/test-data:/data local/codewhale-terminal:test

# Test changes
open http://localhost:7681
```

#### 2. Hot-reload Script Testing

For script changes without full rebuilds:

```bash
# Copy updated script to running container
podman cp ./codewhale-terminal/scripts/welcome.sh \
  test-codewhale-dev:/opt/scripts/

# Make executable
podman exec test-codewhale-dev chmod +x /opt/scripts/welcome.sh

# Test directly
podman exec -it test-codewhale-dev /opt/scripts/welcome.sh
```

### Testing Scenarios

#### Config generation

The add-on writes `$CODEWHALE_HOME/config.toml` from `/data/options.json` at boot
(`scripts/codewhale-config.sh`). Test it locally without a container:

```bash
mkdir -p /tmp/cwtest
echo '{"provider": "deepseek", "api_key": "sk-test"}' > /tmp/cwtest/options.json
CONFIG_FILE=/tmp/cwtest/options.json CODEWHALE_HOME=/tmp/cwtest/.codewhale \
  bash codewhale-terminal/scripts/codewhale-config.sh
cat /tmp/cwtest/.codewhale/config.toml   # verify provider/api_key
```

Inside the container, `codewhale-reconfigure` re-runs this from the terminal.

#### Authentication

Verify the generated config is recognized:

```bash
CODEWHALE_HOME=/tmp/cwtest/.codewhale codewhale auth status
# deepseek should show status "config" (set)
```

#### ha-mcp

Registered by writing an argv-form entry (command+args+env) into `$CODEWHALE_HOME/mcp.json` — see `scripts/setup-ha-mcp.sh`.
Check with `codewhale mcp list` (config in `$CODEWHALE_HOME/mcp.json`).

### Common Issues & Solutions

- **Port already in use**: run on another port with `-p 7682:7681`.
- **aarch64 binary won't run**: Codewhale's arm64 binary requires glibc ≥ 2.39
  (provided by the Ubuntu 24.04 base). Verify with `codewhale-doctor` / `ldd --version`.
- **Images not on GHCR**: the `Publish Images` workflow pushes on changes to
  `codewhale-terminal/**` on `main`; run it manually via
  `gh workflow run publish-images.yml` if needed.

### Cleanup

```bash
podman stop test-codewhale-dev && podman rm test-codewhale-dev
podman rmi local/codewhale-terminal:test
```

## Production Deployment

Release flow: bump `version:` in `codewhale-terminal/config.yaml`, add a
`CHANGELOG.md` entry, then tag and push — the `Release` workflow validates the
tag against `config.yaml` and the `Publish Images` workflow rebuilds the GHCR
images.

```bash
git tag v0.1.1 && git push origin v0.1.1
```
