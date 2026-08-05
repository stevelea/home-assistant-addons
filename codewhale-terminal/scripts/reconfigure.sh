#!/bin/bash

# codewhale-reconfigure — regenerate ~/.codewhale/config.toml from the
# current add-on options (provider, api_key, model, ...) and re-apply the
# ha-mcp registration. Run this after editing options without restarting.

CODEWHALE_HOME="${CODEWHALE_HOME:-/data/.codewhale}"
CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"

# Ensure the config directory exists (run.sh creates it at boot)
mkdir -p "$CODEWHALE_HOME"

# Reuse the same config writer that run.sh uses at boot
source /opt/scripts/codewhale-config.sh

write_codewhale_config || {
    echo "codewhale-reconfigure: config generation failed" >&2
    exit 1
}

# Re-apply the Home Assistant MCP registration with the current options
if [ -f /opt/scripts/setup-ha-mcp.sh ]; then
    source /opt/scripts/setup-ha-mcp.sh
    setup_ha_mcp_server || echo "codewhale-reconfigure: ha-mcp setup encountered issues (continuing)" >&2
fi

echo ""
echo "Done. Restart the running Codewhale session (exit and re-run 'codewhale')"
echo "for the new config to take effect."
