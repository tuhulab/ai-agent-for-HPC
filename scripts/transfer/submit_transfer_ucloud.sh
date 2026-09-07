#!/bin/bash
# ============================================================================
# SLURM Job Submission Script for UCloud Data Transfer
# ============================================================================
# Purpose: Submit a data transfer job from uGerm HPC to UCloud via SLURM
# Author: INFIMM-Bioinformatics
# Usage: sbatch scripts/submit_transfer_ucloud.sh <source_path> <destination_path> <ucloud_port> [ucloud_host]
# Example: sbatch scripts/submit_transfer_ucloud.sh \
#            /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/ \
#            /work/data_migration/total_lung_TBD/ \
#            2631 \
#            ssh.cloud.sdu.dk
# ============================================================================

# SLURM directives
#SBATCH --job-name=ucloud-transfer
#SBATCH --partition=standard
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --output=logs/transfer_%j.log
#SBATCH --error=logs/transfer_%j.err

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to display usage
usage() {
    cat <<EOF
Usage: sbatch $0 <source_path> <destination_path> <ucloud_port> [ucloud_host]

Arguments:
  source_path       Local path on uGerm to transfer
  destination_path  Remote path on UCloud (e.g., /work/data_migration/total_lung_TBD/)
  ucloud_port       SSH port from UCloud job interface (REQUIRED)
  ucloud_host       UCloud hostname (default: ssh.cloud.sdu.dk)

Example:
    sbatch $0 \\
      /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/ \\
      /work/data_migration/total_lung_TBD/ \\
      2631 \\
      ssh.cloud.sdu.dk

Notes:
  - Data transfer happens asynchronously via SLURM on uGerm HPC
  - No 'screen' session needed (SLURM manages process continuity)
  - Check job status: squeue -u \$USER
  - Monitor transfer: tail -f logs/transfer_<jobid>_*.log (once job starts)
  - View completed job: sacct -j <jobid>

EOF
    exit 1
}

# ============================================================================
# Main Script
# ============================================================================

log_header "SLURM UCloud Data Transfer Job"

# Validate input arguments
if [[ $# -lt 3 ]]; then
    log_error "Missing required arguments"
    usage
fi

SOURCE_PATH="${1}"
DEST_PATH="${2}"
UCLOUD_PORT="${3}"
UCLOUD_HOST="${4:-ssh.cloud.sdu.dk}"

log_info "SLURM Job ID: ${SLURM_JOB_ID}"
log_info "Source: ${SOURCE_PATH}"
log_info "Destination: ${DEST_PATH}"
log_info "UCloud Port: ${UCLOUD_PORT}"
log_info "UCloud Host: ${UCLOUD_HOST}"
log_info "Job submitted by: $(whoami)"
log_info "Current directory: $(pwd)"

# Validate source path exists
log_info "Validating source path..."
if [[ ! -e "${SOURCE_PATH}" ]]; then
    log_error "Source path does not exist: ${SOURCE_PATH}"
    exit 1
fi
log_info "Source path validated ✓"

# Validate UCloud port is numeric
log_info "Validating UCloud port..."
if ! [[ "${UCLOUD_PORT}" =~ ^[0-9]+$ ]]; then
    log_error "UCloud port must be a number: ${UCLOUD_PORT}"
    exit 1
fi
log_info "UCloud port validated ✓"

# Ensure logs directory exists
if [[ ! -d "logs" ]]; then
    log_info "Creating logs directory..."
    mkdir -p logs
fi

# Calculate source size
log_info "Calculating source data size..."
SOURCE_SIZE=$(du -sh "${SOURCE_PATH}" | awk '{print $1}')
log_info "Source size: ${SOURCE_SIZE}"

log_header "Starting Data Transfer via transfer_to_ucloud.sh"

# Run the transfer script
# The transfer_to_ucloud.sh script will:
#   1. Test SSH connectivity to UCloud
#   2. Check destination disk space
#   3. Generate MD5 checksums on source
#   4. Transfer data via rsync
#   5. Verify MD5 checksums on destination
#   6. Create immutable log file with results

# Find the transfer script - use the current working directory (repo root)
# SLURM sets the correct PWD when launching the job
TRANSFER_SCRIPT="${PWD}/scripts/transfer_to_ucloud.sh"

if [[ ! -f "${TRANSFER_SCRIPT}" ]]; then
    log_error "Transfer script not found: ${TRANSFER_SCRIPT}"
    log_error "PWD: ${PWD}"
    log_error "Available scripts: $(ls -la ${PWD}/scripts/ 2>&1 | grep transfer || echo 'None found')"
    exit 1
fi

log_info "Running: ${TRANSFER_SCRIPT} ${SOURCE_PATH} ${DEST_PATH} ${UCLOUD_PORT} ${UCLOUD_HOST}"
log_info ""

# Execute the transfer script
# Note: We do NOT use screen here because SLURM manages job continuity
if "${TRANSFER_SCRIPT}" "${SOURCE_PATH}" "${DEST_PATH}" "${UCLOUD_PORT}" "${UCLOUD_HOST}"; then
    log_header "Transfer Completed Successfully ✓"
    log_info "Data transfer completed successfully"
    log_info "Check ${DEST_PATH} on UCloud for transferred files"
    log_info "Log files are in: logs/"
    exit 0
else
    TRANSFER_EXIT_CODE=$?
    log_header "Transfer Failed ✗"
    log_error "Data transfer exited with code: ${TRANSFER_EXIT_CODE}"
    log_error "Check the log file for details: logs/transfer_${SLURM_JOB_ID}_*.log"
    exit ${TRANSFER_EXIT_CODE}
fi
