#!/bin/bash

# ============================================================================
# ucloud-connect: Utility for human users to connect to UCloud HPC
# ============================================================================
# Purpose:
#   Updates the "Host ucloud" block in ~/.ssh/config with the dynamic port
#   assigned to a running UCloud job, sets up tunneling / ProxyJump, and
#   initiates a VSCode Remote-SSH session (or CLI SSH).
#
# Supports two network environments:
#   1. Statens IT (SIT) managed equipment (SSI network):
#      Outbound access to high ports is restricted; requires ProxyJump
#      via uGerm HPC (login.ugerm.dksund.dk).
#   2. Non-SIT / unrestricted equipment:
#      Direct connection to ssh.cloud.sdu.dk.
#
# NOTE FOR AI AGENTS:
#   This script is intended for HUMAN interaction. Automated AI agents should
#   NOT mutate ~/.ssh/config. Instead, capture the dynamic port in memory and
#   invoke SSH directly with command-line flags:
#     - Direct:  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p <PORT> ucloud@ssh.cloud.sdu.dk '<cmd>'
#     - SIT:     ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J <UGERM_USER>@login.ugerm.dksund.dk -p <PORT> ucloud@ssh.cloud.sdu.dk '<cmd>'
# ============================================================================

set -e

CONFIG_FILE="$HOME/.ssh/config"
BACKUP_DIR="$HOME/.ssh/config_backups"
HOST_NAME="ucloud-vm"
REMOTE_DIR="/work"
DEFAULT_UGERM_USER="${UGERM_USER:-hutu}"
UGERM_HOST="login.ugerm.dksund.dk"
DEFAULT_FORWARD="8888 localhost:8888"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    cat <<EOF
Usage: connect_ucloud [options] [vm|k8s] [port-number]

Utility for human users to configure ~/.ssh/config for UCloud jobs and launch VSCode.

Arguments:
  port-number            UCloud SSH port from the job progress page (1-65535)

Modes:
  -s, --sit              Statens IT (SIT) mode: enable ProxyJump via uGerm
  -d, --direct           Direct (Non-SIT) mode: direct connection without ProxyJump

Target Host:
  vm, --vm               Target 'Host ucloud-vm' in ~/.ssh/config (Virtual Machine, default)
  k8s, --k8s            Target 'Host ucloud-k8s' in ~/.ssh/config (Kubernetes container)
  --name HOST            Target arbitrary 'Host <HOST>' in ~/.ssh/config
Options:
  -u, --ugerm-user USER  uGerm username for ProxyJump (default: \${UGERM_USER:-${DEFAULT_UGERM_USER}})
  -j, --proxyjump TARGET Explicit ProxyJump target (default: USER@${UGERM_HOST})
  -f, --forward SPEC     Port forwarding spec (default: '${DEFAULT_FORWARD}')
      --no-forward       Disable LocalForward
  -n, --no-code          Update SSH config only; do not launch VSCode
  -h, --help             Show this help message

Environment Variables:
  UCLOUD_SIT             Set to '1' for SIT mode by default, '0' for direct mode
  UGERM_USER             Default username for uGerm ProxyJump

Examples:
  # Interactive wizard (prompts for target environment and port)
  connect_ucloud

  # Positional target and port
  connect_ucloud vm 2523
  connect_ucloud k8s 2820

  # SIT mode on SSI network
  connect_ucloud --sit vm 2523

  # Direct mode without ProxyJump
  connect_ucloud --direct vm 2523

  # Update SSH config without launching VSCode
  connect_ucloud --no-code vm 2523
EOF
}

