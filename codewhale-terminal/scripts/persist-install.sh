#!/bin/bash
#
# persist-install - Install packages that persist across container restarts
#
# Usage:
#   persist-install apt <package1> [package2] ...  - Install apt packages
#   persist-install pip <package1> [package2] ...  - Install pip packages
#   persist-install list                           - List persistent packages
#   persist-install help                           - Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config file for tracking installed packages (persisted in /data)
PERSIST_CONFIG="/data/persistent-packages.json"

# Initialize config file if it doesn't exist
init_config() {
    if [ ! -f "$PERSIST_CONFIG" ]; then
        echo '{"apt_packages": [], "pip_packages": []}' > "$PERSIST_CONFIG"
    fi
}

# Show help message
show_help() {
    echo -e "${BLUE}persist-install${NC} - Install packages that persist across container restarts"
    echo ""
    echo "Usage:"
    echo "  persist-install apt <package1> [package2] ...  - Install apt packages"
    echo "  persist-install pip <package1> [package2] ...  - Install pip packages"
    echo "  persist-install list                           - List persistent packages"
    echo "  persist-install remove apt <package>           - Remove apt package from persistence"
    echo "  persist-install remove pip <package>           - Remove pip package from persistence"
    echo "  persist-install help                           - Show this help message"
    echo ""
    echo "Examples:"
    echo "  persist-install apt htop"
    echo "  persist-install pip requests pandas numpy"
    echo "  persist-install list"
    echo ""
    echo -e "${YELLOW}Note:${NC} Packages are installed immediately and will be reinstalled"
    echo "      automatically after container restarts."
}

# List installed packages
list_packages() {
    init_config

    echo -e "${BLUE}Persistent Packages${NC}"
    echo "==================="
    echo ""

    echo -e "${GREEN}apt Packages:${NC}"
    local apt_packages
    apt_packages=$(jq -r '.apt_packages[]' "$PERSIST_CONFIG" 2>/dev/null || echo "")
    if [ -z "$apt_packages" ]; then
        echo "  (none)"
    else
        echo "$apt_packages" | while read -r pkg; do
            echo "  - $pkg"
        done
    fi

    echo ""
    echo -e "${GREEN}Pip Packages:${NC}"
    local pip_packages
    pip_packages=$(jq -r '.pip_packages[]' "$PERSIST_CONFIG" 2>/dev/null || echo "")
    if [ -z "$pip_packages" ]; then
        echo "  (none)"
    else
        echo "$pip_packages" | while read -r pkg; do
            echo "  - $pkg"
        done
    fi

    echo ""
}

# Add package to persistent config
add_packages() {
    local manager="$1"
    shift

    if [ -z "$1" ]; then
        echo -e "${YELLOW}No packages specified.${NC}"
        echo "Usage: persist-install $manager <package1> [package2] ..."
        return 1
    fi

    init_config

    for package in "$@"; do
        if jq -e --arg manager "$manager" --arg pkg "$package" \
            ".${manager}_packages | index(\$pkg)" "$PERSIST_CONFIG" >/dev/null 2>&1; then
            echo -e "${YELLOW}Package already in persistent list: ${package}${NC}"
            continue
        fi

        # Install the package
        local install_output
        if [ "$manager" = "apt" ]; then
            install_output=$(apt-get update -qq && apt-get install -y --no-install-recommends "$package" 2>&1)
        elif [ "$manager" = "pip" ]; then
            install_output=$(pip3 install --break-system-packages --no-cache-dir "$package" 2>&1)
        else
            echo -e "${RED}Unknown package manager: ${manager}${NC}"
            return 1
        fi

        if [ $? -eq 0 ]; then
            # Save to persistent config
            jq --arg manager "$manager" --arg pkg "$package" \
                ".${manager}_packages += [\$pkg]" "$PERSIST_CONFIG" > "${PERSIST_CONFIG}.tmp"
            mv "${PERSIST_CONFIG}.tmp" "$PERSIST_CONFIG"
            echo -e "${GREEN}Installed and persisted: ${package}${NC}"
        else
            echo -e "${RED}Failed to install: ${package}${NC}"
            echo "$install_output" | tail -5
            return 1
        fi
    done
}

# Remove package from persistent config
remove_packages() {
    local manager="$1"
    shift

    if [ -z "$1" ]; then
        echo -e "${YELLOW}No packages specified.${NC}"
        echo "Usage: persist-install remove $manager <package>"
        return 1
    fi

    init_config

    for package in "$@"; do
        if jq --arg manager "$manager" --arg pkg "$package" \
            ".${manager}_packages = (.${manager}_packages | map(select(. != \$pkg)))" \
            "$PERSIST_CONFIG" > "${PERSIST_CONFIG}.tmp" 2>/dev/null; then
            mv "${PERSIST_CONFIG}.tmp" "$PERSIST_CONFIG"
            echo -e "${GREEN}Removed from persistent list: ${package}${NC}"
        else
            echo -e "${YELLOW}Package not in persistent list: ${package}${NC}"
        fi
    done
}

# Main dispatch
case "$1" in
    apt|pip)
        add_packages "$@"
        ;;
    remove)
        shift
        if [ -z "$1" ]; then
            show_help
            exit 1
        fi
        remove_packages "$@"
        ;;
    list)
        list_packages
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: ${1:-}${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
