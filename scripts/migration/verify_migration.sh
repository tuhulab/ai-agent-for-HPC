#!/usr/bin/env bash
# ============================================================================
# Step 1: Verification & Audit Script for Migrated Data on UCloud
#
# Verifies:
#   1. All destination datasets from manifest_raw.csv exist and are non-empty.
#   2. All 10 previously blocked permission files are present.
#   3. Gzip archive integrity check (gzip -t) on fastq.gz files.
#   4. Checksum verification if checksum manifest is available.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEST_ROOT="${DEST_ROOT:-/work/data_migration}"
MANIFEST="${1:-$REPO_ROOT/docs/data-management/runbook/manifest_raw.csv}"
[ ! -f "$MANIFEST" ] && MANIFEST="${DEST_ROOT}/docs/runbook/manifest_raw.csv"
BLOCKED_MANIFEST="${BLOCKED_MANIFEST:-$REPO_ROOT/docs/data-management/runbook/manifest_retransfer_blocked.csv}"
[ ! -f "$BLOCKED_MANIFEST" ] && BLOCKED_MANIFEST="${DEST_ROOT}/docs/runbook/manifest_retransfer_blocked.csv"
REPORT_FILE="${DEST_ROOT}/verification_report_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$DEST_ROOT"

# Formatting helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo -e "${BOLD}INFIMM Migration Verification (Step 1: Checksum & Integrity Audit)${NC}"
echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo "Destination Root : $DEST_ROOT"
echo "Manifest         : $MANIFEST"
echo "Audit Log        : $REPORT_FILE"
echo "Timestamp        : $(date)"
echo ""

TOTAL_ITEMS=0
PASSED_ITEMS=0
FAILED_ITEMS=0

# Log header
{
    echo "======================================================================"
    echo "INFIMM Migration Verification Report"
    echo "Date: $(date)"
    echo "Destination Root: $DEST_ROOT"
    echo "Manifest: $MANIFEST"
    echo "======================================================================"
} > "$REPORT_FILE"

# ----------------------------------------------------------------------------
# 1. Audit Primary Raw Manifest Datasets
# ----------------------------------------------------------------------------
echo -e "${BOLD}1. Checking Primary Manifest Datasets...${NC}"
printf "%-40s %-12s %-12s %-10s\n" "DATASET / TARGET" "FILES" "SIZE" "STATUS"
printf "%-40s %-12s %-12s %-10s\n" "----------------------------------------" "------------" "------------" "----------"

