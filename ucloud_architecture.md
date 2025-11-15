# UCloud HPC Platform Architecture Reference

**Version**: 1.0  
**Last Updated**: November 12, 2025  
**Platform**: SDU eScience Center UCloud  
**Purpose**: Comprehensive architecture reference for AI coding agents and developers

---

> Disclaimer
>
> This document is provided solely by Tu Hu (GitHub: tuhulab) in a personal capacity. It is not affiliated with, endorsed by, or representative of any organization or UCloud. The content is provided "AS IS" without warranties or guarantees; no responsibility or liability is accepted for any use, decisions, or outcomes. Use this document at your own risk — you are solely responsible for how you use it.


## Executive Summary

UCloud is a **containerized HPC platform** running on Kubernetes (k3s), not traditional VMs. This fundamental difference affects service management, process lifecycle, and storage patterns. Key characteristics:

- **Container Runtime**: k3s with overlay filesystem (ephemeral root)
- **Persistent Storage**: WekaFS distributed filesystem (4.7PB capacity, but not all is usable. The user group, INFIMM, pays for 20 TB at the time of writing.)
- **Init System**: bash (PID 1), NOT systemd
- **Base Image**: User-selectable (Ubuntu, Rocky Linux, Debian, etc. - versions vary)
- **Module System**: Lmod + EasyBuild for scientific software

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Container Environment](#container-environment)
3. [Storage Architecture](#storage-architecture)
4. [Compute Resources](#compute-resources)
5. [Software Environment](#software-environment)
6. [Job Management](#job-management)
7. [Networking](#networking)
8. [Critical Differences from Traditional HPC](#critical-differences-from-traditional-hpc)
9. [Development Best Practices](#development-best-practices)
10. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)

---

## System Architecture

### Operating System

**User-Configurable**: The operating system and version are selected when submitting a job in UCloud. The platform supports multiple distributions and versions.

**Current Session** (example - varies by job configuration):
```
Distribution:  Ubuntu 24.04.3 LTS (Noble Numbat)
Kernel:        5.15.186.el8
Architecture:  x86_64
```

**Common Options**:
- Ubuntu: Various versions (20.04, 22.04, 24.04)
- Rocky Linux / AlmaLinux
- Debian
- Other distributions as available in the UCloud app catalog

**To Check Your Environment**:
```bash
cat /etc/os-release      # Distribution details
uname -r                 # Kernel version
lsb_release -a          # Additional release info (if available)
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
| `/work` | wekafs | 4.7PB | Persistent | User data, project files |
| `/etc/hosts` | rbd | 48GB | Ephemeral | Network configuration |
| `/opt` | overlay | - | Ephemeral | Software installations |
| `/home/ucloud` | overlay | - | Ephemeral | User home (some files persist) |

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
- **Multi-tenancy**: Projects can be mounted as subdirectories

**Mount Options**:
```bash
ucloud on /work type wekafs (rw,relatime,context=system_u:object_r:wekafs_t:s0,
writecache,readahead_kb=32768,dentry_max_age_positive=1000,
dentry_max_age_negative=0,container_name=client)
```

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

3. **File Permissions**
   - Default user: `ucloud` (uid=11042, gid=11042)
   - User has `sudo` access
   - WekaFS respects POSIX permissions

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
NUMA:     2 nodes
```

**Memory**:
```bash
$ free -h
              total        used        free      shared  buff/cache   available
Mem:          376Gi        68Gi       176Gi       604Mi       135Gi       308Gi
Swap:         8.0Gi       382Mi       7.6Gi
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
- Variations: Different CPU/memory/GPU configurations

---

## Software Environment

### Pre-installed Tools

**System Tools** (availability varies by OS selection):
- Python 3.x (version depends on base image)
- Git, curl, wget
- Build essentials (gcc, make, cmake)
- Common utilities (tmux, vim, nano)

**Example from Ubuntu 24.04**:
- Python 3.12.3 with pip 24.0
- Restic 0.16.4 (backup tool)
- tmux, zsh, bash

**Development**:
- Sudo access for package installation
- Package manager (apt for Ubuntu/Debian, dnf/yum for Rocky/Alma)
- Module system (Lmod)

### Module System (Lmod)

**Environment Setup**:
```bash
# Lmod is pre-configured (availability depends on base image)
$ echo $LMOD_VERSION
8.7

$ echo $MODULEPATH
/opt/easybuild/ubuntu-24.04/intel/modules/all
# Note: Path varies by OS (e.g., rocky-linux-9, ubuntu-22.04, etc.)
```

**Available Software** (partial list):
- Compiler toolchains: GCC 11.3-14.3, Intel compilers
- MPI: OpenMPI, Intel MPI
- Math libraries: FFTW, BLAS, LAPACK, ScaLAPACK
- Python: Multiple versions with scientific packages
- AI/ML: CUDA, cuDNN, PyTorch, TensorFlow
- Data science: R, Julia, Jupyter
- Bioinformatics: BioPython, ASE, various tools

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

Example paths:
- `/opt/easybuild/ubuntu-24.04/intel/modules/all/`
- `/opt/easybuild/rocky-linux-9/intel/modules/all/`
- `/opt/easybuild/ubuntu-22.04/intel/modules/all/`

This provides:
- Reproducible builds
- Dependency management
- Version control
- Optimized compilation flags for the host architecture

---

## Job Management

### Job Parameters

Every job has metadata in `/work/JobParameters.json`:

```json
{
  "siteVersion": 3,
  "request": {
    "application": {
      "name": "terminal-ubuntu",
      "version": "Nov2025"
    },
    "product": {
      "id": "u1-standard-h-4",
      "category": "u1-standard-h",
      "provider": "ucloud"
    },
    "replicas": 1,
    "timeAllocation": {
      "hours": 24,
      "minutes": 0,
      "seconds": 0
    },
    "resources": [
      {
        "type": "file",
        "path": "/1098321",
        "readOnly": false
      }
    ],
    "sshEnabled": true
  },
  "machineType": {
    "cpu": 4,
    "memoryInGigs": 24
  }
}
```

### Script Parameters

Additional configuration in `/work/.script-params.yaml`:

```yaml
ucloud:
  application:
    name: terminal-ubuntu
    version: Nov2025
  jobId: "5392098"
  machine:
    category: u1-standard-h
    cpu: 4
    cpuModel: Intel Xeon Gold 6130
    gpu: 0
    memoryInGigs: 24
    name: u1-standard-h-4
  nodes: 1
  rank: 0
```

### UCloud-Specific Files

Location: `/etc/ucloud/`

```bash
$ ls -la /etc/ucloud/
dr-xr-xr-x. 3 root   root   95 Nov 12 13:39 .
-rw-r--r--. 1 root   root   56 Nov 12 13:39 node-0.txt
-rw-r--r--. 1 root   root   56 Nov 12 13:39 nodes.txt
-rw-r--r--. 1 root   root    2 Nov 12 13:39 number_of_nodes.txt
-rw-r--r--. 1 root   root    2 Nov 12 13:39 rank.txt
drwx------. 2 ucloud ucloud 36 Nov 12 13:39 ssh/
```

**Contents**:
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

SSH can be enabled per job:
```json
"sshEnabled": true
```

Keys stored in `/etc/ucloud/ssh/`

### Web Services

Applications can expose web interfaces (via ingress configuration in `resolvedResources`)

---

## Critical Differences from Traditional HPC

### Service Management

| Feature | Traditional HPC | UCloud Container |
|---------|----------------|------------------|
| Init system | systemd (PID 1) | bash (PID 1) |
| Start services | `systemctl start` | Direct invocation: `sudo daemon` |
| Check status | `systemctl status` | `ps aux \| grep daemon` |
| Enable on boot | `systemctl enable` | N/A (re-run on each job) |
| Service logs | `journalctl -u service` | Custom logging to `/work/` |

### Filesystem Persistence

| Directory | Traditional HPC | UCloud |
|-----------|----------------|--------|
| `/home/user` | Persistent | Mostly ephemeral* |
| `/tmp` | Ephemeral | Ephemeral |
| `/opt` | Persistent | Ephemeral |
| `/work` | N/A | **Persistent (WekaFS)** |
| Root `/` | Persistent | Ephemeral (overlay) |

*Some dotfiles in `/home/ucloud` may persist via volume mounts

### Process Lifecycle

**Traditional HPC**:
```
Boot → systemd → All services start → User logs in
```

**UCloud**:
```
Container starts → bash (PID 1) → User script runs → 
Manual service startup required
```

### Cron Jobs

**Traditional**: `crontab -e` → Persistent across reboots  
**UCloud**: `crontab -e` → Persists only during job lifetime

```bash
# Must start cron daemon manually
sudo cron

# Then add jobs
crontab -e
```

---

## Development Best Practices

### 1. Persistent Storage Strategy

```bash
# All persistent data in /work
export PROJECT_ROOT="/work/my-project"
export DATA_DIR="/work/data"
export BACKUP_DIR="/work/backups"

# Use absolute paths
REPO=$(readlink -f "/work/repository")
```

### 2. Service Initialization Pattern

Create an initialization script in `/work`:

```bash
#!/bin/bash
# /work/init-services.sh

# Start required services
sudo cron
sudo other_daemon

# Verify services
ps aux | grep -E "cron|other_daemon"

# Log startup
echo "Services initialized at $(date)" >> /work/init.log
```

Make it executable and run on job start.

### 3. Environment Configuration

Persist environment variables in `/work/.bashrc_custom`:

```bash
# /work/.bashrc_custom
export RESTIC_REPOSITORY=/work/backup-repo
export RESTIC_PASSWORD_FILE=/work/.backup-password
export PROJECT_ROOT=/work/my-project

# Add to ~/.bashrc
if [ -f /work/.bashrc_custom ]; then
    source /work/.bashrc_custom
fi
```

### 4. Logging Best Practices

```bash
# Always log to /work
LOG_DIR="/work/logs"
mkdir -p "$LOG_DIR"

# Application logs
./my-app 2>&1 | tee -a "$LOG_DIR/app-$(date +%Y%m%d).log"

# Cron job logs
0 * * * * /work/scripts/backup.sh >> /work/logs/backup.log 2>&1
```

### 5. Dependency Management

```bash
# Check if dependency exists before installing
if ! command -v restic &> /dev/null; then
    # Use appropriate package manager for your OS
    # Ubuntu/Debian:
    sudo apt-get update && sudo apt-get install -y restic
    
    # Rocky Linux/AlmaLinux/CentOS:
    # sudo dnf install -y restic
    # or: sudo yum install -y restic
fi

# Use modules when available (OS-independent)
module load Python/3.11.3-GCCcore-12.3.0
```

**Package Manager Detection**:
```bash
# Auto-detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get update && sudo apt-get install -y"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    INSTALL_CMD="sudo yum install -y"
fi
```

### 6. Job Metadata Utilization

```python
#!/usr/bin/env python3
import json

# Read job parameters
with open('/work/JobParameters.json') as f:
    params = json.load(f)

# Extract useful info
job_id = params['request']['application']['name']
cpu_count = params['machineType']['cpu']
memory_gb = params['machineType']['memoryInGigs']

# Configure based on resources
num_workers = cpu_count
max_memory = f"{memory_gb - 2}G"  # Reserve 2GB for system
```

---

## Common Pitfalls and Solutions

### ❌ Pitfall 1: Using systemctl

**Problem**:
```bash
sudo systemctl start cron
# Error: System has not been booted with systemd as init system (PID 1). Can't operate.
```

**Solution**:
```bash
sudo cron  # Direct daemon invocation
ps aux | grep cron  # Verify running
```

### ❌ Pitfall 2: Storing Data Outside /work

**Problem**:
```bash
# Install software in /opt
sudo apt-get install my-tool
# Lost when job ends!
```

**Solution**:
```bash
# Install to /work
pip install --user --target=/work/python-packages my-tool
export PYTHONPATH=/work/python-packages:$PYTHONPATH
```

### ❌ Pitfall 3: Expecting Persistent Cron

**Problem**:
```bash
crontab -e  # Add jobs
# Job ends and restarts
crontab -l  # Jobs are gone!
```

**Solution**:
```bash
# Store crontab in /work
crontab -l > /work/my-crontab

# Restore on job start
sudo cron
crontab /work/my-crontab
```

### ❌ Pitfall 4: Relative Paths

**Problem**:
```bash
./backup.sh -r repo -s data  # Fails when CWD changes
```

**Solution**:
```bash
# Always use absolute paths
REPO=$(readlink -f "/work/repo")
./backup.sh -r "$REPO" -s "$(readlink -f /work/data)"
```

### ❌ Pitfall 5: Ignoring WekaFS Performance

**Problem**:
```bash
# Many small file operations
for file in /work/data/*.txt; do
    process_file "$file"  # Slow due to network filesystem
done
```

**Solution**:
```bash
# Batch operations or use local tmp
rsync -a /work/data/ /tmp/data/
for file in /tmp/data/*.txt; do
    process_file "$file"  # Faster on local storage
done
rsync -a /tmp/data/ /work/data/
```

---

## Troubleshooting Guide

### Service Won't Start

```bash
# Check if already running
ps aux | grep service_name

# Check for permission issues
sudo service_name

# Check logs (if available)
tail -f /work/logs/service.log
```

### Cron Jobs Not Running

```bash
# Verify cron daemon is running
ps aux | grep cron
# If not: sudo cron

# Check crontab syntax
crontab -l

# Check cron execution (wait for scheduled time)
tail -f /work/backup.log

# Test command manually
/bin/bash -c "command_from_crontab"
```

### Out of Disk Space

```bash
# Check /work usage
df -h /work

# Check root overlay (temporary)
df -h /

# Find large files
du -sh /work/* | sort -h | tail -10

# Clean up if needed
restic forget --keep-last 5  # For backup repositories
rm -rf /work/tmp/*
```

### Module Load Failures

```bash
# Check module is available
module avail ModuleName

# Check dependencies
module show ModuleName/Version

# Purge and reload
module purge
module load GCC/12.3.0
module load Python/3.11.3
```

---

## Quick Reference Commands

### System Information
```bash
# OS version and distribution
cat /etc/os-release

# Detailed OS info
lsb_release -a 2>/dev/null || cat /etc/*-release

# Kernel
uname -r

# Hostname
hostname

# Job ID (extract from hostname)
hostname | cut -d'-' -f2

# Resources allocated
cat /work/JobParameters.json | jq '.machineType'

# Package manager detection
command -v apt-get &> /dev/null && echo "apt-get (Debian/Ubuntu)"
command -v dnf &> /dev/null && echo "dnf (Fedora/Rocky/Alma)"
command -v yum &> /dev/null && echo "yum (CentOS/RHEL)"
```

### Storage
```bash
# Check /work usage and capacity
df -h /work

# Find large directories
du -sh /work/*/ | sort -h

# Count files
find /work -type f | wc -l
```

### Process Management
```bash
# Check PID 1
ps -p 1

# List all user processes
ps aux | grep ucloud

# Start service daemon
sudo daemon_name

# Check if service running
pgrep service_name
```

### Environment
```bash
# Available modules
module avail

# Loaded modules
module list

# Python packages
pip list

# Environment variables
env | sort
```

---

## Additional Resources

### Official Documentation
- **UCloud Docs**: https://docs.cloud.sdu.dk/
- **UCloud Hands-on**: https://docs.cloud.sdu.dk/hands-on/use-cases.html
- **Service Desk**: https://support.escience.sdu.dk/

### Module System
- **Lmod Documentation**: https://lmod.readthedocs.io/
- **EasyBuild**: https://easybuild.io/

### WekaFS
- **WekaFS Documentation**: https://docs.weka.io/

---

## Changelog

### Version 1.0 (November 12, 2025)
- Initial comprehensive architecture documentation
- Detailed container environment analysis
- Storage architecture with WekaFS specifics
- Service management patterns for containerized environment
- Best practices and common pitfalls
- Complete troubleshooting guide
- **Clarification**: OS and version are user-selectable (not fixed to Ubuntu 24.04)
- Added package manager detection patterns for cross-distribution compatibility

---

**Contributing**: This is a living document. Update as the platform evolves or new patterns emerge.
