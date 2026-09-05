#!/bin/bash

# ucloud-connect: Utility to update SSH config port and connect to ucloud via VSCode
# Usage: ucloud-connect [port-number]

set -e

CONFIG_FILE="$HOME/.ssh/config"
BACKUP_DIR="$HOME/.ssh/config_backups"
HOST_NAME="ucloud"
REMOTE_DIR="/work"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup the config file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/config_$TIMESTAMP"
echo -e "${GREEN}Creating backup...${NC}"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Get port number
if [ -n "$1" ]; then
    PORT_NUMBER="$1"
else
    echo -e "${YELLOW}Enter the new port number for ucloud:${NC}"
    read -r PORT_NUMBER
fi

# Validate port number
if ! [[ "$PORT_NUMBER" =~ ^[0-9]+$ ]] || [ "$PORT_NUMBER" -lt 1 ] || [ "$PORT_NUMBER" -gt 65535 ]; then
    echo -e "${RED}Error: Invalid port number. Must be between 1 and 65535.${NC}"
    exit 1
fi

echo -e "${GREEN}Updating SSH config with port $PORT_NUMBER...${NC}"

# Update the config file
# We need to find the ucloud host section and update only its Port line
awk -v port="$PORT_NUMBER" '
BEGIN { in_ucloud = 0 }
/^Host ucloud$/ { in_ucloud = 1; print; next }
/^Host / { in_ucloud = 0 }
in_ucloud && /^  Port / { print "  Port " port; next }
{ print }
' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"

mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo -e "${GREEN}✓ SSH config updated${NC}"

# Display the updated configuration
echo -e "\n${YELLOW}Updated ucloud configuration:${NC}"
awk '/^Host ucloud$/,/^Host / { if (/^Host / && !/^Host ucloud$/) exit; print }' "$CONFIG_FILE"

# Connect to ucloud via VSCode
echo -e "\n${GREEN}Connecting to ucloud via VSCode...${NC}"
code --folder-uri "vscode-remote://ssh-remote+$HOST_NAME$REMOTE_DIR"

echo -e "${GREEN}✓ Connection initiated!${NC}"
