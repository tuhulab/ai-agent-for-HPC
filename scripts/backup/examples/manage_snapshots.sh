#!/bin/bash

# Example 4: Advanced snapshot management
# This script shows how to manage snapshots directly with Restic

REPO="/work/backup-repository"
PASSWORD="/work/password.txt"

# List all snapshots
echo "=== All Snapshots ==="
restic snapshots -r "$REPO" --password-file "$PASSWORD"

# Show repository stats
echo -e "\n=== Repository Statistics ==="
restic stats -r "$REPO" --password-file "$PASSWORD"

# Keep only last 7 daily, 4 weekly, and 6 monthly snapshots
echo -e "\n=== Applying Retention Policy ==="
restic forget -r "$REPO" --password-file "$PASSWORD" \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune

# Verify repository integrity
echo -e "\n=== Checking Repository Integrity ==="
restic check -r "$REPO" --password-file "$PASSWORD"

echo -e "\n=== Snapshot Management Complete ==="
