# UCloud Virtual Machine (`vm-ubuntu`)
## AI Agent & Developer Architecture Reference

**Platform**: SDU eScience Center UCloud  
**Document Version**: 1.0  
**Last Updated**: September 2026  
**Author**: [Tu Hu](https://github.com/tuhulab)

---

> **⚠️ Disclaimer**
>
> This document is provided solely in a personal capacity for researchers, engineers, and autonomous AI agents working in UCloud HPC environments. The content is provided "AS IS" without warranties or guarantees.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Comparison: VM vs Container](#architecture-comparison-vm-vs-container)
3. [System & Hardware Specifications](#system--hardware-specifications)
4. [Storage Topology & Persistence](#storage-topology--persistence)
5. [Network & SSH Access](#network--ssh-access)
6. [Agent & Developer Environment Setup](#agent--developer-environment-setup)
7. [Lifecycle & Credit Management](#lifecycle--credit-management)
8. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
9. [Quick Reference Cheatsheet](#quick-reference-cheatsheet)

---

## Executive Summary

`vm-ubuntu` on UCloud is a **true KVM hardware virtual machine** running on dedicated hypervisors, fundamentally different from standard UCloud containerized applications (such as `terminal-ubuntu` or `coder` which run in Kubernetes pods).

### Key Characteristics:
- **Virtualization**: Hardware KVM (`systemd-detect-virt` $\rightarrow$ `kvm`), dedicated guest kernel.
- **Init System**: Native **systemd** running as PID 1 (`systemctl` and daemon services work normally).
- **Docker Support**: **Full Docker and container daemon support** (`docker.io`, `docker-compose`).
- **Storage**: Dedicated **200 GB native ext4 virtual block disk** for the root OS (`/dev/vda1`), combined with high-speed **`virtiofs` mounts** for UCloud project drives (`/work/<FOLDER>`).
- **User Privileges**: Full **passwordless `sudo`** for the default `ucloud` user.
- **Credit Suspension**: Supports **"Power off" (Pause)**—compute core-hour billing halts immediately while the entire OS, installed packages, and Docker state remain 100% preserved.

---

## Architecture Comparison: VM vs Container

| Feature | Container (`terminal-ubuntu`) | Virtual Machine (`vm-ubuntu`) |
| :--- | :--- | :--- |
| **Virtualization Layer** | Kubernetes Pod (OCI container) | KVM Hypervisor (Full VM) |
| **Guest Kernel** | Shared host Linux kernel | Independent dedicated Linux kernel |
| **Init System (PID 1)** | `/bin/bash` (no systemd) | `systemd` (services, timers, daemons work) |
| **Docker / Containers** | ❌ Blocked (no docker daemon) | ✅ **Full Docker & Podman engine support** |
| **Root Disk (`/`)** | Ephemeral overlayfs (wiped on exit) | **Persistent 200 GB ext4 block storage** |
| **Pause / Resume** | ❌ No pause (Stop terminates container) | ✅ **"Power off" suspends compute billing** |
| **Scientific Modules** | Pre-loaded Lmod + EasyBuild (4,000+ pkgs)| Vanilla Linux (install via apt/pip/cargo) |
| **Multi-Node Cluster** | Supported (multi-node Slurm) | Single VM instance only |
| **I/O Characteristics** | Network filesystem (WekaFS) | Local virtual block I/O (low latency) |

---

## System & Hardware Specifications

Observed production hardware profile on UCloud:

### 1. Compute & Kernel
* **Processor**: AMD EPYC-Genoa Processor (x86_64).
* **vCPUs**: 4 to 8+ dedicated virtual cores (single socket, 1 NUMA node).
* **RAM**: 21 GiB physical RAM allocated.
* **Operating System**: Ubuntu 26.04 LTS.
* **Kernel**: `Linux 7.0.0-30-generic #30-Ubuntu SMP PREEMPT_DYNAMIC`.

### 2. User & Sudo
* **Default User**: `ucloud` (UID `11042`, GID `11042`).
* **Sudoers**: Unrestricted passwordless sudo (`sudo -n true` succeeds).
* **Pre-installed System Binaries**: Python 3.14+, Git 2.53+, Tmux 3.6+.

---

## Storage Topology & Persistence

The VM utilizes a dual-tier storage model combining high-speed local virtual block storage with petabyte-scale shared storage:

```
/ (Root OS: /dev/vda1)                Native ext4 virtual block disk (200 GB) — PERSISTENT across Pauses
  ├── /home/ucloud                    User home directory — PERSISTENT across Pauses
  ├── /var/lib/docker                 Docker containers and images — PERSISTENT across Pauses
  └── /tmp                            RAM/Local scratch disk (tmpfs) — Ephemeral
/work/                                Virtiofs mount root
  └── /work/<MOUNTED_FOLDER>/         Permanent WekaFS project volume (virtiofs, 5.4 PB) — PERSISTENT PERMANENTLY
```

### Storage Persistence Rules:
1. **The Root Virtual Disk (`/dev/vda1`, 200 GB)**:
   * Retains all packages installed via `apt`, Python packages in `~/.local`, Docker images, system configurations, and files in `/home/ucloud`.
   * **Survives VM Power off (Pause)** and reboots.
   * **Destroyed only if the job is explicitly deleted** ("Stop and delete").
2. **The Attached Project Drive (`/work/<MOUNTED_FOLDER>`)**:
   * Mounted using **`virtiofs`**, providing direct memory-mapped host-to-guest file sharing.
   * **Permanent storage** that lives independently of the VM lifecycle.
   * **Golden Rule**: Always keep your Git repositories, large datasets, and secret `.env` files inside `/work/<MOUNTED_FOLDER>` so they are completely immune to VM recreation or deletion.

---

## Network & SSH Access

### Why VM SSH Differs from Container Apps
On container applications (`terminal-ubuntu`), UCloud injects a container SSH proxy daemon exposed as an "SSH access: Enabled/Disabled" toggle at submission. 

In `vm-ubuntu`, the guest is an independent KVM instance. External connectivity is managed as a modular resource through the **Access Panel**.

### Enabling External SSH on `vm-ubuntu`:
1. **Pre-requisite**: Ensure your public key is added under **Resources** $\rightarrow$ **SSH keys** (`https://cloud.sdu.dk/app/ssh-keys`) in the UCloud portal.
2. **Attach Key in Job View**:
   * Open your running VM's **Job Progress View** (`/app/jobs/properties/<job-id>`).
   * In the **Access Panel** on the right side, click the **`+`** icon next to **SSH access**.
   * Select your imported SSH key and confirm.
   * Click the orange **Restart** button in the Access Panel to apply the network injection to the VM.
3. **Retrieve Endpoint**: The panel displays the exact SSH command and assigned high port (e.g. `ssh ucloud@ssh.cloud.sdu.dk -p 2479`).

### Connecting via SSH

#### 1. Non-SIT / Personal / Unrestricted Network (Direct Connection)
```bash
ssh -o StrictHostKeyChecking=no -p <PORT> ucloud@ssh.cloud.sdu.dk
```

#### 2. Statens IT (SIT) Managed Network (SSI Equipment)
On the SSI / Statens IT network, outbound high ports (e.g., port 2479) are blocked by corporate firewalls. Connect via ProxyJump through the uGerm jump host:
```bash
ssh -o StrictHostKeyChecking=no -J <UGERM_USER>@login.ugerm.dksund.dk -p <PORT> ucloud@ssh.cloud.sdu.dk
```
*(Example: `ssh -J hutu@login.ugerm.dksund.dk -p 2479 ucloud@ssh.cloud.sdu.dk`)*

### In-Browser Fallbacks
If external SSH is unavailable, access the VM via the UCloud web interface:
* **Open terminal**: In-browser web tty directly into the VM.
* **Server console**: VNC/serial console. Requires setting a password first in the web terminal:
  ```bash
  sudo passwd ucloud
  ```

### Advanced Networking: Public IPs, Public Links & Private Networks

UCloud provides three networking resources that can be attached to `vm-ubuntu` (configured via **Resources** in the left navigation menu or the VM's **Access Panel**):

#### 1. Public IP (Static Ingress — Eliminates the Changing Port)
* **Mechanism**: Binds a dedicated, static public IP address to your VM with user-defined ingress ports (e.g. TCP 22 for SSH, 80/443 for web).
* **Solves the rotating port problem**: Instead of connecting to `ssh.cloud.sdu.dk -p <DYNAMIC_PORT>`, you connect directly to your static IP on standard port 22:
  ```bash
  ssh -o StrictHostKeyChecking=no ucloud@<YOUR_STATIC_PUBLIC_IP>
  ```
* **Setup**: Go to **Resources** $\rightarrow$ **IP addresses** $\rightarrow$ **Create public IP** (specify allowed ports: 22, 80, 443, etc.), then attach it to your VM in the **Access Panel** and restart.
* **Allocation Requirement**: Public IPv4 addresses are a metered product requiring an explicit project grant. If your project lacks a `public-ip` allocation, the portal returns *"Failed to activate public IP. You do not have any valid allocations for 'public-ip'"*.
* **Zero-Allocation Workaround (SSH Port Forwarding)**: Standard SSH gateway access (`ssh.cloud.sdu.dk -p <PORT>`) requires **no public IP allocation** and incurs zero extra cost. For web dashboards (e.g. Streamlit or FastAPI), forward the port locally through SSH:
  ```bash
  ssh -J <UGERM_USER>@login.ugerm.dksund.dk -p <PORT> -L 8000:localhost:8000 ucloud@ssh.cloud.sdu.dk
  ```
  Then open `http://localhost:8000` directly in your local workstation browser.
#### 2. Public Links (Automatic HTTPS for Agent Web UIs)
* **Mechanism**: Maps a secure SSL/TLS subdomain (`https://app-<name>.cloud.sdu.dk`) directly to any listening TCP port inside your VM (e.g. port 8000, 8080, 8501).
* **Agentic Use Cases**:
  * **Web Dashboards**: Accessing Streamlit, Gradio, OpenHands, Flowise, or Chainlit UIs directly from your browser.
  * **API & Webhooks**: Exposing LiteLLM proxies, FastAPI servers, or agent webhook endpoints with trusted HTTPS certificates.
* **Setup**: Go to **Resources** $\rightarrow$ **Public links** $\rightarrow$ **Create public link** (specify the port your service listens on, e.g. 8501).

#### 3. Connected Networks (Private Subnets for Multi-Job Architectures)
* **Mechanism**: Attaches the VM to an isolated internal virtual network (VPC/subnet) shared with other concurrent UCloud jobs.
* **Architectural Power Pattern (CPU Agent + GPU Server)**:
  * Run your agentic orchestrator on an inexpensive CPU VM (`vm-ubuntu`, 4–8 vCPUs).
  * Run heavy model serving on a separate GPU job (e.g. `triton` with vLLM on a B200 GPU or a persistent `postgresql`/`minio` job).
  * Connect both jobs to the same **Private Network**.
  * Your agent queries the GPU model server or database over fast, unmetered internal network traffic (`http://model-server:8000/v1`) without routing over the public internet.

---

## Agent & Developer Environment Setup

Because `vm-ubuntu` provides full root privileges, you can configure a persistent, production-grade developer and agent environment in minutes.

### 1. Automated One-Liner Bootstrap (`bootstrap_vm.sh`)
A complete, idempotent bootstrap script is provided in this repository at [`scripts/setup/bootstrap_vm.sh`](../scripts/setup/bootstrap_vm.sh) and placed directly on your persistent drive at `/work/TUHU/bootstrap_vm.sh`.

Whenever you or a colleague launch a fresh `vm-ubuntu` instance with your project drive attached, run this single command:

```bash
bash /work/TUHU/bootstrap_vm.sh
```
*(Or run `bash scripts/setup/bootstrap_vm.sh` from the repository root).*

#### What the Bootstrap Script Does (in <2 minutes):
1. **Discovers `/work/*`**: Dynamically detects your attached permanent storage folder.
2. **Installs System Stack**: `docker.io`, `docker-compose-v2`, `nodejs` (v22), `npm`, `gh` (GitHub CLI), `git`, `tmux`, `curl`, `jq`, `build-essential`.
3. **Configures Docker**: Adds `ucloud` to the `docker` group for rootless docker execution.
4. **Installs Python Runtimes**: Installs Astral `uv` for fast virtualenv creation.
5. **Installs Native Agent CLIs**: Installs `claude` (Claude Code), `omp` (Oh My Pi), and `pi` directly onto the local ext4 SSD for fast startup.
6. **Fixes Ghostty Terminfo**: Installs `xterm-ghostty` terminfo to eliminate `'xterm-ghostty': unknown terminal type` errors.
7. **Configures Starship & Shell Profiles**: Generates `~/.config/starship.toml` and configures `~/.bashrc` and `~/.zshrc` with:
   - High-speed local SSD paths (`~/.local/bin`, `/usr/local/bin`).
   - Persistent Git identity (`.gitconfig`, `.ssh`).
   - Persistent GitHub token (`XDG_CONFIG_HOME="/work/<FOLDER>/.config"`).
   - Symlinks for Claude Code and OMP logins (`.claude`, `.omp`) for zero-relogin sessions.
   - Modern colorful aliases (`eza`, `bat`, `fastfetch`).

### 2. Manual Customization & Sourcing
After running the bootstrap, activate the new environment immediately:
```bash
source ~/.bashrc
```
### 3. Outbound API Connectivity
Outbound HTTPS connections to external AI APIs are fully operational:
* **Anthropic Claude API**: `https://api.anthropic.com` ✅
* **OpenAI API**: `https://api.openai.com` ✅
* **HuggingFace**: `https://huggingface.co` ✅

Store API tokens in your persistent drive (e.g., `/work/<FOLDER>/.env`) and source them inside your `tmux` agent sessions.

---

## Lifecycle & Credit Management

> ⚠️ **CRITICAL COST INVARIANT**:  
> Running virtual machines continuously consume project compute allocations (e.g., an 8 vCPU VM consumes **8 Core-hours per clock hour**).

### Pausing vs Deleting

```
                ┌──────────────────────────────────────────────┐
                │          UCloud VM Lifecycle Options         │
                └──────────────────────┬───────────────────────┘
                                       │
                ┌──────────────────────┴───────────────────────┐
                ▼                                              ▼
        [ Power Off (Pause) ]                         [ Stop and Delete ]
  ─────────────────────────────────            ───────────────────────────────────
  • Compute core-hour billing STOPS            • Compute core-hour billing STOPS
  • Root disk (200 GB) KEPT INTACT             • Root disk (200 GB) DESTROYED
  • Docker images & packages PRESERVED         • All uncommitted OS files LOST
  • Small hourly storage quota applies         • Storage quota released
  • Resume in seconds anytime                  • Cannot be undone
```

### Best Practices:
1. **When stepping away or finishing a work session**:
   * Click **Power off** in the top-right progress view.
   * Compute billing stops immediately.
   * You can resume days later without re-installing tools.
2. **Primary Disk Sizing**:
   * Do not allocate unnecessary disk space during job creation (e.g., avoid 1–2 TB virtual disks unless strictly required). A 50–200 GB primary disk is optimal for OS + Docker layers. Keep datasets on the attached `/work/` drive.
3. **Dynamic Port on Resume**:
   * When resuming a paused VM, UCloud dynamically reassigns the internal IP and external SSH port. Check the Job Progress View after resume to retrieve the new port number.

4. **Resource Immutability (vCPU, RAM, and Disk are Fixed)**:
   * Once created, a VM's **vCPU count, RAM, and primary disk size cannot be modified**, even when the VM is powered off (paused).
   * Powering off halts compute core-hour consumption, but the underlying hypervisor hardware reservation and virtual block device are locked to that job ID.
   * **How to scale resources**: To upgrade (e.g. from 8 vCPUs to 32 vCPUs, or to resize disk), you must launch a new VM instance.
   * **Seamless migration**: Because all repositories, datasets, and configurations are kept on the persistent drive (`/work/<MOUNTED_FOLDER>`), a new VM immediately accesses all your work as soon as the drive is attached.
---

## Common Pitfalls & Solutions

### 1. SSH Connection Times Out from Workstation
* **Cause**: Statens IT (SIT) / SSI network blocks outbound connections to high ports (e.g., 2479).
* **Fix**: Use ProxyJump via uGerm:
  ```bash
  ssh -J <UGERM_USER>@login.ugerm.dksund.dk -p <PORT> ucloud@ssh.cloud.sdu.dk
  ```

### 2. Missing Scientific Modules (`module: command not found`)
* **Cause**: `vm-ubuntu` is vanilla Ubuntu; it does not automatically mount the Lmod/EasyBuild cluster directory (`/opt/easybuild/`).
* **Fix**: If your agent workflow requires specific bioinformatics binaries (e.g., Samtools, Bedtools, FastQC), install them directly via `sudo apt install` or `uv`/`conda`, or use container jobs (`terminal-ubuntu`) for native module access.

### 3. Accidental Loss of Files after Deleting Job
* **Cause**: Files saved in `/home/ucloud` or `/tmp` exist only on the virtual block disk; clicking "Stop and delete" destroys the disk.
* **Fix**: Always keep source repositories, datasets, and scripts in `/work/<MOUNTED_FOLDER>/`.

### 4. `'xterm-ghostty': unknown terminal type`
* **Cause**: Modern Mac terminals like **Ghostty** export `TERM=xterm-ghostty`. Ubuntu does not include Ghostty's terminfo definitions in its default package base, breaking commands like `clear`, `nano`, and `tmux`.
* **Fix**: Compile and install the terminfo entry on the VM directly from your Mac:
  ```bash
  infocmp -x xterm-ghostty | ssh -J <UGERM_USER>@login.ugerm.dksund.dk -p <PORT> ucloud@ssh.cloud.sdu.dk 'tic -x -'
  ```
  Or set a fallback in `~/.bashrc`:
  ```bash
  [ "$TERM" = "xterm-ghostty" ] && export TERM=xterm-256color
  ```

---

---

## Remote Desktop Access (GUI)

`vm-ubuntu` runs with systemd's `graphical.target` enabled by default. You can easily install a full graphical desktop and connect using standard **Remote Desktop Protocol (RDP)** or **VNC**.

### Recommended: XRDP + XFCE4 (Fast, Lightweight Desktop)

#### Step 1: Install XFCE and XRDP inside the VM
Run these commands inside your VM terminal:
```bash
# Install lightweight XFCE desktop and XRDP server
sudo apt update && sudo apt install -y xfce4 xfce4-goodies xrdp dbus-x11

# Set XFCE as the default desktop session for ucloud
echo "xfce4-session" > ~/.xsession

# Set a password for the ucloud account (required for RDP login)
sudo passwd ucloud

# Enable and restart xrdp
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp
```

#### Step 2: Forward RDP Port (3389) via SSH Tunnel
On your local laptop terminal, open an SSH tunnel mapping port 3389:
```bash
ssh -J <UGERM_USER>@login.ugerm.dksund.dk -p <PORT> -L 3389:localhost:3389 ucloud@ssh.cloud.sdu.dk
```
*(Example: `ssh -J hutu@login.ugerm.dksund.dk -p 2523 -L 3389:localhost:3389 ucloud@ssh.cloud.sdu.dk`)*

#### Step 3: Connect via Microsoft Remote Desktop
1. Open **Microsoft Remote Desktop** (or any RDP client) on your Mac or PC.
2. Add a new PC with PC name: **`localhost:3389`** (or `127.0.0.1:3389`).
3. Connect and enter username **`ucloud`** and the password you set in Step 1.
4. You now have a full, high-resolution graphical Linux desktop with clipboard integration.

### In-Browser Alternative: UCloud Server Console
In the UCloud **Job Progress View**, the **Server console** dropdown connects to the VM's native virtual display. Once `sudo passwd ucloud` is set, you can log in directly in your web browser without installing any local client software.

## Quick Reference Cheatsheet

```bash
# === Hardware & OS Verification ===
uname -a                           # Linux kernel version
systemd-detect-virt                # Displays 'kvm'
nproc                              # Virtual core count (e.g. 8)
free -h                            # Memory allocation (e.g. 21 GiB)
df -hT / /work/*                   # Root block disk vs virtiofs drive mounts

# === Docker Engine Verification ===
sudo systemctl status docker       # Check docker daemon status
docker run --rm hello-world        # Test container isolation

# === Persistent Environment Loading ===
source /work/TUHU/env.sh           # Load node, omp, claude, git config

# === Unattended Agent Execution ===
tmux new -s agent-run              # Start multiplexer
# ... run agent workflow ...
# Press Ctrl+B then D to detach safely
```
