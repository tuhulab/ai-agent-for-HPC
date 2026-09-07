---
name: uGerm HPC to UCloud
description: Transfer data from uGerm HPC to UCloud via SLURM or login-node screen
---

# Skill Instructions: Data Transfer from uGerm HPC to UCloud

## Overview
This skill guides you through transferring data from the uGerm HPC cluster to UCloud. Use SLURM when compute nodes can reach the UCloud SSH gateway. If compute nodes cannot reach it, run the transfer on the login node inside `screen`.

**Key Benefits:**
- No risk of disconnection (SLURM manages process continuity)
- Can submit multiple transfers simultaneously
- Job status tracked by SLURM (`squeue`, `sacct`)
- Automatic logging with timestamped files
- Integrated MD5 checksum verification

## Prerequisites

1. **UCloud Job with SSH Enabled**
   - Start an interactive or compute job on UCloud web interface
   - **Enable SSH access** in job settings (must be selected when creating the job)
   - **Get SSH port** from job details page (e.g., `2631`, `52143`)

2. **SSH Connection to UCloud**
   - Test connection from uGerm:
     ```bash
     ssh ucloud@ssh.cloud.sdu.dk -p <PORT> "echo 'SSH test successful'"
     ```
   - If this fails, you may need to:
     - Generate SSH key: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519` (if not already done)
     - Add public key to UCloud account settings
    - For batch jobs or login-node runs, set an explicit key:
       ```bash
       export UCLOUD_SSH_KEY="$HOME/.ssh/id_rsa"
       ```

3. **Access to Source Data on uGerm**
   - Data must be readable from uGerm cluster nodes
   - Common locations: `/srvdata/...`, `/home/...`, shared project directories

4. **SLURM Available**
   - Already available on uGerm (verify with: `sbatch --version`)

## Example Transfer: TB-2998 Fastq Data

### Source
- **System**: uGerm HPC cluster
- **Path**: `/srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/`
- **Data type**: FASTQ sequence data
- **Size**: ~52 GB
- **Files**: Multiple `.fastq.gz` files from NGS sequencing

### Destination
- **System**: UCloud HPC
- **Path**: `/work/data_migration/total_lung_TBD/`
- **Persistent**: Data remains available for workflows/analysis on UCloud

## Transfer Workflow

### Step 0: Test SSH Connection to UCloud
```bash
# Test connectivity with the port from UCloud job details
ssh ucloud@ssh.cloud.sdu.dk -p 2631 "echo 'Connection successful'"

# Expected output:
# Connection successful
```
**Troubleshooting:**
- If connection refused: Check that the UCloud job is still running and SSH is enabled
- If host key error: Accept the key with `yes` (first connection only)
- If timeout: UCloud port may have changed; refresh job details page

### Step 1: Validate Source Data on uGerm
```bash
# Check that source path is accessible
ls -lh /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/ | head -5

# Estimate transfer time (shows data size)
du -sh /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/

# Expected output: ~52G
```

If the path does not exist or is not accessible, verify:
- Path is correct (no typos)
- You have read permissions: `test -r <path> && echo 'readable' || echo 'not readable'`
- Data has not been moved/deleted

### Step 2: Submit Transfer Job to SLURM Queue

```bash
# Navigate to the data-transfer-agent directory
cd /dpssi/home/hutu/data-transfer-agent

# Submit the job
sbatch scripts/submit_transfer_ucloud.sh \
  /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/ \
  /work/data_migration/total_lung_TBD/ \
  2631 \
  ssh.cloud.sdu.dk

# Expected output:
# Submitted batch job 12345
```

**Parameters Explained:**
1. **Source path**: `/srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/`
   - Full path to data on uGerm cluster
   - Can be relative path if you cd into the directory first

2. **Destination path**: `/work/data_migration/total_lung_TBD/`
   - Full path on UCloud (subdirectory of `/work/data_migration/`)
   - Created automatically if it doesn't exist

3. **UCloud port**: `2631`
   - **MUST match the port shown in UCloud job details**
   - Changes every time you start a new job

4. **UCloud host**: `ssh.cloud.sdu.dk`
   - Default UCloud SSH gateway hostname
   - Can be omitted (defaults to this value)

### Step 3: Monitor Transfer Job Status

```bash
# Check job queue
squeue -u $(whoami)

