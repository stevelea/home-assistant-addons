#!/bin/bash

# Codewhale Terminal banner — compact, non-blocking header with version and
# tips. With --shell, drops into an interactive bash afterwards (shell mode).
# Runs inside ttyd/tmux (user-visible) — plain bash.

CYAN='\033[38;2;34;211;238m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

version=$(cat /opt/scripts/addon-version 2>/dev/null || echo "unknown")

echo ""
echo -e "  ${CYAN}Codewhale Terminal${NC}  ${DIM}v${version} · Home Assistant add-on${NC}"
echo ""
echo -e "  ${WHITE}codewhale${NC}          start the Codewhale coding agent  ${DIM}(-c continue · -r resume a session)${NC}"
echo -e "  ${WHITE}codewhale-doctor${NC}   diagnose network, auth, and environment issues"
echo -e "  ${WHITE}codewhale-reconfigure${NC}  regenerate config.toml from the add-on options"
echo -e "  ${WHITE}persist-install${NC}    install apt/pip packages that survive restarts"
echo -e "  ${WHITE}ha-context${NC}         refresh the Home Assistant context file for Codewhale"
echo ""

if [ "$1" = "--shell" ]; then
    exec bash
fi
