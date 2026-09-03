# UCloud HPC Platform (SDU eScience Center)
## AI Copilot Instructions & Architecture Reference

**Platform**: SDU eScience Center UCloud  
**Document Version**: 1.0  
**Last Updated**: November 2025  
**Author**: [Tu Hu](https://github.com/tuhulab)

---

> **⚠️ Disclaimer**
>
> This document is provided solely by Tu Hu in a personal capacity. It is not affiliated with, endorsed by, or representative of any organization or UCloud. The content is provided "AS IS" without warranties or guarantees. Use at your own risk — you are solely responsible for any decisions or outcomes resulting from its use.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Container Environment](#container-environment)
4. [Storage Architecture](#storage-architecture)
5. [Compute Resources](#compute-resources)
6. [Software Environment](#software-environment)
7. [Job Management](#job-management)
8. [Networking](#networking)
9. [Critical Differences from Traditional HPC](#critical-differences-from-traditional-hpc)
10. [Development Best Practices](#development-best-practices)
11. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
12. [Quick Reference](#quick-reference)

---

## Executive Summary

UCloud is a **containerized HPC platform** running on Kubernetes (k3s), not traditional VMs. This fundamental difference affects service management, process lifecycle, and storage patterns.

**Key Characteristics**:
- **Container Runtime**: k3s with overlay filesystem (ephemeral root)
- **Persistent Storage**: WekaFS distributed filesystem (4.7PB capacity)
- **Init System**: bash (PID 1), NOT systemd
- **Base Image**: User-selectable (Ubuntu, Rocky Linux, Debian, etc.)
- **Module System**: Lmod + EasyBuild for scientific software

---

## System Architecture

### Operating System

**User-Configurable**: The operating system and version are selected when submitting a job in UCloud.

**Common Options**:
- Ubuntu: Various versions (20.04, 22.04, 24.04)
- Rocky Linux / AlmaLinux
- Debian

**To Check Your Environment**:
```bash
cat /etc/os-release      # Distribution details
uname -r                 # Kernel version
lsb_release -a           # Additional release info (if available)
```

### Container Runtime

UCloud jobs run in **Kubernetes pods** managed by k3s:

```bash
# Root filesystem is overlay (ephemeral)
overlay on / type overlay (rw,relatime,...)

# PID 1 is bash, NOT systemd
$ cat /proc/1/comm
bash
```

**Critical Implication**: Standard systemd/init commands DO NOT WORK:
- ❌ `systemctl start service`
- ❌ `service daemon status`
- ✅ Use direct daemon invocation: `sudo daemon_name`

### Hostname Pattern

```
Format: j-<job-id>-job-<replica>
Example: j-5392098-job-0
Full FQDN: j-5392098-job-0.j-5392098.ucloud-apps.svc.cluster.local
```

---

## Container Environment

### Process Management

**PID 1**: `/bin/bash` (not systemd)

```bash
# Check init process
ps -p 1
  PID TTY          TIME CMD
    1 ?        00:00:00 bash
```

**Service Management Strategy**:
```bash
# Traditional approach (DOES NOT WORK)
systemctl start cron         # Error: System has not been booted with systemd

# UCloud approach (CORRECT)
sudo cron                    # Directly starts daemon
ps aux | grep cron           # Verify running
```

### Filesystem Layout

| Mount Point | Type | Size | Persistence | Purpose |
|------------|------|------|-------------|---------|
| `/` | overlay | 1.0TB | Ephemeral | Container root filesystem |
| `/work` | wekafs | 4.7PB | **Persistent** | User data, project files |
| `/etc/hosts` | rbd | 48GB | Ephemeral | Network configuration |
| `/opt` | overlay | - | Ephemeral | Software installations |
| `/home/ucloud` | overlay | - | Ephemeral | User home |

**Key Insight**: Only `/work` survives job restarts. All other changes are lost when the job ends.

---

## Storage Architecture

### WekaFS Distributed Filesystem

```bash
$ df -h /work
Filesystem      Size  Used Avail Use% Mounted on
ucloud          4.7P  3.7P  944T  81% /work
```

**Characteristics**:
- **Technology**: WekaFS (distributed parallel filesystem)
- **Capacity**: 4.7 petabytes total
- **Performance**: Optimized for large-scale data operations
- **Persistence**: Data survives job termination and restarts

### Storage Best Practices

1. **Always use `/work` for persistent data**
   ```bash
   # ✅ Correct
   /work/my-project/data/
   /work/backup-repository/
   
   # ❌ Wrong (will be lost)
   /tmp/important-file
   /opt/custom-install/
   ```

2. **Project Structure**
   ```
   /work/
   ├── ProjectA/           # Main project directory
   ├── ProjectB/           # Another mounted project
   ├── JobParameters.json  # UCloud job metadata
   └── vscode-server/      # VS Code server files
   ```

---

## Compute Resources

### Hardware Specifications

**CPU**:
```
Model:    Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz
Sockets:  2
Cores:    16 per socket (32 total physical cores)
Threads:  2 per core (64 logical CPUs)
Features: AVX-512, AVX2, FMA, SSE4.2
```

**Job Allocation Example** (from JobParameters.json):
```json
{
  "machineType": {
    "cpu": 4,
    "memoryInGigs": 24
  },
  "product": {
    "id": "u1-standard-h-4",
    "category": "u1-standard-h"
  }
}
```

### Resource Categories

Common machine types:
- `u1-standard-h`: Standard compute nodes
- `u1-gpu`: GPU-accelerated nodes

---

## Software Environment

### Module System (Lmod)

```bash
# Lmod is pre-configured
$ echo $MODULEPATH
/opt/easybuild/ubuntu-24.04/intel/modules/all
# Note: Path varies by OS
```

**Usage**:
```bash
# List available modules
module avail

# Load a module
module load GCC/12.3.0
module load Python/3.11.3-GCCcore-12.3.0

# Check loaded modules
module list
```

### EasyBuild Integration

Software is installed via EasyBuild in `/opt/easybuild/<os-distribution>/intel/modules/all/`

---

## Job Management

### Job Parameters

Every job has metadata in `/work/JobParameters.json`:

```json
{
  "request": {
    "application": {
      "name": "terminal-ubuntu",
      "version": "Nov2025"
    },
    "timeAllocation": {
      "hours": 24,
      "minutes": 0,
      "seconds": 0
    },
    "sshEnabled": true
  },
  "machineType": {
    "cpu": 4,
    "memoryInGigs": 24
  }
}
```

### UCloud-Specific Files

Location: `/etc/ucloud/`

- `nodes.txt`: Full node hostname
- `number_of_nodes.txt`: Total replicas in job
- `rank.txt`: This replica's rank (0-indexed)
- `ssh/`: SSH keys for inter-node communication

---

## Networking

### Container Networking

Jobs run in Kubernetes cluster:
```
Namespace: ucloud-apps
Service: j-<job-id>.ucloud-apps.svc.cluster.local
```

### SSH Access

SSH can be enabled per job. Keys stored in `/etc/ucloud/ssh/`

---

## Critical Differences from Traditional HPC

### Service Management

| Feature | Traditional HPC | UCloud Container |
|---------|----------------|------------------|
| Init system | systemd (PID 1) | bash (PID 1) |
| Start services | `systemctl start` | Direct invocation: `sudo daemon` |
| Check status | `systemctl status` | `ps aux \| grep daemon` |
| Enable on boot | `systemctl enable` | N/A (re-run on each job) |

### Filesystem Persistence

| Directory | Traditional HPC | UCloud |
|-----------|----------------|--------|
| `/home/user` | Persistent | Ephemeral |
| `/tmp` | Ephemeral | Ephemeral |
| `/opt` | Persistent | Ephemeral |
| `/work` | N/A | **Persistent (WekaFS)** |

---

## Development Best Practices

### 1. Persistent Storage Strategy

```bash
# All persistent data in /work
export PROJECT_ROOT="/work/my-project"
export DATA_DIR="/work/data"
export BACKUP_DIR="/work/backups"
```

### 2. Service Initialization Pattern

```bash
#!/bin/bash
# /work/init-services.sh

sudo cron
sudo other_daemon

echo "Services initialized at $(date)" >> /work/init.log
```

### 3. Environment Configuration

```bash
# /work/.bashrc_custom
export RESTIC_REPOSITORY=/work/backup-repo
export PROJECT_ROOT=/work/my-project

# Add to ~/.bashrc
if [ -f /work/.bashrc_custom ]; then
    source /work/.bashrc_custom
fi
```

### 4. Package Manager Detection

```bash
if command -v apt-get &> /dev/null; then
    INSTALL_CMD="sudo apt-get update && sudo apt-get install -y"
elif command -v dnf &> /dev/null; then
    INSTALL_CMD="sudo dnf install -y"
elif command -v yum &> /dev/null; then
    INSTALL_CMD="sudo yum install -y"
fi
```

---

## Common Pitfalls and Solutions

### ❌ Pitfall 1: Using systemctl

**Problem**: `sudo systemctl start cron` → Error

**Solution**: `sudo cron` (direct daemon invocation)

### ❌ Pitfall 2: Storing Data Outside /work

**Problem**: Data in `/opt` or `/tmp` lost after job ends

**Solution**: Always use `/work` for persistent data

### ❌ Pitfall 3: Expecting Persistent Cron

**Problem**: Crontab lost after job restart

**Solution**:
```bash
crontab -l > /work/my-crontab   # Save
crontab /work/my-crontab        # Restore on job start
```

### ❌ Pitfall 4: Relative Paths

**Problem**: Scripts fail when working directory changes

**Solution**: Always use absolute paths with `readlink -f`

---

## Quick Reference

### System Information
```bash
cat /etc/os-release          # OS version
uname -r                     # Kernel
hostname                     # Job hostname
hostname | cut -d'-' -f2     # Extract job ID
cat /work/JobParameters.json | jq '.machineType'  # Resources
```

### Storage
```bash
df -h /work                  # Check capacity
du -sh /work/*/              # Directory sizes
```

### Process Management
```bash
ps -p 1                      # Check PID 1
sudo daemon_name             # Start service
pgrep service_name           # Check if running
```

### Environment
```bash
module avail                 # Available modules
module list                  # Loaded modules
module load Python/3.11.3    # Load module
```

---

## Additional Resources

- **UCloud Docs**: https://docs.cloud.sdu.dk/
- **UCloud Hands-on**: https://docs.cloud.sdu.dk/hands-on/use-cases.html
- **Service Desk**: https://support.escience.sdu.dk/
- **Lmod Documentation**: https://lmod.readthedocs.io/
- **WekaFS Documentation**: https://docs.weka.io/

---

## Access & Automation

### Login Methods

UCloud supports two primary login mechanisms:

1.  **SAML / WAYF (SSO)**:
    - The default "Login" button redirects to the WAYF (Where Are You From) service.
    - Used for university credentials (e.g., SDU, AU, KU).

2.  **Local Credentials**:
    - Accessed via the "**Other login options →**" link on the login page.
    - Requires **Username** (e.g., `User#1234`) and **Password**.
    - **Two-Factor Authentication (2FA)**: A 6-digit TOTP code is required after password submission.

### Automation Notes

- **URL**: `https://cloud.sdu.dk/app`
- **Project Context**: The active project is displayed in the **top right corner** (e.g., "BINF INFIMM"). Jobs are billed to and run within this project. **Always verify** the correct project is selected before exploring apps or starting jobs. Click the project name to switch contexts.
- **2FA Handling**: Automated agents must pause to request the 2FA code or use a programmatic TOTP generator if the secret is available.
- **Job Submission**: Jobs are submitted via the "Apps" interface. The `terminal-ubuntu` app provides a standard environment.
- **Input Field Caution**: When setting job duration (e.g., "Hours"), the input field may have a default value. Automation scripts must **clear the field** before typing to avoid appending values (e.g., typing "1" into a field with "1" results in "11").
- **Stopping Applications**: The "Stop application" button features an "anti-dump" mechanism. It requires a **Long Click** (press and hold for ~2-3 seconds) to trigger. Standard clicks will not stop the job.
- **Cleanup Protocol**: Automated agents should **always prompt the user** after a job session to ask if the job should be stopped (using the Long Click method) to prevent unnecessary resource usage.
- **Backup Implementation** (Added Dec 2025):
    - **Strategy**: Periodic backup using `restic` (snapshot-based, incremental).
    - **Source**: `TB group` drive (mount to `/work/TB_group`).
    - **Destination**: `Data_backup` drive (mount to `/work/Data_backup`).
    - **Setup**:
        1.  **Critical**: Ensure drives are mounted correctly in the job configuration. For "TB group", verify it appears in `/work` after starting the job.
        2.  Copy the `restic_wrapper.sh` script to the destination drive (or `/work`).
        3.  Create a secure password file (e.g., `restic_pw.txt`).
        4.  Run: `./restic_wrapper.sh backup -r /work/Data_backup/repo -s /work/TB_group -p /work/Data_backup/restic_pw.txt`.

## Changelog

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | November 2025 | Initial release |
| 1.1 | December 2025 | Added Access & Automation section |