# Expected output:
#    JOBID  PARTITION     NAME  USER ST       TIME  NODES NODELIST(REASON)
#    12345   standard ucloud-tr hutu  R       0:05      1 dpssi-006

# States:
# ST = R (Running)
# ST = PD (Pending)
# ST = CA (Cancelled)
# ST = CD (Completed)
# ST = F (Failed)

# View job details
sinfo -j 12345    # Or use your actual job ID

# Check view completed or failed jobs
sacct -j 12345    # Shows more details including exit code and runtime
```

### Step 4: Monitor Transfer Progress

Once the job is running, monitor the transfer in real-time:

```bash
# Find the latest transfer log file
ls -ltr logs/transfer_*.log | tail -1

# Tail the log to watch progress
tail -f logs/transfer_<JOBID>_*.log

# Watch for these phases:
# 1. SSH connection test
# 2. Destination path check
# 3. Disk space verification
# 4. MD5 checksum generation (source)
# 5. rsync transfer (with progress bar)
# 6. MD5 checksum verification (destination)
# 7. Completion message

# Example progress output:
# [INFO] ... SSH connection test successful
# [INFO] ... Destination path exists
# [INFO] ... Source size: 52G
# [INFO] ... Generating MD5 checksums on source...
# [INFO] ... Starting rsync transfer...
# 123.45M   0%    1.23MB/s    5:32:15 (continuing)
```

**Monitoring Tips:**
- `tail -f` will continue showing new lines as job progresses (exit with `Ctrl+C`)
- For large transfers (>100GB), expect several hours
- Do not interrupt the SLURM job while transfer is running (use `scancel <JOBID>` only if absolutely necessary)

### Step 5: Verify Transfer Completion

```bash
# After job completes, check job status
sacct -j 12345 --format=JobID,JobName,State,ExitCode,Elapsed

# Look for:
# State: COMPLETED
# ExitCode: 0:0 (success)

# Check the final log for summary
tail -30 logs/transfer_12345_*.log

# Expected completion message:
# ========================================
# SLURM UCloud Data Transfer Job
# ========================================
# Transfer Completed Successfully ✓
```

### Step 6: Verify Data on UCloud

```bash
# Connect to UCloud and verify files arrived
ssh ucloud@ssh.cloud.sdu.dk -p 2631

# On UCloud, check destination
ls -lh /work/data_migration/total_lung_TBD/
du -sh /work/data_migration/total_lung_TBD/

# Verify file count matches (account for Logs directory if present)
find /work/data_migration/total_lung_TBD/ -type f | wc -l

# Exit UCloud connection
exit
```

### Step 2b: Login Node Transfer with screen (fallback)

If SLURM compute nodes cannot reach `ssh.cloud.sdu.dk`, run the transfer on the login node inside `screen`:

```bash
# Start a protected screen session
screen -S transfer_TB2998

# Run the transfer inside screen
export UCLOUD_SSH_KEY="$HOME/.ssh/id_rsa"
./scripts/transfer_to_ucloud.sh \
   /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/ \
   /work/data_migration/total_lung_TBD/ \
   2631 \
   ssh.cloud.sdu.dk

# Detach: Ctrl+A, then D
# Reattach: screen -r transfer_TB2998
```

Notes:
- Use the login node only if SLURM jobs cannot reach UCloud
- The same log files are written under `logs/`

## Troubleshooting

### Job Submitted Successfully, but Status Shows "PD" (Pending) for a Long Time

**Cause**: Waiting in SLURM queue for available resources

**Solution:**
```bash
# Check queue load
sinfo

# Try submitting with different partition (may have shorter queue)
# Edit the script or resubmit with:
sbatch -p queue_name scripts/submit_transfer_ucloud.sh ...

