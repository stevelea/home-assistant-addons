#!/bin/bash

# Health check / diagnostics for the Codewhale Terminal add-on.
# Installed as `codewhale-doctor`; run it inside the terminal to validate
# the environment and get troubleshooting info. Plain bash (no bashio).

CODEWHALE_HOME="${CODEWHALE_HOME:-/data/.codewhale}"
CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"
PASS=0
FAIL=0

report() {
    local status="$1"
    local msg="$2"
    case "$status" in
        pass) PASS=$((PASS + 1)); echo -e "  \033[0;32m✓\033[0m $msg" ;;
        warn) echo -e "  \033[1;33m⚠\033[0m $msg" ;;
        fail) FAIL=$((FAIL + 1)); echo -e "  \033[0;31m✗\033[0m $msg" ;;
    esac
}

check_system_resources() {
    echo "=== System Resources ==="

    local mem_total mem_free
    mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    mem_free=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    report pass "Memory: ${mem_free}MB free of ${mem_total}MB total"
    [ "$mem_free" -lt 256 ] 2>/dev/null && report warn "Less than 256MB available — may cause issues"

    local disk_free
    disk_free=$(df -m /data 2>/dev/null | tail -1 | awk '{print $4}')
    report pass "Disk space in /data: ${disk_free}MB free"
    [ -n "$disk_free" ] && [ "$disk_free" -lt 100 ] 2>/dev/null && report warn "Less than 100MB free in /data"
}

check_data_writable() {
    echo "=== /data Permissions ==="
    if [ -w /data ]; then
        report pass "/data is writable"
    else
        report fail "/data is not writable"
        return 1
    fi
    if mkdir -p "$CODEWHALE_HOME" 2>/dev/null; then
        report pass "Can write to $CODEWHALE_HOME"
    else
        report fail "Cannot write to $CODEWHALE_HOME"
        return 1
    fi
}

check_binaries() {
    echo "=== Codewhale Binaries ==="
    local bin
    for bin in codewhale codewhale-tui tmux ttyd jq git curl uv uvx; do
        if command -v "$bin" >/dev/null 2>&1; then
            report pass "$bin: $(command -v "$bin")"
        else
            report warn "$bin: not found"
        fi
    done

    echo "=== Codewhale Version ==="
    local cw_version
    if cw_version=$(timeout 10 codewhale --version 2>&1); then
        report pass "codewhale $cw_version"
    else
        report fail "codewhale --version failed: $cw_version"
    fi

    echo "=== libc ==="
    ldd --version 2>&1 | head -1
}

check_config() {
    echo "=== Codewhale Config ==="
    if [ -f "$CODEWHALE_HOME/config.toml" ]; then
        report pass "config.toml present ($CODEWHALE_HOME/config.toml)"
        local provider
        provider=$(grep -E '^provider\s*=' "$CODEWHALE_HOME/config.toml" 2>/dev/null | head -1 | sed 's/.*= *"//;s/"//')
        [ -n "$provider" ] && report pass "provider: ${provider}"
        if grep -q '^api_key\s*=\s*"' "$CODEWHALE_HOME/config.toml" 2>/dev/null; then
            report pass "API key present in config"
        else
            report warn "No api_key found in config.toml — configure it inside Codewhale: codewhale auth set --provider <name> --api-key-stdin"
        fi
    else
        report fail "config.toml missing — run codewhale-reconfigure or restart the add-on"
    fi

    if [ -f "$CODEWHALE_HOME/mcp.json" ] && jq -e '.servers.home-assistant' "$CODEWHALE_HOME/mcp.json" >/dev/null 2>&1; then
        report pass "ha-mcp server registered"
    else
        report warn "ha-mcp server not registered (enable_ha_mcp option)"
    fi
}

check_ha_connectivity() {
    echo "=== Home Assistant Connectivity ==="
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        report warn "SUPERVISOR_TOKEN not set — running outside a Home Assistant add-on?"
        return 0
    fi
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "http://supervisor/core/api/" 2>/dev/null)
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        report pass "Supervisor API reachable (HTTP ${http_code})"
    else
        report fail "Supervisor API unreachable (HTTP ${http_code:-timeout})"
    fi
}

main() {
    echo "Codewhale Terminal — diagnostics"
    echo "================================="
    echo ""

    check_system_resources
    echo ""
    check_data_writable
    echo ""
    check_binaries
    echo ""
    check_config
    echo ""
    check_ha_connectivity
    echo ""
    echo "================================="
    echo -e "Result: \033[0;32m${PASS} passed\033[0m, \033[0;31m${FAIL} failed\033[0m"
    if [ "$FAIL" -gt 0 ]; then
        echo "Some checks failed — see the messages above."
        exit 1
    fi
    echo "All checks passed."
}

main "$@"