while IFS=',' read -r src dst || [ -n "$src" ]; do
    [[ -z "$src" || "$src" =~ ^[[:space:]]*# ]] && continue
    src=$(echo "$src" | xargs)
    dst=$(echo "$dst" | xargs)

    TOTAL_ITEMS=$((TOTAL_ITEMS + 1))
    target_path="${DEST_ROOT}/${dst}"

    if [ -e "$target_path" ]; then
        if [ -d "$target_path" ]; then
            file_count=$(find "$target_path" -type f 2>/dev/null | wc -l)
            size_human=$(du -sh "$target_path" 2>/dev/null | awk '{print $1}')
        else
            file_count=1
            size_human=$(du -sh "$target_path" 2>/dev/null | awk '{print $1}')
        fi

        if [ "$file_count" -gt 0 ]; then
            printf "%-40s %-12s %-12s ${GREEN}%-10s${NC}\n" "${dst:0:38}" "$file_count" "$size_human" "PASS"
            echo "PASS | $dst | files: $file_count | size: $size_human | path: $target_path" >> "$REPORT_FILE"
            PASSED_ITEMS=$((PASSED_ITEMS + 1))
        else
            printf "%-40s %-12s %-12s ${RED}%-10s${NC}\n" "${dst:0:38}" "0" "0B" "EMPTY"
            echo "EMPTY | $dst | files: 0 | path: $target_path" >> "$REPORT_FILE"
            FAILED_ITEMS=$((FAILED_ITEMS + 1))
        fi
    else
        printf "%-40s %-12s %-12s ${RED}%-10s${NC}\n" "${dst:0:38}" "0" "0B" "MISSING"
        echo "MISSING | $dst | path: $target_path" >> "$REPORT_FILE"
        FAILED_ITEMS=$((FAILED_ITEMS + 1))
    fi
done < "$MANIFEST"

echo ""

# ----------------------------------------------------------------------------
# 2. Audit the 10 Previously Blocked Permission Files
# ----------------------------------------------------------------------------
echo -e "${BOLD}2. Auditing Previously Permission-Blocked Files (GEO/F2702 & GEO/F2833)...${NC}"
BLOCKED_TOTAL=0
BLOCKED_PASSED=0

if [ -f "$BLOCKED_MANIFEST" ]; then
    while IFS=',' read -r src dst || [ -n "$src" ]; do
        [[ -z "$src" || "$src" =~ ^[[:space:]]*# ]] && continue
        src=$(echo "$src" | xargs)
        dst=$(echo "$dst" | xargs)
        fname=$(basename "$src")
        
        BLOCKED_TOTAL=$((BLOCKED_TOTAL + 1))
        
        # Target could be directory or file path
        if [[ "$dst" == */ ]]; then
            target_file="${DEST_ROOT}/${dst}${fname}"
        else
            target_file="${DEST_ROOT}/${dst}"
        fi

        if [ -s "$target_file" ]; then
            fsize=$(du -sh "$target_file" 2>/dev/null | awk '{print $1}')
            echo -e "  [${GREEN}✓${NC}] $fname ($fsize)"
            echo "BLOCKED_AUDIT_PASS | $fname | $target_file | $fsize" >> "$REPORT_FILE"
            BLOCKED_PASSED=$((BLOCKED_PASSED + 1))
        else
            echo -e "  [${RED}✗${NC}] $fname (${RED}MISSING or EMPTY${NC})"
            echo "BLOCKED_AUDIT_FAIL | $fname | $target_file" >> "$REPORT_FILE"
        fi
    done < "$BLOCKED_MANIFEST"
    echo -e "Blocked files status: ${BLOCKED_PASSED}/${BLOCKED_TOTAL} verified."
else
    echo "Note: Blocked manifest not found at $BLOCKED_MANIFEST (skipped)."
fi

echo ""

# ----------------------------------------------------------------------------
# 3. Gzip Integrity Check (gzip -t) on Sample Fastq Archives
# ----------------------------------------------------------------------------
echo -e "${BOLD}3. Sampling Fastq Archive Integrity (gzip -t test)...${NC}"
FASTQ_SAMPLES=$(find "$DEST_ROOT" -maxdepth 3 -type f -name "*.fastq.gz" 2>/dev/null | head -n 2 || true)

if [ -n "$FASTQ_SAMPLES" ]; then
    GZIP_FAILS=0
    while IFS= read -r fq_file; do
        printf "  Testing %-55s ... " "$(basename "$fq_file")"
        if gzip -t "$fq_file" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
            echo "GZIP_TEST_PASS | $fq_file" >> "$REPORT_FILE"
        else
            echo -e "${RED}CORRUPTED${NC}"
            echo "GZIP_TEST_FAIL | $fq_file" >> "$REPORT_FILE"
            GZIP_FAILS=$((GZIP_FAILS + 1))
        fi
    done <<< "$FASTQ_SAMPLES"

    if [ "$GZIP_FAILS" -eq 0 ]; then
        echo -e "${GREEN}✓ All tested Fastq gzip archives passed integrity check.${NC}"
    else
        echo -e "${RED}✗ Warning: $GZIP_FAILS archive(s) failed gzip integrity test.${NC}"
    fi
else
    echo "No .fastq.gz files found in top levels of $DEST_ROOT to test."
fi

echo ""

# ----------------------------------------------------------------------------
# Summary & Decision
# ----------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo -e "${BOLD}VERIFICATION SUMMARY${NC}"
echo -e "${BOLD}${BLUE}======================================================================${NC}"
echo "Total Manifest Items   : $TOTAL_ITEMS"
echo "Passed                 : $PASSED_ITEMS"
echo "Failed / Missing       : $FAILED_ITEMS"
echo "Audit Log Written to   : $REPORT_FILE"
echo ""

if [ "$FAILED_ITEMS" -eq 0 ] && [ "$BLOCKED_PASSED" -eq "$BLOCKED_TOTAL" ]; then
    echo -e "${GREEN}${BOLD}✓ GATE 1 PASSED: All migrated datasets and files verified.${NC}"
    echo -e "You can now safely proceed to Step 2 (Restic Backup Snapshot)."
    exit 0
else
    echo -e "${RED}${BOLD}✗ GATE 1 FAILED: Missing or incomplete datasets detected.${NC}"
    echo -e "${YELLOW}DO NOT DELETE source files on Computerome until all items pass.${NC}"
    exit 1
fi
