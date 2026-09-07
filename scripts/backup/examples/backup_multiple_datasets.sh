#!/bin/bash

# Backup Multiple TB Group Datasets
# ==================================
# This script automates backing up multiple data directories from /work/TB group
# to separate Restic repositories in /work/Data_backup.
#
# Features:
#   - Auto-discovers all directories with 'data' in the name
#   - Excludes specified test directories
#   - Creates separate repository per dataset for easier management
#   - Handles spaces in directory names correctly
#   - Interactive confirmation before starting
#   - Progress tracking and error reporting
#
# Usage:
#   ./backup_multiple_datasets.sh /path/to/password.txt
#
# Requirements:
#   - Password file must exist and be readable
#   - restic_wrapper.sh must be in parent directory
#   - Source directories must exist in /work/TB group
#
# Output:
#   - Backup repositories: /work/Data_backup/<dataset_name>/
#   - Logs: /work/backup.log (appended by cron jobs)
#   - Cron jobs: Scheduled every 2 hours per dataset
#
# Example:
#   ./backup_multiple_datasets.sh /work/tb_backup_password.txt
#
# Tips:
#   - Run in screen for long backups: screen -dmS backup bash -c './backup_multiple_datasets.sh /work/password.txt'
#   - Monitor progress: tail -f /work/backup.log
#   - Re-running is safe: Restic only backs up changed files
#
# Directory List (auto-discovered from /work/TB group):
#   - imaging_data_f2944_1
#   - imaging_data_f2944_2
#   - imaging_data_f2701_HEV
#   - imaging_data_f2805_HEV
#   - imaging_data_CD31pilot_#1_#2
#   - imaging_data_f2630_HEV
#   - imaging_data_f2630_neutrophils
#   - imaging_data_seattle
#   - sequencing_data_MonkeyPAXgene_GEO241235
#   - sequencing_data_totallung
#   - sequencing_data_endothelial
#
# Excluded (test data):
#   - imaging_data_test_cellpose

# Configuration
SOURCE_BASE="/work/TB group"
BACKUP_BASE="/work/Data_backup"
PASSWORD_FILE="${1}"
WRAPPER_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/restic_wrapper.sh"

# Directories to exclude
EXCLUDE_DIRS=("imaging_data_test_cellpose")

# Validate inputs
if [[ -z "$PASSWORD_FILE" ]]; then
    echo "Error: Password file path required as first argument"
    echo "Usage: $0 /path/to/password.txt"
    exit 1
fi

if [[ ! -f "$PASSWORD_FILE" ]]; then
    echo "Error: Password file not found: $PASSWORD_FILE"
    exit 1
fi

if [[ ! -f "$WRAPPER_SCRIPT" ]]; then
    echo "Error: restic_wrapper.sh not found at: $WRAPPER_SCRIPT"
    exit 1
fi

# Function to check if directory should be excluded
should_exclude() {
    local dir_name="$1"
    for exclude in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$dir_name" == "$exclude" ]]; then
            return 0  # Exclude this directory
        fi
    done
    return 1  # Include this directory
}

# Find all data directories (handle spaces properly)
echo "Discovering data directories in $SOURCE_BASE..."
mapfile -t DATA_DIRS < <(find "$SOURCE_BASE" -maxdepth 1 -type d -name '*data*' | sort)

if [[ ${#DATA_DIRS[@]} -eq 0 ]]; then
    echo "Error: No data directories found in $SOURCE_BASE"
    exit 1
fi

# Filter out excluded directories and display plan
BACKUP_LIST=()
echo ""
echo "Backup Plan:"
echo "============"
for dir in "${DATA_DIRS[@]}"; do
    dir_name=$(basename "$dir")
    
    if should_exclude "$dir_name"; then
        echo "  ⊘ $dir_name (EXCLUDED)"
    else
        echo "  ✓ $dir_name"
        BACKUP_LIST+=("$dir")
    fi
done

echo ""
echo "Total: ${#BACKUP_LIST[@]} directories to backup"
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Execute backups
echo ""
echo "Starting backups..."
echo "==================="
SUCCESS=0
FAILED=0
SKIPPED=0

for source_dir in "${BACKUP_LIST[@]}"; do
    dir_name=$(basename "$source_dir")
    repo_path="$BACKUP_BASE/$dir_name"
    
    echo ""
    echo "Backing up: $dir_name"
    echo "  Source: $source_dir"
    echo "  Repository: $repo_path"
    echo "---"
    
    # Check if repository already exists
    if [[ -d "$repo_path" ]]; then
        echo "  ⚠ Repository already exists. Running incremental backup..."
    fi
    
    # Execute backup using restic wrapper
    if "$WRAPPER_SCRIPT" backup -r "$repo_path" -s "$source_dir" -p "$PASSWORD_FILE"; then
        echo "  ✓ Backup completed successfully"
        ((SUCCESS++))
    else
        echo "  ✗ Backup failed"
        ((FAILED++))
    fi
done

# Summary
echo ""
echo "==================="
echo "Backup Summary"
echo "==================="
echo "  Successful: $SUCCESS"
echo "  Failed: $FAILED"
echo "  Excluded: $SKIPPED"
echo ""
echo "Logs available at: /work/backup.log"
echo "View scheduled backups: crontab -l"
