#!/bin/bash
set -euo pipefail

# ============================================================================
# UCloud Data Transfer Script with Integrity Verification
# ============================================================================
# Purpose: Automate data transfer from local Mac to UCloud HPC with MD5 checks
# Author: INFIMM-Bioinformatics
# Usage: ./transfer_to_ucloud.sh <source_path> <destination_path> <ucloud_port> [ucloud_host]
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 <source_path> <destination_path> <ucloud_port> [ucloud_host]

Arguments:
  source_path       Local path to transfer (e.g., /Users/username/Downloads/data)
  destination_path  Remote path on UCloud (e.g., /work/data_migration/data)
  ucloud_port       SSH port from UCloud job interface (REQUIRED)
  ucloud_host       UCloud hostname (default: read from prompt)

Example:
    $0 /Users/B291968/Downloads/F2805 /work/data_migration/F2805 52143 ssh.cloud.sdu.dk

Note: Get the UCloud SSH port from the job details in UCloud web interface
      Recommended: Run inside 'screen' for long transfers

Alias mode (ProxyJump):
    If you have an SSH config alias (e.g., 'ucloud' with ProxyJump),
    pass 'ucloud' as ucloud_host. The script will use plain ssh (no -p),
    and the port from your SSH config will be used.

Screen usage:
  screen -S my_transfer        # Start new screen session
  $0 <args>                    # Run transfer
  Ctrl+A, then D               # Detach (transfer continues)
  screen -r my_transfer        # Reattach later

Environment Variables (optional):
  UCLOUD_USER      UCloud username (default: ucloud)
    UCLOUD_SSH_KEY   Path to SSH private key (useful for batch jobs)
  SKIP_CHECKSUM    Skip MD5 verification if set to 1
    USE_SSH_ALIAS    Force using SSH alias mode ("ssh" without -p) if set to 1

EOF
    exit 1
}

