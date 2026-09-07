---
name: data-backup
description: Automated incremental backup, point-in-time snapshot recovery, retention pruning, and cron automation on UCloud using Restic. Use for dataset backup, snapshot management, and disaster recovery.
---

# UCloud Data Backup Skill (Restic)

This skill provides an automated, encrypted, and deduplicated backup solution using [Restic](https://restic.net/) for data protection on UCloud infrastructure (WekaFS storage).

---

## 1. System Architecture & Prerequisites

### 1.1 Storage Setup on UCloud
- **Working Source**: `/work/TB_group` (or primary mounted working drive, Folder #1)
- **Backup Target**: `/work/Data_backup/repo` (or secondary mounted backup drive, Folder #2)
- **Password File**: `/work/Data_backup/restic_pw.txt` (permissions `600`)

> ⚠️ **Persistence Reminder**: On UCloud, only files inside mounted subdirectories (`/work/TB_group/`, `/work/Data_backup/`) survive job restarts. Never store repositories or password files in top-level `/work/`, `/home`, or `/tmp`.

### 1.2 Initial Setup
```bash
# 1. Create a secure password file inside the mounted backup drive
openssl rand -base64 32 > /work/Data_backup/restic_pw.txt
chmod 600 /work/Data_backup/restic_pw.txt

# 2. Verify mounts
ls -d /work/TB_group /work/Data_backup
```

---

## 2. Core Backup CLI (`scripts/backup/restic_wrapper.sh`)

The wrapper script automatically installs Restic + cron (if missing), initializes the repository, executes the backup snapshot, and configures a periodic cron job.

### 2.1 Basic Backup
```bash
./scripts/backup/restic_wrapper.sh backup \
  -r /work/Data_backup/repo \
  -s /work/TB_group \
  -p /work/Data_backup/restic_pw.txt
```

### 2.2 Backup with Exclusion Patterns
```bash
./scripts/backup/restic_wrapper.sh backup \
  -r /work/Data_backup/repo \
  -s /work/TB_group \
  -p /work/Data_backup/restic_pw.txt \
  --exclude "*.tmp" \
  --exclude "*.fastq" \
  --exclude "/work/TB_group/.cache"
```

### 2.3 Batch Dataset Backups
To back up multiple datasets across `/work/TB_group` while skipping test datasets:

```bash
./scripts/backup/run_incremental_backups.sh
```

Or run via `screen` for large multi-hour initial uploads:
```bash
screen -dmS backup_job bash -c './scripts/backup/run_incremental_backups.sh'
# Monitor with: screen -r backup_job (detach: Ctrl+A, then D)
# View logs: tail -f /work/Data_backup/backup.log
```

---

## 3. Resuming Backups After Job Restart

On UCloud, when a job restarts or is rescheduled:
- ✅ **Persists**: Repositories, snapshots, password files, and data in `/work/Data_backup/` and `/work/TB_group/`.
- ❌ **Does NOT persist**: Background cron daemons (`cron`), screen sessions, and running processes.

### 3.1 Job Resumption Checklist
1. **Verify repository integrity**:
   ```bash
   restic -r /work/Data_backup/repo --password-file /work/Data_backup/restic_pw.txt snapshots
   ```
2. **Restart cron daemon and register scheduled backup**:
   ```bash
   sudo cron
   ./scripts/backup/restic_wrapper.sh backup \
     -r /work/Data_backup/repo \
     -s /work/TB_group \
     -p /work/Data_backup/restic_pw.txt
   ```
   *Note: Because Restic is content-addressable and deduplicated, re-running the backup will scan and only upload newly created or modified files.*

---

## 4. Snapshot Management & Pruning

### 4.1 List Snapshots
```bash
restic -r /work/Data_backup/repo \
  --password-file /work/Data_backup/restic_pw.txt snapshots
```

### 4.2 Check Repository Integrity
```bash
restic -r /work/Data_backup/repo \
  --password-file /work/Data_backup/restic_pw.txt check
```

### 4.3 Retention Policy & Space Pruning
Prune old snapshots to stay within storage quotas (e.g. keep last 10 snapshots):

```bash
# 1. Forget old snapshots according to retention policy
restic -r /work/Data_backup/repo \
  --password-file /work/Data_backup/restic_pw.txt forget \
  --keep-last 10 \
  --keep-daily 7 \
  --keep-weekly 4

# 2. Prune unreferenced blobs to free physical disk space
restic -r /work/Data_backup/repo \
  --password-file /work/Data_backup/restic_pw.txt prune
```

---

## 5. Point-in-Time Restoration

### 5.1 Restore Latest Snapshot
```bash
./scripts/backup/restic_wrapper.sh restore \
  -r /work/Data_backup/repo \
  -t /work/TB_group/restored_data \
  -p /work/Data_backup/restic_pw.txt
```

### 5.2 Restore a Specific Snapshot ID
```bash
restic -r /work/Data_backup/repo \
  --password-file /work/Data_backup/restic_pw.txt \
  restore <SNAPSHOT_ID> \
  --target /work/TB_group/restored_snapshot \
  --host UCloud
```

---

## 6. Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| `unable to open password file` | Wrong path or permissions | Verify password file exists in mounted directory; `chmod 600`. |
| `repository master key and config already exist` | Repo already initialized | Expected behavior; wrapper proceeds automatically with backup. |
| `cron not executing` | `cron` daemon not running | Run `sudo cron` and check `crontab -l`. |
| `out of space on /work` | Stale snapshots consuming space | Run `restic forget --keep-last 10` followed by `restic prune`. |
