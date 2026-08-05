#!/bin/bash

# codewhale-config.sh — bootstrap ~/.codewhale/config.toml on FIRST boot only.
#
# After the first boot, Codewhale owns this file: provider, model, base_url,
# reasoning_effort and extra providers are configured inside the terminal
# (codewhale auth set, the /provider onboarding, or by editing the file) and
# persist in /data. The add-on never rewrites it, so option changes can't
# clobber Codewhale's settings.
#
# Sourced by run.sh (boot) and reconfigure.sh (manual); safe to run directly:
# executes the writer.

CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"
CODEWHALE_HOME="${CODEWHALE_HOME:-/data/.codewhale}"

# Be self-sufficient when run directly (run.sh and reconfigure.sh also ensure
# this directory exists before sourcing us)
mkdir -p "$CODEWHALE_HOME"

# Read an option from /data/options.json with a default. Classifies by the
# actual JSON type: booleans are echoed literally, arrays are joined with
# spaces, everything else (strings, numbers) is echoed raw. Never sniffs the
# decoded value's prefix — a string that happens to start with "[" is not an
# array.
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

# Escape a value for use inside a double-quoted TOML string
toml_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

write_codewhale_config() {
    # Codewhale owns config.toml after first boot — never rewrite it.
    if [ -f "$CODEWHALE_HOME/config.toml" ]; then
        echo "[codewhale-terminal] config.toml exists — managed by Codewhale; leaving untouched"
        return 0
    fi

    # Bootstrap: a minimal config with the deepseek default. The api_key
    # option is a first-boot convenience; afterwards set/rotate keys inside
    # Codewhale (codewhale auth set --provider deepseek --api-key-stdin).
    local api_key
    api_key=$(get_option 'api_key' '')

    echo "[codewhale-terminal] First boot — bootstrapping Codewhale config (provider=deepseek)..."

    local tmp
    tmp=$(mktemp "${CODEWHALE_HOME}/config.toml.XXXXXX")

    {
        echo "# Bootstrap config written by the Codewhale Terminal add-on (first boot)."
        echo "# Codewhale owns this file from here on: configure provider/model/key with"
        echo "# 'codewhale auth set --provider <name> --api-key-stdin', the /provider"
        echo "# onboarding, or by editing this file."
        echo ""
        echo "provider = \"deepseek\""
        echo "auth_mode = \"api_key\""
        echo ""
        echo "[providers.deepseek]"
        [ -n "$api_key" ] && echo "api_key = \"$(toml_escape "$api_key")\""
        echo ""
    } > "$tmp"

    chmod 600 "$tmp"
    mv "$tmp" "$CODEWHALE_HOME/config.toml"
    chmod 600 "$CODEWHALE_HOME/config.toml"

    echo "[codewhale-terminal] Bootstrap config written to $CODEWHALE_HOME/config.toml"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    write_codewhale_config
fi
