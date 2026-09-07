---
name: S to UCloud
description: Move data from S drive (or local disk) to UCloud HPC
---

# Skill Instructions

## Overview
Transfer data from local Mac (originally from S drive) to UCloud HPC's persistent storage at `/work/data_migration`.

## Prerequisites
1. **UCloud Job Running**: Start a job on UCloud with SSH enabled
2. **Mount Point Ready**: Ensure `/work/data_migration` is mounted (done via UCloud web interface)
3. **SSH Access**: Get SSH connection details from UCloud job interface
  - Hostname: `ssh.cloud.sdu.dk` (UCloud SSH gateway)
   - Username: Usually `ucloud`
   - **Port: MUST be obtained from UCloud interface** (changes per job, never hardcode)
   - SSH key: Use your configured SSH key
4. **Screen Session**: Start a screen session for protection against disconnection

### SSI Network ProxyJump Setup (Optional)
If you are on the SSI network and cannot connect directly, add this to `~/.ssh/config`:

```sshconfig
Host ucloud
  HostName ssh.cloud.sdu.dk
  User ucloud
  Port 2194            # Set per-job port from UCloud interface
  ProxyJump hutu@login.ugerm.dksund.dk
  LocalForward 8888 localhost:8888
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

Then use `ssh ucloud` or `rsync -e "ssh" ... ucloud:/work/...`.

## Example Transfer: F2805 Imaging Data

### Source
- **Original location**: S drive at `smb://s-inf-fil-05-p.ssi.ad/svl/...`
- **Current location**: Local Mac at `/Users/B291968/Downloads/F2805`
- **Data type**: Imaging data
- **Status**: Already copied from S drive to local disk for better performance

### Destination
- **System**: UCloud HPC
- **Path**: `/work/data_migration/F2805`
- **Access**: SSH-enabled job (must be manually started via UCloud web interface)

## Transfer Workflow

### Step 0: Start Screen Session (Recommended)
```bash
# Start a named screen session to protect your transfer
screen -S transfer_F2805

# Inside screen, you can now run all transfer commands
# If disconnected, reattach with: screen -r transfer_F2805
```

### Step 1: Verify Source Data
```bash
# Check data size and structure
du -sh /Users/B291968/Downloads/F2805
find /Users/B291968/Downloads/F2805 -type f | wc -l

# Generate MD5 checksums before transfer
cd /Users/B291968/Downloads
find F2805 -type f -exec md5 {} \; > F2805_checksums.txt
```

### Step 2: Get UCloud Connection Details and Test
```bash
# IMPORTANT: Get these values from UCloud web interface (job details page)
UCLOUD_HOST="ssh.cloud.sdu.dk"  # UCloud SSH gateway
UCLOUD_USER="ucloud"
UCLOUD_PORT="<port>"  # Example: 52143 (ALWAYS check current job!)

# Test connection
ssh -p ${UCLOUD_PORT} ${UCLOUD_USER}@${UCLOUD_HOST} "echo 'Connection successful'"

# Verify destination path exists
ssh -p ${UCLOUD_PORT} ${UCLOUD_USER}@${UCLOUD_HOST} "ls -ld /work/data_migration"
```

### Step 3: Transfer Data with rsync
```bash
# Transfer with progress, preserve attributes, and compression
rsync -avzP --stats \
  -e "ssh -p ${UCLOUD_PORT}" \
  /Users/B291968/Downloads/F2805/ \
  ${UCLOUD_USER}@${UCLOUD_HOST}:/work/data_migration/F2805/

# Options explained:
# -a: archive mode (preserves permissions, timestamps, etc.)
# -v: verbose output
# -z: compress during transfer
# -P: show progress and keep partial files
# --stats: show transfer statistics

# You can now detach from screen: Press Ctrl+A, then D
# Transfer continues in background
```

**Using SSH config alias with ProxyJump (recommended on SSI network)**
```bash
rsync -avzP --stats \
  -e "ssh" \
  /Users/B291968/Downloads/F2805/ \
  ucloud:/work/data_migration/F2805/
```

**Alternative: sftp for interactive transfer**
```bash
sftp -P ${UCLOUD_PORT} ${UCLOUD_USER}@${UCLOUD_HOST}
# Then in sftp:
cd /work/data_migration
mkdir F2805
cd F2805
lcd /Users/B291968/Downloads/F2805
put -r *
```

### Step 4: Verify Transfer on UCloud
```bash
# Check transferred files
ssh -p ${UCLOUD_PORT} ${UCLOUD_USER}@${UCLOUD_HOST} \
  "find /work/data_migration/F2805 -type f | wc -l"

# Generate checksums on destination
ssh -p ${UCLOUD_PORT} ${UCLOUD_USER}@${UCLOUD_HOST} \
  "cd /work/data_migration && find F2805 -type f -exec md5sum {} \; > F2805_checksums_destination.txt"

# Copy checksums back for comparison
scp -P ${UCLOUD_PORT} \
  ${UCLOUD_USER}@${UCLOUD_HOST}:/work/data_migration/F2805_checksums_destination.txt \
  /Users/B291968/Downloads/
```

