#!/bin/bash

# tmux-status.sh — lightweight status bar data for Codewhale Terminal
# Called by tmux every status-interval seconds. Must be fast (<1s).

# --- Auth status ---
auth_status() {
    local config="${CODEWHALE_HOME:-$HOME/.codewhale}/config.toml"

    # An api_key in config.toml (or a provider *_API_KEY env var) counts as
    # configured. Existence alone doesn't mean the key is valid, so a present
    # key shows green and a missing one shows red.
    if [ -f "$config" ] && grep -q '^api_key\s*=\s*"' "$config" 2>/dev/null; then
        echo "#[fg=colour114]Auth"
        return
    fi

    if env | grep -qE '^(DEEPSEEK|OPENAI|OPENROUTER|MOONSHOT|OLLAMA|XAI|ANTHROPIC|ZHIPU|GLM|KIMI|SILICONFLOW|STEPFUN|MINIMAX|NVIDIA|FIREWORKS|TOGETHER|NOVITA|ARCEE|HF|HUGGINGFACE|DEEPINFRA|QIANFAN|VOLCENGINE|WANJIE|ATLASCLOUD|XIAOMI)_API_KEY=' 2>/dev/null; then
        echo "#[fg=colour114]Auth"
        return
    fi

    if [ -f "$config" ]; then
        echo "#[fg=colour208]Auth"
    else
        echo "#[fg=colour203]Auth"
    fi
}

# --- HA connection status ---
ha_status() {
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        echo "#[fg=colour245]HA"
        return
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 2 \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "http://supervisor/core/api/" 2>/dev/null)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "#[fg=colour114]HA"
    else
        echo "#[fg=colour208]HA"
    fi
}

# --- Build output ---
auth=$(auth_status)
ha=$(ha_status)
datetime=$(date '+%a %m-%d %H:%M')

echo "${auth} #[fg=colour245]| ${ha} #[fg=colour245]| #[fg=colour252]${datetime}"
