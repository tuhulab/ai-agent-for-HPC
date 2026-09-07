---
name: data-transfer
description: Cross-platform data transfer with MD5 integrity verification, background resilience (screen/SLURM), and automated logging across S-Drive, uGerm HPC, Computerome, and UCloud. Use for transferring datasets to UCloud HPC.
---

# Cross-Platform Data Transfer Skill

This skill provides automated transfer scripts, background process resilience, and end-to-end MD5 integrity verification for moving datasets to UCloud HPC.

---

## 1. Connection Discovery & Prerequisites

### 1.1 UCloud SSH Connection Details
1. Start an SSH-enabled job on [UCloud](https://cloud.sdu.dk/app).
2. Find connection details on the job's progress page:
   - **Gateway Host**: `ssh.cloud.sdu.dk`
   - **User**: `ucloud`
   - **Port**: Per-job dynamic port (e.g. `52143` or `2631`) — **never hardcode**.
3. Confirm persistent destination folder exists on UCloud (e.g. `/work/TB_group/data_migration` or `/work/data_migration`).

### 1.2 SSH Config Alias (Optional for SSI Network / ProxyJump)
Add to `~/.ssh/config` on your local machine or login node:

```sshconfig
Host ucloud
  HostName ssh.cloud.sdu.dk
  User ucloud
  Port 52143            # Set current job's port
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

---

## 2. Transfer Scenarios

### Scenario A: Local Mac / S-Drive $\rightarrow$ UCloud (Direct or Staged)
- **Tool**: `scripts/transfer/transfer_to_ucloud.sh`
- **Workflow Guide**: [`skills/data-transfer/S_to_UCloud.md`](S_to_UCloud.md)

```bash
# 1. Start protected screen session
screen -S data_transfer

# 2. Run transfer script (rsync + MD5 verification)
./scripts/transfer/transfer_to_ucloud.sh \
  /path/to/source_data \
  /work/TB_group/data_migration/dataset_name \
  <UCLOUD_PORT> \
  ssh.cloud.sdu.dk

# 3. Detach: Ctrl+A, then D. Reattach later: screen -r data_transfer
```

---

### Scenario B: uGerm HPC Cluster $\rightarrow$ UCloud (via SLURM Queue)
- **Tool**: `scripts/transfer/submit_transfer_ucloud.sh`
- **Workflow Guide**: [`skills/data-transfer/uGerm_to_UCloud.md`](uGerm_to_UCloud.md)

```bash
# 1. Submit transfer job to SLURM
sbatch scripts/transfer/submit_transfer_ucloud.sh \
  /srvdata/Projects/shll_INFIMM/proj/sequence_data/TB-2998/fastq/ \
  /work/TB_group/data_migration/total_lung_TBD/ \
  <UCLOUD_PORT> \
  ssh.cloud.sdu.dk

# 2. Monitor job status
squeue -u $(whoami)
tail -f logs/transfer_<JOB_ID>_*.log
```

---

### Scenario C: Computerome (`cu_10181`) $\rightarrow$ UCloud Migration
- **Documentation & Manifests**: [`docs/data-management/`](../../docs/data-management/)
- **Tools**: `scripts/migration/dry_run.py`, `scripts/migration/migrate.sh`

```bash
# 1. Validate manifest before transfer
python3 scripts/migration/dry_run.py \
  --manifest docs/data-management/runbook/manifest_raw.csv

# 2. Execute migration with rsync
./scripts/migration/migrate.sh
```

---

## 3. Integrity Verification Protocol

The transfer tooling enforces strict integrity verification:

1. **Source Checksums**: Generates source MD5 hash table (`find <src> -type f -exec md5 / md5sum`).
2. **Transfer**: Executes `rsync -avzP --stats` over SSH with compression and attribute preservation.
3. **Destination Checksums**: Remotely computes destination MD5 hashes via SSH.
4. **Comparison**: Normalizes macOS `md5` vs Linux `md5sum` formats, performs `diff`, and flags any mismatches.
5. **Immutable Audit Logs**: Writes timestamped logs to `logs/transfer_YYYYMMDD_HHMMSS.log` and locks with `chmod 444`.

---

## 4. Troubleshooting

| Issue | Cause | Resolution |
|---|---|---|
| `Connection refused` | Job not running or wrong port | Verify job state on UCloud; check SSH port widget on progress page. |
| `Checksum mismatch` | Network corruption or concurrent write | Re-run `transfer_to_ucloud.sh`; rsync will only re-transmit failed chunks. |
| `Slow transfer from S-Drive` | SMB latency over network | Stage dataset to local SSD first, then transfer to UCloud. |
| `SLURM job network failure` | Compute nodes blocked from external internet | Run transfer inside a `screen` session on the uGerm login node instead of batch worker nodes. |
