#!/bin/bash

# Codewhale Terminal — Codewhale coding agent in a browser terminal (ttyd + tmux).
#
# Startup philosophy (same as claude-terminal): everything the terminal needs
# is baked into the image, and nothing on the boot path may depend on the
# network or block on input. Network work (Codewhale updates, HA context
# generation) happens in the background after the terminal is already up.
#
# Unlike claude-terminal this image has no s6-overlay/bashio (Ubuntu base),
# so this is plain bash: options come from /data/options.json via jq, and the
# Supervisor runs /run.sh as PID 1. `exec ttyd` at the end makes ttyd PID 1 so
# signals are handled properly.

set -e
set -o pipefail

# Used by the sourced codewhale-config.sh library below (crosses the source
# boundary, so shellcheck can not see the use)
# shellcheck disable=SC2034
CONFIG_FILE="/data/options.json"
CODEWHALE_HOME="${CODEWHALE_HOME:-/data/.codewhale}"

log() { echo "[codewhale-terminal] $*"; }

# Shared config generator (get_option, toml_escape, write_codewhale_config) —
# also used by the `codewhale-reconfigure` command
source /opt/scripts/codewhale-config.sh

# Initialize the environment using /data exclusively (HA best practice — the
# container filesystem is recreated on every restart)
init_environment() {
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"

    log "Initializing Codewhale environment in /data..."

    mkdir -p "$data_home" "$config_dir" "$cache_dir" "$state_dir" \
        "/data/.local/share" "$CODEWHALE_HOME"

    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"
    export CODEWHALE_HOME

    # The persistent Codewhale install (see update_codewhale) must win over
    # the copy bundled in the image
    export PATH="$data_home/.local/bin:$PATH"

    # Repoint the TUI binary at the persistent copy when one exists
    if [ -x "$data_home/.local/bin/codewhale-tui" ]; then
        export CODEWHALE_TUI_BIN="$data_home/.local/bin/codewhale-tui"
    fi

    # Install tmux configuration to the user home directory
    if [ -f "/opt/scripts/tmux.conf" ]; then
        cp /opt/scripts/tmux.conf "$data_home/.tmux.conf"
        chmod 644 "$data_home/.tmux.conf"
    fi

    # Persist the resolved env for scripts run inside the terminal
    cat > "$data_home/.codewhale-env" << EOF
export HOME="$data_home"
export CODEWHALE_HOME="$CODEWHALE_HOME"
export CODEWHALE_TUI_BIN="${CODEWHALE_TUI_BIN:-/usr/local/bin/codewhale-tui}"
EOF

    log "Environment initialized (HOME=${HOME}, CODEWHALE_HOME=${CODEWHALE_HOME})"
}
# Install user-facing commands into /usr/local/bin
setup_commands() {
    local entry name script
    for entry in \
        "welcome:/opt/scripts/welcome.sh" \
        "persist-install:/opt/scripts/persist-install.sh" \
        "ha-context:/opt/scripts/ha-context.sh" \
        "codewhale-doctor:/opt/scripts/health-check.sh" \
        "codewhale-reconfigure:/opt/scripts/reconfigure.sh"; do
        name="${entry%%:*}"
        script="${entry#*:}"
        if [ -f "$script" ]; then
            cp "$script" "/usr/local/bin/$name"
            chmod +x "/usr/local/bin/$name"
        else
            log "WARNING: script not found: $script"
        fi
    done
}

# A persistent Codewhale copy being executable (-x) is not the same as being
# runnable — a partially-updated or libc-incompatible binary would shadow the
# bundled copy and take the terminal down with it. Treat "installed" and
# "actually runs" as separate facts.
native_codewhale_runs() {
    timeout 10 "$HOME/.local/bin/codewhale" --version >/dev/null 2>&1
}

# Remove a persistent copy that exists but cannot execute in this image so it
# stops shadowing the working bundled copy. Returns 0 if a usable persistent
# copy remains, 1 otherwise.
ensure_native_codewhale_usable() {
    [ -x "$HOME/.local/bin/codewhale" ] || return 1
    if native_codewhale_runs; then
        return 0
    fi
    log "WARNING: persistent Codewhale is present but fails to run; removing it and falling back to the bundled copy"
    rm -f "$HOME/.local/bin/codewhale" "$HOME/.local/bin/codewhale-tui"
    return 1
}

