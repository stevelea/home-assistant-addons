#!/bin/bash

# setup-ha-mcp.sh — register ha-mcp (Home Assistant MCP Server) with
# Codewhale. Sourced by run.sh (boot) and reconfigure.sh; safe to run
# directly. Repository: https://github.com/homeassistant-ai/ha-mcp

CODEWHALE_HOME="${CODEWHALE_HOME:-/data/.codewhale}"
CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"

# Read an option with a default (same semantics as codewhale-config.sh).
# Classifies by actual JSON type — never sniffs the decoded value's prefix,
# so a string starting with "[" is not mistaken for an array.
get_option() {
    local key="$1"
    local default="$2"
    local type
    type=$(jq -r --arg key "$key" 'if has($key) then (.[$key] | type) else "null" end' "$CONFIG_FILE" 2>/dev/null || echo "null")
    case "$type" in
        "null")
            echo "$default"
            ;;
        "array")
            jq -r --arg key "$key" '.[$key][]?' "$CONFIG_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
            ;;
        *)
            jq -r --arg key "$key" '.[$key]' "$CONFIG_FILE" 2>/dev/null
            ;;
    esac
}

setup_ha_mcp_server() {
    if [ "$(get_option 'enable_ha_mcp' 'true')" != "true" ]; then
        echo "[codewhale-terminal] ha-mcp integration disabled in configuration"
        return 0
    fi

    # Check for supervisor token (required for HA API access)
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        echo "[codewhale-terminal] WARNING: SUPERVISOR_TOKEN not available - ha-mcp setup skipped"
        return 0
    fi

    # Check if uv/uvx is available
    if ! command -v uvx >/dev/null 2>&1; then
        echo "[codewhale-terminal] WARNING: uvx not found - ha-mcp setup skipped"
        return 0
    fi

    local version
    version=$(get_option 'ha_mcp_version' '7.11.0')

    # Remove existing ha-mcp configuration if present (to ensure clean state)
    codewhale mcp remove home-assistant >/dev/null 2>&1 || true

    # ha-mcp >= 4.x requires CPython 3.13 exactly, which Ubuntu 24.04 does
    # not ship — uv provisions a managed 3.13 build (persisted under /data
    # via XDG_DATA_HOME, so it downloads once). The command runs through
    # /usr/bin/env so the env prefix works whether Codewhale executes the
    # command directly or via a shell.
    if codewhale mcp add home-assistant \
        --command "env HOMEASSISTANT_URL=http://supervisor/core HOMEASSISTANT_TOKEN=${SUPERVISOR_TOKEN} uvx --python 3.13 --index-strategy unsafe-best-match ha-mcp@${version}" >/dev/null 2>&1; then
        echo "[codewhale-terminal] ha-mcp ${version} configured for Codewhale"

        # Pre-warm the uv environment in the background (managed Python
        # download + dependency resolution) so the first MCP connection
        # doesn't hit the client startup timeout
        (uvx --python 3.13 --index-strategy unsafe-best-match \
            --from "ha-mcp@${version}" python -c "" >/dev/null 2>&1 || true) &
        echo "[codewhale-terminal] Pre-warming ha-mcp environment in background"
    else
        echo "[codewhale-terminal] WARNING: failed to configure ha-mcp - continuing without MCP integration"
    fi
}

# Run setup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ha_mcp_server
fi
