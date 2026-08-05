#!/bin/bash

# setup-ha-mcp.sh — register ha-mcp (Home Assistant MCP Server) with
# Codewhale. Sourced by run.sh (boot) and reconfigure.sh; safe to run
# directly. Repository: https://github.com/homeassistant-ai/ha-mcp
#
# Registration format matters: Codewhale spawns the mcp.json `command` as a
# single executable and passes `env` values literally to the child. A
# shell-style one-liner in `command` (e.g. "env A=1 B=2 uvx ...") fails with
# "MCP stdio spawn failed ... No such file or directory". We therefore write
# the entry directly with argv-form command/args and a literal env object.

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

    mkdir -p "$CODEWHALE_HOME"
    local mcp_file="$CODEWHALE_HOME/mcp.json"

    # Ensure mcp.json exists (Codewhale creates it lazily; be explicit so we
    # can merge into it deterministically)
    if [ ! -f "$mcp_file" ]; then
        printf '%s\n' \
            '{"timeouts":{"connect_timeout":10,"execute_timeout":60,"read_timeout":120},"servers":{}}' \
            > "$mcp_file"
    fi

    # ha-mcp >= 4.x requires CPython 3.13 exactly, which Ubuntu 24.04 does
    # not ship — uv provisions a managed 3.13 build (persisted under /data,
    # so it downloads once). The env values are passed literally to the
    # child, so HOMEASSISTANT_TOKEN carries the Supervisor token at launch.
    if jq --arg token "${SUPERVISOR_TOKEN}" --arg ver "$version" \
        '.servers["home-assistant"] = {
            "command": "uvx",
            "args": ["--python","3.13","--index-strategy","unsafe-best-match","ha-mcp@\($ver)"],
            "env": {
                "HOMEASSISTANT_URL": "http://supervisor/core",
                "HOMEASSISTANT_TOKEN": $token
            },
            "disabled": false
        }' "$mcp_file" > "${mcp_file}.tmp" 2>/dev/null; then
        mv "${mcp_file}.tmp" "$mcp_file"
        chmod 600 "$mcp_file"
        echo "[codewhale-terminal] ha-mcp ${version} configured for Codewhale"

        # Pre-warm the uv environment in the background (managed Python
        # download + dependency resolution) so the first MCP connection
        # doesn't hit the client startup timeout
        (uvx --python 3.13 --index-strategy unsafe-best-match \
            --from "ha-mcp@${version}" python -c "" >/dev/null 2>&1 || true) &
        echo "[codewhale-terminal] Pre-warming ha-mcp environment in background"
    else
        rm -f "${mcp_file}.tmp"
        echo "[codewhale-terminal] WARNING: failed to configure ha-mcp - continuing without MCP integration"
    fi
}

# Run setup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ha_mcp_server
fi
