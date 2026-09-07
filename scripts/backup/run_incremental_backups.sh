#!/bin/bash
# Run incremental backups for all TB group datasets (mirrors scheduled cron job)
# Sequential to avoid I/O contention on WekaFS. Logs each result to /work/backup.log

export RESTIC_PASSWORD_FILE="/work/data_backup/tb_backup_password.txt"
LOG="/work/backup.log"

declare -A REPO_SRC=(
  ["imaging_data_CD31pilot_#1_#2"]="/work/TB group/imaging_data_CD31pilot_#1_#2"
  ["imaging_data_f2630_HEV"]="/work/TB group/imaging_data_f2630_HEV"
  ["imaging_data_f2630_neutrophils"]="/work/TB group/imaging_data_f2630_neutrophils"
  ["imaging_data_f2701_HEV"]="/work/TB group/imaging_data_f2701_HEV"
  ["imaging_data_f2805_HEV"]="/work/TB group/imaging_data_f2805_HEV"
  ["imaging_data_f2944_1"]="/work/TB group/imaging_data_f2944_1"
  ["imaging_data_f2944_2"]="/work/TB group/imaging_data_f2944_2"
  ["imaging_data_seattle"]="/work/TB group/imaging_data_seattle"
  ["sequencing_data_MonkeyPAXgene_GEO241235"]="/work/TB group/sequencing_data_MonkeyPAXgene_GEO241235"
  ["sequencing_data_endothelial"]="/work/TB group/sequencing_data_endothelial"
  ["sequencing_data_totallung"]="/work/TB group/sequencing_data_totallung"
)

echo "=== Incremental backup run started $(date +%F_%T) ===" >> "$LOG"

for name in "${!REPO_SRC[@]}"; do
    repo="/work/Data_backup/$name"
    src="${REPO_SRC[$name]}"
    echo "" >> "$LOG"
    echo "--- [$name] start $(date +%T) ---" >> "$LOG"
    restic --password-file "$RESTIC_PASSWORD_FILE" -r "$repo" backup --host UCloud --verbose "$src" >> "$LOG" 2>&1
    rc=$?
    echo "--- [$name] end $(date +%T) exit=$rc ---" >> "$LOG"
done

echo "=== Incremental backup run complete $(date +%F_%T) ===" >> "$LOG"