# Keep Codewhale current. The bundled copy is frozen at build time; a
# persistent copy in /data survives restarts and add-on updates, is refreshed
# in the background on each boot, and wins on PATH.
update_codewhale() {
    local native_usable=0
    ensure_native_codewhale_usable || native_usable=$?

    if [ "$(get_option 'codewhale_auto_update' 'true')" != "true" ]; then
        if [ "$native_usable" -eq 0 ]; then
            log "Codewhale auto-update disabled; using persistent Codewhale"
        else
            log "Codewhale auto-update disabled; using bundled Codewhale"
        fi
        return 0
    fi

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    # Seed the persistent copy from the bundled binaries if absent
    if [ "$native_usable" -ne 0 ] && [ -x /usr/local/bin/codewhale ]; then
        cp /usr/local/bin/codewhale "$bin_dir/codewhale"
        cp /usr/local/bin/codewhale-tui "$bin_dir/codewhale-tui"
        chmod 755 "$bin_dir/codewhale" "$bin_dir/codewhale-tui"
        export CODEWHALE_TUI_BIN="$bin_dir/codewhale-tui"
        log "Persistent Codewhale seeded from bundled copy"
    fi

    log "Checking for Codewhale updates in background"
    (
        # An update can pull a build this image's libc can't run; don't let
        # it linger on PATH for the next launch or reconnect.
        if ! "$bin_dir/codewhale" update >/dev/null 2>&1; then
            log "WARNING: Codewhale update failed; keeping current version"
        fi
        if [ -x "$bin_dir/codewhale" ] && ! native_codewhale_runs; then
            log "WARNING: updated Codewhale no longer runs in this image; removing it and falling back to the bundled copy"
            rm -f "$bin_dir/codewhale" "$bin_dir/codewhale-tui"
        fi
    ) &
}

