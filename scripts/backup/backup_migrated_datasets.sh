#!/usr/bin/env bash
# ============================================================================
# Step 2: Restic Backup Automation for Migrated Datasets on UCloud
#
# Automates:
#   1. Discovery of all migrated datasets in /work/data_migration
#   2. Repository initialization in /work/Data_backup/<dataset_name>
#   3. Snapshot creation with deduplication and compression
#   4. Restic repository integrity checks (restic check)
#   5. Logging results to /work/backup.log
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_BASE="${SOURCE_BASE:-/work/data_migration}"
BACKUP_BASE="${BACKUP_BASE:-/work/Data_backup}"
LOG_FILE="/work/backup.log"

# Find password file
PASSWORD_FILE="${1:-}"
if [ -z "$PASSWORD_FILE" ]; then
    if [ -f "/work/data_backup/tb_backup_password.txt" ]; then
        PASSWORD_FILE="/work/data_backup/tb_backup_password.txt"
    elif [ -f "/work/password.txt" ]; then
        PASSWORD_FILE="/work/password.txt"
    elif [ -f "/work/.backup-password" ]; then
        PASSWORD_FILE="/work/.backup-password"
    else
        echo "Error: Password file not specified and no default found."
        echo "Usage: $0 /path/to/password.txt [source_dir]"
        exit 1
    fi
fi

if [ ! -f "$PASSWORD_FILE" ]; then
    echo "Error: Password file '$PASSWORD_FILE' does not exist."
    exit 1
fi

if [ $# -ge 2 ]; then
    SOURCE_BASE="$2"
fi

mkdir -p "$BACKUP_BASE" "$(dirname "$LOG_FILE")"

# Formatting helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo -e "${BOLD}INFIMM Migrated Datasets Backup (Step 2: Restic Snapshot Creation)${NC}"
echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo "Source Base   : $SOURCE_BASE"
echo "Backup Base   : $BACKUP_BASE"
echo "Password File : $PASSWORD_FILE"
echo "Log File      : $LOG_FILE"
echo "Timestamp     : $(date)"
echo ""

# Ensure restic is installed and available
if ! command -v restic &>/dev/null; then
    echo "Installing restic..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y restic cron
    fi
fi

# Discover directories to back up
echo -e "${BOLD}Discovering datasets in $SOURCE_BASE...${NC}"
mapfile -t DATASET_DIRS < <(find "$SOURCE_BASE" -mindepth 1 -maxdepth 1 -type d | sort)

if [ ${#DATASET_DIRS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No dataset subdirectories found in $SOURCE_BASE.${NC}"
    echo "Backing up entire $SOURCE_BASE directory as a single repository..."
    DATASET_DIRS=("$SOURCE_BASE")
fi

echo "Found ${#DATASET_DIRS[@]} dataset directory(ies) to backup."
echo ""

TOTAL=${#DATASET_DIRS[@]}
SUCCESS=0
FAILED=0

echo -e "=== Migrated datasets backup run started $(date +%F_%T) ===" >> "$LOG_FILE"

for ((i=0; i<TOTAL; i++)); do
    src_dir="${DATASET_DIRS[$i]}"
    dname=$(basename "$src_dir")
    repo_path="${BACKUP_BASE}/${dname}"

    echo -e "${BOLD}[$((i+1))/$TOTAL] Backing up: $dname${NC}"
    echo "  Source : $src_dir"
    echo "  Repo   : $repo_path"

    # Initialize repository if not already initialized
    if ! restic -r "$repo_path" --password-file "$PASSWORD_FILE" snapshots >/dev/null 2>&1; then
        echo "  Initializing new Restic repository..."
        restic -r "$repo_path" --password-file "$PASSWORD_FILE" init >> "$LOG_FILE" 2>&1 || {
            echo -e "  ${RED}✗ Failed to initialize repository for $dname${NC}"
            FAILED=$((FAILED + 1))
            continue
        }
    fi

    # Execute backup snapshot
    echo "  Creating backup snapshot..."
    if restic -r "$repo_path" \
        --password-file "$PASSWORD_FILE" \
        backup \
        --host UCloud \
        --tag "migration-raw" \
        --verbose \
        "$src_dir" >> "$LOG_FILE" 2>&1; then
        
        echo -e "  ${GREEN}✓ Backup snapshot created successfully.${NC}"
        
        # Verify repository integrity
        printf "  Checking repository integrity (restic check) ... "
        if restic -r "$repo_path" --password-file "$PASSWORD_FILE" check >> "$LOG_FILE" 2>&1; then
            echo -e "${GREEN}OK${NC}"
            SUCCESS=$((SUCCESS + 1))
        else
            echo -e "${RED}CHECK FAILED (see log)${NC}"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "  ${RED}✗ Backup failed (see $LOG_FILE)${NC}"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo -e "=== Migrated datasets backup run complete $(date +%F_%T) ===" >> "$LOG_FILE"

# Summary
echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo -e "${BOLD}BACKUP SUMMARY${NC}"
echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo "Total Datasets Processed : $TOTAL"
echo "Successful Backups       : $SUCCESS"
echo "Failed                   : $FAILED"
echo "Backup Log               : $LOG_FILE"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ GATE 2 PASSED: All Restic snapshots created and integrity checked.${NC}"
    echo -e "Redundant backup is now active on UCloud WekaFS."
    exit 0
else
    echo -e "${RED}${BOLD}✗ GATE 2 FAILED: One or more datasets failed to backup.${NC}"
    echo -e "${YELLOW}DO NOT DELETE source files until all snapshots succeed.${NC}"
    exit 1
fi
