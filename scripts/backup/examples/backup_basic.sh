#!/bin/bash

# Example 1: Basic backup of a data directory
# This creates a backup every 2 hours (default)

./restic_wrapper.sh backup \
  -r /work/backup-repository \
  -s /work/my-research-data \
  -p /work/password.txt

echo "Backup configured with default 2-hour schedule"
