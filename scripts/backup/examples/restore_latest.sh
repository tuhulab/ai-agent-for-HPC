#!/bin/bash

# Example 3: Restore from latest snapshot

./restic_wrapper.sh restore \
  -r /work/backup-repository \
  -t /work/restored-data \
  -p /work/password.txt

echo "Data restored from latest snapshot to /work/restored-data"