# Parse options
MODE=""
PORT_NUMBER=""
HOST_EXPLICIT=false
UGERM_USER="$DEFAULT_UGERM_USER"
CUSTOM_PROXYJUMP=""
LOCAL_FORWARD="$DEFAULT_FORWARD"
LAUNCH_CODE=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--sit)
            MODE="sit"
            shift
            ;;
        -d|--direct|--no-sit)
            MODE="direct"
            shift
            ;;
        vm|--vm)
            HOST_NAME="ucloud-vm"
            HOST_EXPLICIT=true
            shift
            ;;
        k8s|--k8s)
            HOST_NAME="ucloud-k8s"
            HOST_EXPLICIT=true
            shift
            ;;
        --name)
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                HOST_NAME="$2"
                HOST_EXPLICIT=true
                shift 2
            else
                echo -e "${RED}Error: --name requires a host name${NC}" >&2
                exit 1
            fi
            ;;
        -u|--ugerm-user|--user)
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                UGERM_USER="$2"
                shift 2
            else
                echo -e "${RED}Error: --ugerm-user requires a username${NC}" >&2
                exit 1
            fi
            ;;
        -j|--proxyjump)
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                CUSTOM_PROXYJUMP="$2"
                shift 2
            else
                echo -e "${RED}Error: --proxyjump requires a target${NC}" >&2
                exit 1
            fi
            ;;
        -f|--forward)
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                LOCAL_FORWARD="$2"
                shift 2
            else
                echo -e "${RED}Error: --forward requires a forwarding specification${NC}" >&2
                exit 1
            fi
            ;;
        --no-forward)
            LOCAL_FORWARD=""
            shift
            ;;
        -n|--no-code|--no-launch)
            LAUNCH_CODE=false
            shift
            ;;
        *)
            if [[ -z "$PORT_NUMBER" && "$1" =~ ^[0-9]+$ ]]; then
                PORT_NUMBER="$1"
                shift
            else
                echo -e "${RED}Error: Unknown argument '$1'${NC}" >&2
                show_help
                exit 1
            fi
            ;;
    esac
done

# Ensure SSH config directory and file exist
mkdir -p "$HOME/.ssh"
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
fi

# Detect mode if not explicitly specified
if [ -z "$MODE" ]; then
    if [ "${UCLOUD_SIT:-}" = "1" ]; then
        MODE="sit"
    elif [ "${UCLOUD_SIT:-}" = "0" ]; then
        MODE="direct"
    elif grep -A 10 "^[[:space:]]*Host[[:space:]]\+ucloud" "$CONFIG_FILE" 2>/dev/null | grep -q "ProxyJump"; then
        # Existing config uses ProxyJump -> maintain SIT mode
        MODE="sit"
    elif [[ "$(whoami)" =~ ^[A-Z0-9]{7}$ ]] || hostname 2>/dev/null | grep -qi "ssi"; then
        # Running on SSI / Statens IT machine by default
        MODE="sit"
    else
        MODE="direct"
    fi
fi

# Determine ProxyJump setting
if [ "$MODE" = "sit" ]; then
    if [ -n "$CUSTOM_PROXYJUMP" ]; then
        PROXY_JUMP="$CUSTOM_PROXYJUMP"
    else
        PROXY_JUMP="${UGERM_USER}@${UGERM_HOST}"
    fi
    echo -e "${CYAN}[Mode: Statens IT (SIT) - ProxyJump via ${PROXY_JUMP}]${NC}"
else
    PROXY_JUMP=""
    echo -e "${CYAN}[Mode: Direct (Non-SIT) - Direct connection to ssh.cloud.sdu.dk]${NC}"
fi

# Backup the config file before touching it
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/config_$TIMESTAMP"
echo -e "${GREEN}Creating backup...${NC}"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Get port number interactively if not provided
if [ "$HOST_EXPLICIT" = false ]; then
    echo -e "${YELLOW}Select target environment:${NC}"
    echo -e "  ${CYAN}1)${NC} Virtual Machine (ucloud-vm) [default]"
    echo -e "  ${CYAN}2)${NC} Kubernetes Container (ucloud-k8s)"
    read -r -p "Enter choice [1/2, default=1]: " HOST_CHOICE
    case "$HOST_CHOICE" in
        2|k8s|container)
            HOST_NAME="ucloud-k8s"
            ;;
        *)
            HOST_NAME="ucloud-vm"
            ;;
    esac
fi

if [ -z "$PORT_NUMBER" ]; then
    echo -e "${YELLOW}Enter UCloud SSH port for $HOST_NAME (from job progress view):${NC}"
    read -r PORT_NUMBER
fi

# Validate port number
if ! [[ "$PORT_NUMBER" =~ ^[0-9]+$ ]] || [ "$PORT_NUMBER" -lt 1 ] || [ "$PORT_NUMBER" -gt 65535 ]; then
    echo -e "${RED}Error: Invalid port number '$PORT_NUMBER'. Must be between 1 and 65535.${NC}"
    exit 1
