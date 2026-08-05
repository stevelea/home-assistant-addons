#!/bin/bash

# codewhale-config.sh — generate ~/.codewhale/config.toml from the add-on
# options in /data/options.json. Sourced by run.sh (boot) and
# reconfigure.sh (manual); safe to run directly: executes the writer.
#
# The file regenerates only when the relevant options changed (a hash of
# them is stored next to the config), so manual edits survive restarts
# unless the add-on options change.

CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"
CODEWHALE_HOME="${CODEWHALE_HOME:-/data/.codewhale}"

# Be self-sufficient when run directly (run.sh and reconfigure.sh also ensure
# this directory exists before sourcing us)
mkdir -p "$CODEWHALE_HOME"

# Read an option from /data/options.json with a default. Classifies by the
# actual JSON type: booleans are echoed literally, arrays are joined with
# spaces, everything else (strings, numbers) is echoed raw. Never sniffs the
# decoded value's prefix — a string that happens to start with "[" is not an
# array (e.g. extra_config).
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
    local provider api_key base_url model reasoning skip
    provider=$(get_option 'provider' 'deepseek')
    api_key=$(get_option 'api_key' '')
    base_url=$(get_option 'base_url' '')
    model=$(get_option 'default_text_model' '')
    reasoning=$(get_option 'reasoning_effort' 'auto')
    skip=$(get_option 'dangerously_skip_permissions' 'false')

    # Provider names become [providers.<name>] tables — restrict to safe chars
    if ! [[ "$provider" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "[codewhale-terminal] ERROR: invalid provider name '$provider' (only [a-zA-Z0-9_-] allowed)" >&2
        return 1
    fi

    local fingerprint
    fingerprint=$(printf '%s|%s|%s|%s|%s|%s' \
        "$provider" "$api_key" "$base_url" "$model" "$reasoning" "$skip" \
        | sha256sum | cut -d' ' -f1)

    local marker="$CODEWHALE_HOME/.config-hash"
    if [ -f "$CODEWHALE_HOME/config.toml" ] && [ -f "$marker" ] \
        && [ "$(cat "$marker" 2>/dev/null)" = "$fingerprint" ]; then
        echo "[codewhale-terminal] Codewhale config up to date (provider=${provider})"
        return 0
    fi

    echo "[codewhale-terminal] Writing Codewhale config (provider=${provider})..."

    local tmp
    tmp=$(mktemp "${CODEWHALE_HOME}/config.toml.XXXXXX")

    {
        echo "# Managed by the Codewhale Terminal add-on."
        echo "# Regenerate from add-on options with: codewhale-reconfigure"
        echo ""
        echo "provider = \"$(toml_escape "$provider")\""
        echo "auth_mode = \"api_key\""
        [ -n "$model" ] && echo "default_text_model = \"$(toml_escape "$model")\""
        echo "reasoning_effort = \"$(toml_escape "$reasoning")\""
        if [ "$skip" = "true" ]; then
            echo "# dangerously_skip_permissions: never ask before running tools"
            echo "approval_policy = \"never\""
        fi
        echo ""
        echo "[providers.$(toml_escape "$provider")]"
        [ -n "$api_key" ] && echo "api_key = \"$(toml_escape "$api_key")\""
        [ -n "$base_url" ] && echo "base_url = \"$(toml_escape "$base_url")\""
        echo ""
    } > "$tmp"

    # Append user-provided extra TOML (additional providers etc.)
    local extra
    extra=$(get_option 'extra_config' '')
    if [ -n "$extra" ] && [ "$extra" != "null" ]; then
        printf '\n%s\n' "$extra" >> "$tmp"
    fi

    chmod 600 "$tmp"
    mv "$tmp" "$CODEWHALE_HOME/config.toml"
    chmod 600 "$CODEWHALE_HOME/config.toml"
    printf '%s' "$fingerprint" > "$marker"
    chmod 600 "$marker"

    echo "[codewhale-terminal] Codewhale config written to $CODEWHALE_HOME/config.toml"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    write_codewhale_config
fi
