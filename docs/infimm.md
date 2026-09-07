# INFIMM Bioinformatics Core — UCloud HPC Reference & AI Agent Instructions

**Platform**: SDU eScience Center UCloud (INFIMM Bioinformatics Environment)  
**Document Version**: 1.0  
**Last Updated**: September 2026  
**Author**: [Tu Hu](https://github.com/tuhulab) / [INFIMM Bioinformatics](https://github.com/INFIMM-Bioinformatics)

---

## 🎯 Executive Summary

This document provides lab-specific conventions, storage topologies, automated backup procedures, and AI agent instructions tailored for the **INFIMM Bioinformatics Core**.

All researchers and AI assistants operating in the INFIMM environment should adhere to the rules in this document in conjunction with the general [UCloud HPC Architecture Reference](ucloud-sdu.md).

---

## 🏛️ Workspace & Project Context

| Setting | Value | Notes |
|---|---|---|
| **Primary Workspace** | `BINF INFIMM` | Select via top-right dropdown on `https://cloud.sdu.dk/app` |
| **Provider** | `DeiC Interactive HPC (SDU/K8s)` | Default K8s container provider |
| **Compute Products** | `cpu-amd-zen5` / `gpu-nvidia-b200` | AMD EPYC 9535 (1–128 vCPU) / NVIDIA B200 |
| **Storage Architecture** | WekaFS (4.7PB shared volume) | Mounted per folder under `/work/<FOLDER>` |

> ⚠️ **Verification Checklist**: Before launching any job, check the **top-right workspace dropdown** to confirm that `BINF INFIMM` is selected. Submitting under "My workspace" bills the wrong allocation and prevents access to shared project drives.

---

## 💾 Storage Topology & Drive Conventions

On UCloud, the `/work` root directory is an **ephemeral mount point**. Only the folders explicitly attached during job launch persist across runs.

```
/work/                                   # Container mount namespace (ephemeral root)
├── TB_group/                            # Primary working drive (Folder #1) — PERSISTENT
│   ├── raw_data/                        # Raw sequencing data (read-only recommended)
│   ├── analysis/                        # Active analysis projects
│   ├── venvs/                           # Shared Python virtual environments
│   └── conda_envs/                      # Shared Conda/Mamba environments
├── Data_backup/                         # Backup repository drive (Folder #2) — PERSISTENT
│   ├── repo/                            # Restic backup repository
│   └── restic_pw.txt                    # Secure password file for restic
├── JobParameters.json                   # Job execution metadata (ephemeral)
└── job-report.csv                       # Resource sampling report (ephemeral)
```

### Drive Mapping Rules

1. **Working Data (`TB group`)**:
   - In the job create form, attach `TB group` as **Folder #1**.
   - Accessible in-container at `/work/TB_group/`.
   - All scripts, inputs, virtual environments, and outputs **must** reside inside `/work/TB_group/` or another mounted project directory.

2. **Backup Storage (`Data_backup`)**:
   - In jobs performing backups, attach `Data_backup` as **Folder #2**.
   - Accessible in-container at `/work/Data_backup/`.

3. **Session Output Archival**:
   - Any unmounted files accidentally created directly under `/work/` (e.g. `/work/my-repo`) are saved to the member's personal archive upon job completion:
     ```
     /Member Files: <User#Tag> (<DriveID>)/Jobs/<AppName>/<JobID>/<User#Tag>/
     ```
   - To recover, navigate to `Files` (`/app/drives`) in the web portal and move the files into `/work/TB_group/`.

---

## 🔄 Automated Backup Protocol (Restic)

The INFIMM environment uses `scripts/restic_wrapper.sh` for incremental snapshot backups from the working drive to the backup drive.

### Setup & Execution

When launching a backup job, attach both `TB group` and `Data_backup` folders:

```bash
# 1. Verify mounts
ls -d /work/TB_group /work/Data_backup

# 2. Run backup and register automated 2-hour cron job
./scripts/restic_wrapper.sh backup \
  -r /work/Data_backup/repo \
  -s /work/TB_group \
  -p /work/Data_backup/restic_pw.txt

# 3. Verify crontab and restic snapshots
crontab -l
restic -r /work/Data_backup/repo --password-file /work/Data_backup/restic_pw.txt snapshots
```

### Restoring from Backup

```bash
./scripts/restic_wrapper.sh restore \
  -r /work/Data_backup/repo \
  -p /work/Data_backup/restic_pw.txt
```

---

## 🧬 Standard Bioinformatics Pipelines & Environment Setup

### 1. Virtual Environments
Always create venvs inside the mounted working directory:

```bash
# Python venv
python3 -m venv /work/TB_group/venvs/rnaseq-env
source /work/TB_group/venvs/rnaseq-env/bin/activate
pip install --cache-dir /work/TB_group/.cache/pip scanpy scrublet anndata
```

### 2. Environment Modules (Lmod)
UCloud provides AMD/Intel optimized EasyBuild modules:

```bash
source /opt/lmod/lmod/init/bash
module use $MODULEPATH

# Standard Bioinformatics Tools
module load GCC/13.3.0
module load OpenMPI/5.0.10
module load Python/3.12.3-GCCcore-13.3.0
```

### 3. Nextflow / nf-core Execution
For I/O-intensive pipelines (e.g. `nf-core/rnaseq`, `nf-core/sarek`):

```bash
# Use /tmp for scratch work and intermediate task directories
export NXF_WORK=/tmp/nxf_work
mkdir -p /tmp/nxf_work

# Direct final pipeline results to the persistent mounted drive
nextflow run nf-core/rnaseq \
  -profile singularity \
  -work-dir /tmp/nxf_work \
  --outdir /work/TB_group/analysis/rnaseq_results \
  -resume
```

---

## 🤖 AI Agent Quick Start

### For GitHub Copilot / Cursor
Reference this document in your `.github/copilot-instructions.md` or `.cursorrules`:

```bash
curl -o .github/copilot-instructions.md https://raw.githubusercontent.com/INFIMM-Bioinformatics/ai-agent-for-HPC/main/docs/infimm.md
```

### For Pi Coding Agent
Install the HPC skill package directly:

```bash
# From INFIMM repository
pi install git:github.com/INFIMM-Bioinformatics/ai-agent-for-HPC

# Or from upstream
pi install git:github.com/tuhulab/ai-agent-for-HPC
```

---

## 📋 Critical Rules for AI Agents

1. **Project Context**: Ensure the active workspace is `BINF INFIMM`.
2. **Mount Awareness**: Verify that persistent data is written to `/work/TB_group/...` (never write persistent outputs directly to `/work/`).
3. **Hold-to-Stop**: When stopping applications or canceling reservations in automated scripts, use the press-and-hold action (~3 seconds) to satisfy UCloud's anti-dump mechanism.
4. **Scratch Storage**: Use `/tmp` for compilations and large intermediate files, syncing finished outputs into `/work/TB_group/`.