fi

echo -e "${GREEN}Updating SSH config with port $PORT_NUMBER...${NC}"

# Canonical ucloud block updater using awk.
# Normalizes the "Host ucloud" block:
#   - rewrites tracked directives to canonical values
#   - removes directives when value is empty (e.g. ProxyJump in direct mode)
#   - collapses duplicate lines
#   - appends missing directives
#   - creates Host ucloud if absent
awk -v hostname="ssh.cloud.sdu.dk" \
    -v user="ucloud" \
    -v port="$PORT_NUMBER" \
    -v proxyjump="$PROXY_JUMP" \
    -v localforward="$LOCAL_FORWARD" \
    -v stricts="no" \
    -v knownhosts="/dev/null" \
    -v target_host="$HOST_NAME" '
BEGIN {
    order[1]="HostName";             val["HostName"]=hostname
    order[2]="User";                 val["User"]=user
    order[3]="Port";                 val["Port"]=port
    order[4]="ProxyJump";            val["ProxyJump"]=proxyjump
    order[5]="LocalForward";         val["LocalForward"]=localforward
    order[6]="StrictHostKeyChecking"; val["StrictHostKeyChecking"]=stricts
    order[7]="UserKnownHostsFile";   val["UserKnownHostsFile"]=knownhosts
    n=7; in_ucloud=0; ucloud_found=0
}
function flush_missing() {
    for (i=1; i<=n; i++) {
        k = order[i]
        if (!(k in seen) && val[k] != "") {
            print "  " k " " val[k]
        }
    }
}
/^[ \t]*Host[ \t]+/ {
    t=$0; sub(/^[ \t]*Host[ \t]+/, "", t)
    split(t, pats, /[ \t]+/)
    if (pats[1] == target_host) {
        in_ucloud=1; ucloud_found=1
        print
        next
    }
    if (in_ucloud) { flush_missing(); in_ucloud=0 }
    print
    next
}
in_ucloud {
    line=$0
    sub(/^[ \t]+/, "", line)
    if (line ~ /^[A-Za-z][A-Za-z0-9]*[ \t]/) {
        split(line, parts, /[ \t]+/)
        d=parts[1]
        if (d in val) {
            if (d in seen) next
            seen[d]=1
            if (val[d] != "") {
                print "  " d " " val[d]
            }
            next
        }
    }
}
{ print }
END {
    if (in_ucloud) flush_missing()
    if (!ucloud_found) {
        print ""
        print "Host " target_host
        for (i=1; i<=n; i++) {
            k = order[i]
            if (val[k] != "") {
                print "  " k " " val[k]
            }
        }
    }
}
' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"

mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

echo -e "${GREEN}✓ SSH config updated${NC}"

# Display the updated ucloud block
echo -e "\n${YELLOW}Updated $HOST_NAME configuration in ~/.ssh/config:${NC}"
awk -v target_host="$HOST_NAME" '
$0 ~ "^[ \t]*Host[ \t]+" target_host "[ \t]*$" {p=1}
p {print}
p && /^[ \t]*Host[ \t]+/ && $0 !~ "^[ \t]*Host[ \t]+" target_host "[ \t]*$" {exit}
' "$CONFIG_FILE"

# Connect via VSCode Remote-SSH if requested
if [ "$LAUNCH_CODE" = true ]; then
    if command -v code >/dev/null 2>&1; then
        echo -e "\n${GREEN}Connecting to $HOST_NAME via VSCode...${NC}"
        code --folder-uri "vscode-remote://ssh-remote+$HOST_NAME$REMOTE_DIR"
        echo -e "${GREEN}✓ VSCode connection initiated!${NC}"
    else
        echo -e "\n${YELLOW}VSCode CLI ('code') not found in PATH.${NC}"
        echo -e "You can connect manually via terminal: ${GREEN}ssh $HOST_NAME${NC}"
    fi
else
    echo -e "\n${GREEN}SSH config ready. Connect via:${NC} ${CYAN}ssh $HOST_NAME${NC}"
fi

if [ -n "$LOCAL_FORWARD" ]; then
    echo -e "${YELLOW}Tip: with tunnel active, VM port 8888 is forwarded to ${GREEN}http://localhost:8888${NC}"
fi
