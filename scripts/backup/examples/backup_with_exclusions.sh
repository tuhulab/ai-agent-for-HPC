#!/bin/bash

# Example 2: Backup with exclusions
# Exclude temporary files, cache directories, and large data files

./restic_wrapper.sh backup \
  -r /work/backup-repository \
  -s /work/my-research-data \
  -p /work/password.txt \
  --exclude "*.tmp" \
  --exclude "*.temp" \
  --exclude "*/cache/*" \
  --exclude "*/node_modules/*" \
  --exclude "*.bam" \
  --exclude "*.fastq.gz"

echo "Backup configured with file exclusions"