# Or just wait—pending jobs typically start within minutes to hours
squeue -u $(whoami)  # Keep checking
```

### Job Status "CA" (Cancelled)

**Cause**: Job was manually cancelled or timed out

**Solution:**
```bash
# Check why it was cancelled
sacct -j <JOBID> --format=JobID,JobName,State,ExitCode

# If timeout: increase SLURM walltime in submit_transfer_ucloud.sh
# Edit line: #SBATCH --time=12:00:00 (currently 12 hours)
# For 100GB+: try 24:00:00 or 48:00:00
```

### Job Status "F" (Failed), ExitCode Non-Zero

**Cause**: Transfer script encountered an error

**Solution:**
```bash
# Find and read the .err file for more details
ls -ltr logs/transfer_<JOBID>_*.err | tail -1
cat logs/transfer_<JOBID>_*.err

# Common errors and fixes:

# 1. SSH connection failed
#    → UCloud job may have stopped
#    → Restart UCloud job with SSH enabled
#    → Update port number in resubmit

# 2. Destination disk full
#    → Check available space on UCloud: df -h /work
#    → Contact UCloud support if quota exceeded

# 3. Source path not found
#    → Verify path is correct: ls <SOURCE_PATH>
#    → Check for typos

# 4. rsync transfer error
#    → Usually transient network issue
#    → Resubmit job: rsync will skip already-transferred files
```

### SSH Connection Fails: "Connection refused"

**Cause**: UCloud job is no longer running or SSH port is incorrect

**Solution:**
```bash
# 1. Check UCloud web interface—is the job still running?
# 2. Verify you're using the CURRENT port (not from a previous job)
# 3. Test connection manually:
ssh ucloud@ssh.cloud.sdu.dk -p <CURRENT_PORT> "echo test"

# If still fails, check your SSH key:
ssh -v ucloud@ssh.cloud.sdu.dk -p <PORT> 2>&1 | grep -i "permission\|key"

# You may need to add ~/.ssh/id_*.pub to UCloud account
```

### Transfer Takes Too Long or Hangs

**Cause**: Network issues, slow destination storage, or large dataset

**Solution:**
```bash
# Monitor rsync details in log:
grep -i "rsync\|bytes\|transfer" logs/transfer_<JOBID>_*.log | tail -20

# For massive datasets (>500GB):
# 1. Consider splitting into smaller batches
# 2. Submit multiple jobs with different directory subsets
# 3. Contact UCloud support about storage performance

# If job appears hung (no progress for hours):
# 1. Check if job is still running: squeue
# 2. Cancel if needed: scancel <JOBID>
# 3. Resubmit: rsync will resume from where it left off
```

## Advanced: Submitting Multiple Transfers

You can submit multiple transfer jobs simultaneously:

```bash
# Transfer TB-2998 fastq
sbatch scripts/submit_transfer_ucloud.sh \
  /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/Analysis/5/Data/fastq/ \
  /work/data_migration/total_lung_TBD/ \
  2631 ssh.cloud.sdu.dk

# Transfer another dataset in parallel
sbatch scripts/submit_transfer_ucloud.sh \
  /srvdata/Projects/another_project/data/ \
  /work/data_migration/another_project/ \
  2631 ssh.cloud.sdu.dk

# Monitor all jobs
squeue -u $(whoami)
```

## Summary

**Quick Checklist:**
- [ ] UCloud job running with SSH enabled
- [ ] SSH connection test successful: `ssh ucloud@ssh.cloud.sdu.dk -p <PORT> "echo test"`
- [ ] Source data accessible on uGerm: `ls <SOURCE_PATH>`
- [ ] Execute submit command: `sbatch scripts/submit_transfer_ucloud.sh ...`
- [ ] Monitor job: `squeue -u $(whoami)` → look for job ID
- [ ] Watch transfer: `tail -f logs/transfer_<JOBID>_*.log`
- [ ] Verify completion: `sacct -j <JOBID>` → State=COMPLETED
- [ ] Confirm data on UCloud: `ssh ucloud@... "ls /work/data_migration/..."`

**For Help:**
- Check log files in `logs/` directory
- Review `.err` file for error messages
- Consult Troubleshooting section above
- Contact INFIMM-Bioinformatics team