# Install persistent packages from config and saved state
install_persistent_packages() {
    local persist_config="/data/persistent-packages.json"
    local apt_packages="" pip_packages=""

    local config_apt config_pip
    config_apt=$(get_option 'persistent_apt_packages' '')
    config_pip=$(get_option 'persistent_pip_packages' '')
    [ -n "$config_apt" ] && apt_packages="$config_apt"
    [ -n "$config_pip" ] && pip_packages="$config_pip"

    if [ -f "$persist_config" ]; then
        local local_apt local_pip
        local_apt=$(jq -r '.apt_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        local_pip=$(jq -r '.pip_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        [ -n "$local_apt" ] && apt_packages="$apt_packages $local_apt"
        [ -n "$local_pip" ] && pip_packages="$pip_packages $local_pip"
    fi

    # Trim whitespace and remove duplicates
    apt_packages=$(echo "$apt_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
    pip_packages=$(echo "$pip_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    if [ -n "$apt_packages" ]; then
        log "Installing persistent apt packages: $apt_packages"
        # shellcheck disable=SC2086
        if apt-get update -qq && apt-get install -y --no-install-recommends $apt_packages; then
            log "apt packages installed successfully"
        else
            log "WARNING: some apt packages failed to install"
        fi
    fi

    if [ -n "$pip_packages" ]; then
        log "Installing persistent pip packages: $pip_packages"
        # shellcheck disable=SC2086
        if pip3 install --break-system-packages --no-cache-dir $pip_packages; then
            log "pip packages installed successfully"
        else
            log "WARNING: some pip packages failed to install"
        fi
    fi
}

# Generate Home Assistant context file (AGENTS.md) for Codewhale sessions —
# background, because a slow Supervisor API must never delay the terminal
generate_ha_context() {
    if [ "$(get_option 'ha_smart_context' 'true')" != "true" ]; then
        log "HA Smart Context disabled in configuration"
        return 0
    fi

    if [ -f /usr/local/bin/ha-context ]; then
        log "Generating Home Assistant context in background"
        (/usr/local/bin/ha-context >/dev/null 2>&1 || true) &
    fi
}

# Register ha-mcp (Home Assistant MCP Server) with Codewhale
# Repository: https://github.com/homeassistant-ai/ha-mcp
setup_ha_mcp() {
    if [ "$(get_option 'enable_ha_mcp' 'true')" != "true" ]; then
        log "ha-mcp integration disabled in configuration"
        return 0
    fi

    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        log "WARNING: SUPERVISOR_TOKEN not available - ha-mcp setup skipped"
        return 0
    fi

    if ! command -v uvx >/dev/null 2>&1; then
        log "WARNING: uvx not found - ha-mcp setup skipped"
        return 0
    fi

    local version
    version=$(get_option 'ha_mcp_version' '7.11.0')

    log "Setting up ha-mcp (Home Assistant MCP Server)..."
    codewhale mcp remove home-assistant >/dev/null 2>&1 || true

    # ha-mcp >= 4.x requires CPython 3.13 exactly, which Ubuntu 24.04 does
    # not ship — uv provisions a managed 3.13 build (persisted under /data,
    # so it downloads once). The command runs via /usr/bin/env so it works
    # whether Codewhale executes it directly or through a shell.
    if codewhale mcp add home-assistant \
        --command "env HOMEASSISTANT_URL=http://supervisor/core HOMEASSISTANT_TOKEN=${SUPERVISOR_TOKEN} uvx --python 3.13 --index-strategy unsafe-best-match ha-mcp@${version}" >/dev/null 2>&1; then
        log "ha-mcp ${version} configured for Codewhale"

        # Pre-warm the uv environment in the background (managed Python
        # download + dependency resolution) so the first MCP connection
        # doesn't hit the client startup timeout
        (uvx --python 3.13 --index-strategy unsafe-best-match \
            --from "ha-mcp@${version}" python -c "" >/dev/null 2>&1 || true) &
        log "Pre-warming ha-mcp environment in background"
    else
        log "WARNING: failed to configure ha-mcp - continuing without MCP integration"
    fi
}

# Build extra flags for every Codewhale launch. The value is word-split;
# quoted multi-word arguments are not re-parsed (documented limitation).
build_codewhale_flags() {
    local flags=""
    local extra
    extra=$(get_option 'codewhale_extra_args' '')
    if [ -n "$extra" ] && [ "$extra" != "null" ]; then
        flags="$extra"
    fi
    echo "$flags"
}

# Determine the command ttyd runs for each client connection
get_launch_command() {
    local flags="$1"

    if [ "$(get_option 'auto_launch_codewhale' 'true')" = "true" ]; then
        # tmux -A attaches to the live session on browser reconnects and HA
        # navigation instead of stacking new ones
        echo "tmux new-session -A -s codewhale 'codewhale${flags:+ $flags}'"
    else
        # Shell mode: banner + interactive bash, still inside tmux for
        # reconnect persistence. Run 'codewhale' manually when ready.
        echo "tmux new-session -A -s codewhale '/usr/local/bin/welcome --shell'"
    fi
}

# Start main web terminal
start_web_terminal() {
    local port=7681
    local flags
    flags=$(build_codewhale_flags)

    if [ "$(get_option 'dangerously_skip_permissions' 'false')" = "true" ]; then
        log "WARNING: =========================================================="
        log "WARNING: dangerously_skip_permissions is ENABLED."
        log "WARNING: Codewhale will run tools without asking for confirmation."
        log "WARNING: It has write access to /config and can control Home"
        log "WARNING: Assistant through the Supervisor API and MCP."
        log "WARNING: =========================================================="
    fi

    local launch_command
    launch_command=$(get_launch_command "$flags")

    log "Starting web terminal on port ${port} (auto_launch_codewhale=$(get_option 'auto_launch_codewhale' 'true'))"

    # Terminal theme - dark palette with cyan accents (Codewhale)
    local ttyd_theme='{"background":"#0f1420","foreground":"#c0caf5","cursor":"#22d3ee","cursorAccent":"#0f1420","selectionBackground":"#164e63","selectionForeground":"#c0caf5","black":"#15161e","red":"#f7768e","green":"#9ece6a","yellow":"#e0af68","blue":"#7aa2f7","magenta":"#bb9af7","cyan":"#22d3ee","white":"#a9b1d6","brightBlack":"#414868","brightRed":"#f7768e","brightGreen":"#9ece6a","brightYellow":"#e0af68","brightBlue":"#7aa2f7","brightMagenta":"#bb9af7","brightCyan":"#22d3ee","brightWhite":"#c0caf5"}'

    # Run ttyd with keepalive configuration to prevent WebSocket disconnects
    # (same settings as claude-terminal: see their issue #24)
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        --ping-interval 30 \
        --client-option enableReconnect=true \
        --client-option reconnect=10 \
        --client-option reconnectInterval=5 \
        --client-option "theme=${ttyd_theme}" \
        --client-option fontSize=14 \
        bash -c "$launch_command"
}

# Main execution
main() {
    log "Starting Codewhale Terminal add-on..."

    init_environment
    write_codewhale_config
    setup_commands
    update_codewhale
    install_persistent_packages
    generate_ha_context
    setup_ha_mcp
    start_web_terminal
}

# Execute main function
main "$@"