# Check arguments
if [ $# -lt 3 ]; then
    usage
fi

SOURCE_PATH="$1"
DEST_PATH="$2"
UCLOUD_PORT="$3"
UCLOUD_HOST="${4:-}"
UCLOUD_USER="${UCLOUD_USER:-ucloud}"
SKIP_CHECKSUM="${SKIP_CHECKSUM:-0}"
USE_SSH_ALIAS="${USE_SSH_ALIAS:-0}"

# Validate source path
if [ ! -d "$SOURCE_PATH" ] && [ ! -f "$SOURCE_PATH" ]; then
    log_error "Source path does not exist: $SOURCE_PATH"
    exit 1
fi

# Get UCloud connection details if not provided
if [ -z "$UCLOUD_HOST" ]; then
    echo -n "Enter UCloud hostname (e.g., ssh.cloud.sdu.dk): "
    read -r UCLOUD_HOST
fi

if [ -z "$UCLOUD_HOST" ]; then
    log_error "UCloud hostname is required"
    exit 1
fi

# Determine SSH command (alias vs direct)
ALIAS_MODE=0
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
if [ -n "${UCLOUD_SSH_KEY:-}" ]; then
    SSH_OPTS="$SSH_OPTS -i $UCLOUD_SSH_KEY"
fi

RSYNC_SSH_CMD="ssh -p $UCLOUD_PORT $SSH_OPTS"
SSH_CMD="ssh -p $UCLOUD_PORT $SSH_OPTS"
if [ "$UCLOUD_HOST" = "ucloud" ] || [ "$USE_SSH_ALIAS" = "1" ]; then
    ALIAS_MODE=1
    RSYNC_SSH_CMD="ssh $SSH_OPTS"
    SSH_CMD="ssh $SSH_OPTS"
fi

# Detect if running in screen (skip interactive prompt if in SLURM job or other batch environment)
# Use parameter substitution to avoid "unbound variable" error with "set -u"
STY_VAL="${STY:-}"
if [ -z "$STY_VAL" ] && [ -z "${SLURM_JOB_ID:-}" ]; then
    log_warn "⚠️  Not running in screen session"
    log_warn "   For long transfers, consider using screen to prevent interruption:"
    log_warn "   screen -S transfer_$(date +%Y%m%d_%H%M%S)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Setup logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/transfer_$(date +%Y%m%d_%H%M%S).log"

# Create temporary directory for checksums
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Function to log to both file and stdout
log_both() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Start transfer process
log_both "============================================================================"
log_both "UCloud Data Transfer - Started at $(date)"
log_both "============================================================================"
log_both "Source:      $SOURCE_PATH"
log_both "Destination: $UCLOUD_USER@$UCLOUD_HOST:$DEST_PATH"
if [ "$ALIAS_MODE" = "1" ]; then
    log_both "SSH Mode:    alias (ProxyJump)"
else
    log_both "SSH Port:    $UCLOUD_PORT"
fi
if [ -n "${STY:-}" ]; then
    log_both "Screen:      $STY_VAL"
fi
log_both ""

# Step 1: Test SSH connection
log_info "Testing SSH connection to UCloud..."
log_info "SSH Command: $SSH_CMD"
log_info "Target: $UCLOUD_USER@$UCLOUD_HOST"
if ! $SSH_CMD "$UCLOUD_USER@$UCLOUD_HOST" "echo 'Connection successful'" &>>"$LOG_FILE"; then
    log_error "Cannot connect to UCloud. Please check:"
    log_error "  1. Job is running on UCloud"
    log_error "  2. SSH is enabled in job settings"
    log_error "  3. Hostname and port are correct"
    log_error "  4. Your SSH key is configured"
    log_error "  SSH Debug output appended to log"
    exit 1
fi
log_both "✓ SSH connection successful"

# Step 2: Check destination path
log_info "Verifying destination path on UCloud..."
if ! $SSH_CMD "$UCLOUD_USER@$UCLOUD_HOST" "mkdir -p $(dirname $DEST_PATH)" 2>>"$LOG_FILE"; then
    log_error "Cannot create destination path on UCloud"
    exit 1
fi
log_both "✓ Destination path ready"

# Step 3: Check disk space
log_info "Checking available disk space..."
SOURCE_SIZE=$(du -sk "$SOURCE_PATH" | cut -f1)
DEST_AVAILABLE=$($SSH_CMD "$UCLOUD_USER@$UCLOUD_HOST" "df -k $(dirname $DEST_PATH) | tail -1 | awk '{print \$4}'")

if [ "$SOURCE_SIZE" -gt "$DEST_AVAILABLE" ]; then
    log_error "Insufficient disk space on destination"
    log_error "  Required: $(numfmt --to=iec-i --suffix=B $((SOURCE_SIZE * 1024)))"
    log_error "  Available: $(numfmt --to=iec-i --suffix=B $((DEST_AVAILABLE * 1024)))"
    exit 1
fi
log_both "✓ Sufficient disk space available"

# Step 4: Generate source checksums (if not skipping)
if [ "$SKIP_CHECKSUM" = "0" ]; then
    log_info "Generating MD5 checksums for source files..."
    SOURCE_CHECKSUM="$TEMP_DIR/source_checksums.txt"
    
    if [ -d "$SOURCE_PATH" ]; then
        # Directory: checksum all files
        cd "$(dirname "$SOURCE_PATH")"
        BASENAME=$(basename "$SOURCE_PATH")
        find "$BASENAME" -type f -exec md5 {} \; > "$SOURCE_CHECKSUM" 2>>"$LOG_FILE"
        FILE_COUNT=$(wc -l < "$SOURCE_CHECKSUM" | tr -d ' ')
    else
        # Single file
        md5 "$SOURCE_PATH" > "$SOURCE_CHECKSUM" 2>>"$LOG_FILE"
        FILE_COUNT=1
    fi
    
    log_both "✓ Generated checksums for $FILE_COUNT files"
else
    log_warn "Skipping checksum generation (SKIP_CHECKSUM=1)"
fi

# Step 5: Transfer data with rsync
log_info "Starting rsync transfer..."
log_both ""

RSYNC_OPTS="-avzP --stats"
RSYNC_LOG="$TEMP_DIR/rsync.log"

# Add trailing slash for directory sync behavior
RSYNC_SOURCE="$SOURCE_PATH"
if [ -d "$SOURCE_PATH" ]; then
    RSYNC_SOURCE="$SOURCE_PATH/"
fi

if rsync $RSYNC_OPTS \
    -e "$RSYNC_SSH_CMD" \
    "$RSYNC_SOURCE" \
    "$UCLOUD_USER@$UCLOUD_HOST:$DEST_PATH" \
    2>&1 | tee "$RSYNC_LOG" | tee -a "$LOG_FILE"; then
    log_both ""
    log_both "✓ Transfer completed successfully"
else
    log_error "Transfer failed. Check log: $LOG_FILE"
    exit 1
fi

# Extract rsync statistics
log_both ""
log_both "Transfer Statistics:"
grep -E "Number of files|Total file size|Total transferred file size|Literal data|Total bytes sent|Total bytes received" "$RSYNC_LOG" | tee -a "$LOG_FILE" || true

# Step 6: Verify checksums (if not skipping)
if [ "$SKIP_CHECKSUM" = "0" ]; then
    log_info "Verifying data integrity with MD5 checksums..."
    
    DEST_CHECKSUM="$TEMP_DIR/dest_checksums.txt"
    DEST_BASENAME=$(basename "$DEST_PATH")
    
    # Generate checksums on destination
    $SSH_CMD "$UCLOUD_USER@$UCLOUD_HOST" \
        "cd $(dirname $DEST_PATH) && find $DEST_BASENAME -type f -exec md5sum {} \;" \
        > "$DEST_CHECKSUM" 2>>"$LOG_FILE"
    
    # Process checksums for comparison (handle macOS vs Linux format)
    # macOS md5: MD5 (file) = hash
    # Linux md5sum: hash  file
    awk '{print $NF, $3}' "$SOURCE_CHECKSUM" | sort > "$TEMP_DIR/source_sorted.txt"
    awk '{print $2, $1}' "$DEST_CHECKSUM" | sort > "$TEMP_DIR/dest_sorted.txt"
    
    # Compare checksums
    if diff "$TEMP_DIR/source_sorted.txt" "$TEMP_DIR/dest_sorted.txt" > "$TEMP_DIR/checksum_diff.txt" 2>&1; then
        log_both "✓ All checksums match - transfer verified!"
        CHECKSUM_STATUS="PASSED"
    else
        log_error "Checksum mismatch detected!"
        log_error "Differences saved to: $TEMP_DIR/checksum_diff.txt"
        cat "$TEMP_DIR/checksum_diff.txt" | tee -a "$LOG_FILE"
        CHECKSUM_STATUS="FAILED"
    fi
else
    CHECKSUM_STATUS="SKIPPED"
fi

# Step 7: Create immutable log
log_both ""
log_both "============================================================================"
log_both "Transfer Summary"
log_both "============================================================================"
log_both "Status:              SUCCESS"
log_both "Files transferred:   $FILE_COUNT"
log_both "Checksum validation: $CHECKSUM_STATUS"
log_both "Completed at:        $(date)"
log_both "Log file:            $LOG_FILE"
log_both "============================================================================"

# Make log immutable
chmod 444 "$LOG_FILE"

log_info "Transfer complete! Log saved to: $LOG_FILE"

# Exit with appropriate code
if [ "$CHECKSUM_STATUS" = "FAILED" ]; then
    exit 1
else
    exit 0
fi