### Step 5: Compare Checksums
```bash
# Extract just the MD5 hashes for comparison
# macOS md5 output format: MD5 (file) = hash
# Linux md5sum format: hash  file

# Process local checksums (macOS format)
awk '{print $NF, $3}' /Users/B291968/Downloads/F2805_checksums.txt | sort > local_sorted.txt

# Process remote checksums (Linux format)  
awk '{print $2, $1}' /Users/B291968/Downloads/F2805_checksums_destination.txt | sort > remote_sorted.txt

# Compare
diff local_sorted.txt remote_sorted.txt

# If no output, checksums match!
if [ $? -eq 0 ]; then
    echo "✅ All checksums match - transfer successful!"
else
    echo "❌ Checksum mismatch detected - investigate differences"
fi
```

### Step 6: Log the Transfer
```bash
# Create log directory if needed
mkdir -p /Users/B291968/Projects/data-management-agent/logs

# Generate log entry
LOG_FILE="logs/transfer_$(date +%Y%m%d_%H%M%S).log"
cat > ${LOG_FILE} <<EOF
Transfer Log
============
Date: $(date)
Source: /Users/B291968/Downloads/F2805
Destination: ${UCLOUD_USER}@${UCLOUD_HOST}:/work/data_migration/F2805
Method: rsync over SSH
Status: $([ $? -eq 0 ] && echo "SUCCESS" || echo "FAILED")
Files transferred: $(find /Users/B291968/Downloads/F2805 -type f | wc -l)
Checksum verification: $(diff -q local_sorted.txt remote_sorted.txt && echo "PASSED" || echo "FAILED")
EOF

# Make log immutable
chmod 444 ${LOG_FILE}
echo "Log saved to: ${LOG_FILE}"
```

## Screen Session Management

### Essential Screen Commands
```bash
# Start new screen session
screen -S transfer_F2805

# Detach from screen (transfer keeps running)
# Press: Ctrl+A, then D

# List all screen sessions
screen -ls

# Reattach to session
screen -r transfer_F2805

# Kill a session (if needed)
screen -X -S transfer_F2805 quit

# Scroll in screen (to view old output)
# Press: Ctrl+A, then Esc (then use arrow keys, q to exit scroll mode)
```

### Why Use Screen?
- Protects against accidental terminal closure
- Survives network disconnections
- Allows monitoring progress from different locations
- Essential for transfers >30 minutes
- Can detach and logout while transfer continues

## UCloud-Specific Considerations

### Connection Details
- **SSH must be enabled** when starting the job on UCloud
- **Port number is unique per job** - always check UCloud web interface
- Port numbers are typically in 50000-60000 range
- Connection details (hostname, port) are shown in UCloud job details page
- Jobs run in containers - only `/work` is persistent
- Standard SSH key authentication applies

### Storage Notes
- `/work/data_migration` survives job restarts (WekaFS distributed filesystem)
- Other paths (`/tmp`, `/home/ucloud`, `/opt`) are ephemeral and lost on job restart
- Total capacity: 4.7PB available on `/work`
- WekaFS optimized for large-scale parallel operations

### Troubleshooting

**Connection refused:**
- Verify job is running on UCloud web interface
- Check SSH is enabled in job settings
- Confirm firewall/network access from your location
- Wait ~30 seconds after job starts for SSH to become available

**Slow transfer from S drive:**
- Copy to local disk first (as done with F2805)
- SMB mount (`smb://s-inf-fil-05-p.ssi.ad/svl`) can be slow for many small files
- Local disk acts as staging area for better performance

**Permission denied on destination:**
- Ensure `/work/data_migration` directory exists and has write permissions
- Check that path is properly mounted in the job
- Verify you're connecting as correct user (`ucloud`)

**rsync hangs or stalls:**
- Check network connectivity: `ping ssh.cloud.sdu.dk`
- Verify disk space on destination: `df -h /work`
- Try with `-vv` flag for verbose debugging
- Consider using `--timeout=60` to catch network issues

**Port not defined:**
- Check UCloud web interface for current job's SSH port
- Port changes each time you start a new job
- Never use an old port number from a previous job

**Screen session lost:**
- Run `screen -ls` to find active sessions
- Reattach with `screen -r <session_name>`
- If session terminated, check system logs
- Ensure `/work/data_migration` directory exists and has write permissions
- Check that path is properly mounted in the job
- Verify you're connecting as correct user (`ucloud`)

**rsync hangs or stalls:**
- Check network connectivity: `ping <ucloud-host>`
- Verify disk space on destination: `df -h /work`
- Try with `-vv` flag for verbose debugging
- Consider using `--timeout=60` to catch network issues

## Automation Script Template
See `scripts/transfer_to_ucloud.sh` for a complete bash script that automates this workflow.
