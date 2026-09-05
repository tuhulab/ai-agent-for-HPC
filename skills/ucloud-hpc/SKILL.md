---
name: ucloud-hpc
description: Work efficiently on UCloud HPC (Kubernetes+WekaFS+EasyBuild) and automate the full job lifecycle through the web portal — authenticate, pick a workspace, configure an app (machine type, folder, SSH, init script), submit, monitor, connect, and rerun. Covers filesystem, modules/Lmod, Slurm emulation, MPI, resource detection, persistence, multi-node SSH, and common pitfalls. Use for any task on this HPC/container environment.
---

# UCloud HPC Skill

This UCloud instance is **not a bare-metal HPC**. Jobs are **Kubernetes containers** with WekaFS shared storage, EasyBuild/Lmod modules, and emulated Slurm. Many traditional HPC assumptions break here.

The skill has two halves:

- **Part A (§1–§7): launching jobs through the web portal** — the automation path. Use when no job is running yet and one must be started, or when a job must be monitored, stopped, or rerun.
- **Part B (§8–§19): working inside a running job** — the in-container environment once the job is up.

Official docs: `https://docs.cloud.sdu.dk` (guide/submitting.html, guide/monitoring.html, guide/resources-products.html, Apps/batch_apps.html).

---

# Part A — Launching & Managing Jobs in the Web Portal

## 1. Web Portal Basics

### 1.1 URLs (stable, SPA routes)

| Page | URL |
|---|---|
| Login | `https://cloud.sdu.dk/app/login` |
| Dashboard | `https://cloud.sdu.dk/app` |
| Files | `https://cloud.sdu.dk/app/drives` |
| Project (allocations) | `https://cloud.sdu.dk/app/allocations` |
| Resources / public links, IPs, SSH keys | `https://cloud.sdu.dk/app/public-links` |
| Applications catalog | `https://cloud.sdu.dk/app/applications` |
| Jobs list (Compute) | `https://cloud.sdu.dk/app/jobs` |
| Create job for app | `https://cloud.sdu.dk/app/jobs/create?app=<app-id>` |
| Job properties/progress | `https://cloud.sdu.dk/app/jobs/properties/<job-id>` |
| Product costs | `https://cloud.sdu.dk/app/skus` |

Left nav icons: Files, Project, Resources, Applications, Compute. Bottom of the rail: theme toggle, task monitor, notifications, support, **user avatar** (account settings, logout).

### 1.2 Authentication

- The SAML path (`Login` button → WAYF via `auth.cloud.sdu.dk`) is a ForgeRock flow that is slow and flaky under automation (consent stage "Continue to WAYF" renders late; the page can sit on a spinner). Prefer the **direct login form**: on `/app/login` click **"Other login options →"**, which reveals Username + Password textboxes (AX names: "Username", "Password") and a Login button.
- After submit, a **"6-digit code"** TOTP field appears when 2FA is enabled. The code rotates every 30 s — type and submit immediately.
- Prove login succeeded: page title becomes `UCloud | Dashboard` and the URL is `/app` (not `/app/login`).
- The session lives in the browser; it persists across page navigations. If `/app/*` redirects back to `/app/login`, the session expired — re-authenticate.

### 1.3 Workspace / project selector — ⚠️ the top-right dropdown

The **top-right dropdown** (shows the current workspace, e.g. `My workspace`) is the **workspace/project switcher** — NOT settings and NOT an app menu. Clicking it opens a searchable project list (starred first; `My workspace` is always starred; hidden projects can be toggled). Selecting a project changes the context for EVERYTHING: file browser (Places/drives), cost balance, allocations, folder picker, and job list.

- Before launching, monitoring, or touching files, **read the value of the top-right dropdown and confirm it is the intended project.** An agent clicking around can silently submit a job billed to the wrong project or attach the wrong drive.
- Never confuse it with the **user avatar at the bottom of the left rail** (account settings / logout) or the theme toggle.
- Equivalent effect is available via the command palette (`Cmd+P` / `Ctrl+P`) from any page.

## 2. Launch a Job (create form)

Entry points — either path lands on `/app/jobs/create?app=<id>`:

1. Applications page → click an app card.
2. Direct URL: `https://cloud.sdu.dk/app/jobs/create?app=<app-id>` (fastest for automation; the form validates the app id on load).

Known app ids in the catalog: `terminal-ubuntu` (Terminal/web ttyd), `ubuntu-xfce`, `coder`, `coder-python`, `jupyter-all-spark`, `rstudio`, `shiny`, `nextflow`, `spark-cluster`, `rsync-server`, `minio`, `vm-ubuntu`, `isaac-lab`, `isaac-sim`, `ragflow`, `aistor`, `transcriber-gui`, `cuda-quantum`, `cuquantum`, `redis`, `license-test`, `test-app`. The catalog on `/app/applications` is the authoritative list — scrape the card `href`s with `grep -o 'app=[a-z0-9-]*'` semantics (i.e., read the `href` attributes) rather than guessing.

Form structure (AX snapshot roles observed on UCloud 2026.5.0):

| Control | AX role / name | Notes |
|---|---|---|
| Flavor | button "Default" | some apps have flavors (e.g. Ubuntu vs Debian) |
| Version | button "Aug2026" etc. | latest default; verify it's the wanted image |
| Job name | textbox "Job name" | default is app name; set something unique |
| Hours | textbox "Hours*" + buttons +1 / +8 / +24 | time limit; can be extended while running |
| Number of nodes | (only multi-node apps: `terminal-ubuntu`, `spark-cluster`) | node count for the job |
| Service provider | button "DeiC Interactive HPC (SDU/K8s)" | REQUIRED; may offer others (SDU-Odense) |
| Machine type | button "No machine type selected" | opens selector dialog → see §3 |
| Folder #1… | readonly textbox "Folder #1" | opens Places browser → see §2.2 |
| SSH access | combobox (Enabled/Disabled) | enable to get an `ssh` command in the progress view |
| Private network #1 / Public IP #1 | readonly textbox | advanced connectivity |
| Job report sample rate | combobox, default 250 ms | writes `/work/job-report.csv` |
| Modules path | readonly textbox | auto-load an Lmod modules folder at startup |
| Initialization | readonly textbox | **startup shell script** — see §2.3 |
| Extra options | textbox | extra args passed to the initialization script |
| E-mail notification settings | combobox, default "Do not notify me" | |
| Submit | button "Submit ⌘⌥ Enter" | submit the job |

### 2.1 Machine type dialog

Click "No machine type selected". A modal table opens with row: Type | Machine type | Description | Status (e.g. `CPU | cpu-amd-zen5 | General purpose CPU machines.`). Click the row — the dialog closes and the field shows the selection (e.g. `cpu-amd-zen5`). Then:

- Right side shows queue status text: **"This machine type is available."** (green), a busy warning (yellow), or unavailable/queued (red). A red status means the job will wait.
- **Est. cost** (Core-hours) and **Balance** appear after selection; an insufficient balance shows a warning + "Apply for resources" button. Never submit past a balance warning without confirming.

### 2.2 Attaching folders

Click "Folder #1" → Places browser opens:

- Left: sidebar with `Favorites`, `My workspace`, and project drives (e.g. `BINF INFIMM`, `CSCC`, `image_analysis`, …).
- Right: the selected drive's contents (`Jobs`, `Syncthing`, …) with a **Use** button per row; header buttons **"Use this folder" (⌥G)**, **"Create folder" (⌥F)**, **"Upload files" (⌥U)**.
- Click a folder row (or navigate into it) then "Use this folder". Attached folders mount under `/work/` inside the job. Multiple folders = Folder #1, #2, …
- **Only attached folders (your default working tree under `/work`) persist after the job ends.** Anything else in the container is lost.

### 2.3 Initialization script (auto-setup on boot) — key automation lever

"Initialization" attaches a `.sh` script that runs at job startup. Use it to bootstrap the container deterministically every launch:

```bash
#!/bin/bash
set -e
source /work/<COLLECTION>/env.sh 2>/dev/null || true   # persistent env (see §9)
export PATH="/work/<COLLECTION>/nodejs/current/bin:$PATH"
# load modules, install what's missing, start services…
```

"Extra options" passes CLI args to that script. Pair with a persistent `initiation.sh` in your collection (see §9) for idempotent setup.

## 3. Machine Types & Products (DeiC Interactive HPC SDU/K8s)

From `https://docs.cloud.sdu.dk/guide/resources-products.html` + live dialog:

| Machine type | Node hardware | Use for |
|---|---|---|
| `cpu-amd-zen5` | 2× AMD EPYC 9635, 128 vCPU, 768 GB DDR5 | CPU work (default) |
| `gpu-nvidia-b200` | 2× EPYC 9655, 384 vCPU, 2304 GB, 8× NVIDIA B200 192 GB | GPU work |
| `gpu-nvidia-b200-*-mig` | 1/7 of a B200 per MIG, request 1–4 MIGs | small GPU slices |

SDU-Odense provider (SDU-affiliated): `cpu-amd-zen4`, `gpu-nvidia-h100`.

- Storage is a separate product (`storage`, WekaFS); data is never deleted on expiry, but new jobs/uploads stop.
- The dialog may expose only the node-class rows; per-job slice sizing is decided backend-side. Your true allocation is in `/work/JobParameters.json` **inside the job** (cpu/memoryInGigs/vnodes) — never assume 1 vCPU/3 GiB (see §8).

## 4. Deterministic Launches — Import / JobParameters.json

Reproducing a known-good job: click **Import** on the create page → dialog with:

- **"Upload JobParameters.json" (⌥U)** — import a saved parameters file,
- **"Select file from UCloud" (⌥S)** — pick one from your drives,
- a job list to import from a previous run (filtered by current workspace/app/version — "No jobs found with active filters" just means nothing matches, not that no job ever ran).

`JobParameters.json` shape (siteVersion 3):

```json
{
  "siteVersion": 3,
  "request": {
    "application": { "name": "fastqc", "version": "0.12.1" },
    "product": { "id": "u1-standard-2", "category": "u1-standard-h", "provider": "ucloud" },
    "name": "test",
    "replicas": 1,
    "parameters": {
      "inputdir_var": { "type": "file", "path": "/45931/FastQC-input-dir", "readOnly": false },
      "extract_flag": { "type": "boolean", "value": true }
    },
    "timeAllocation": { "hours": 1, "minutes": 0, "seconds": 0 },
    "allowDuplicateJob": true,
    "sshEnabled": false
  },
  "machineType": { "cpu": 2, "memoryInGigs": 12 }
}
```

Every job also writes its own `JobParameters.json` into its output folder — grab it from a good run and reuse it (see §5.3).

## 5. Monitor Jobs

### 5.1 Jobs list (`/app/jobs`)

Columns: Created by | Created at | Time left | State (e.g. `Completed`, `Running`, `Scheduled`/queued, `Suspended`) | Job name. Search box filters; rows are clickable divs (not plain `<a>`).

Selecting a row reveals the action bar: **Run again (⌥B)** · **Rename (⌥R)** · **Stop** · **Done** · **Properties (⌥E)**.

### 5.2 Progress / properties view

`/app/jobs/properties/<job-id>` (via Properties ⌥E or clicking the job name) shows the **event timeline**:

```
[09:11] Job has been scheduled and is starting soon (Assigned to nodeaa-42)
[09:11] TuHu#2222 has requested 1x terminal from DeiC Interactive HPC (SDU/K8s)
[09:11] Job is currently in the queue
[09:11] Job is now running
[09:27] Your machine is currently powered off.
```

- **Scheduled/queued**: "Cancel reservation" button removes it before start.
- **Running**: time allocation can be extended; "Stop application" terminates early; "Open terminal" opens an in-browser terminal; SSH command and public links appear in SSH/Links tabs when enabled; live CPU/memory/network (+GPU) widgets top-right.
- **Completed**: output folder + results listed; "Run application again" reruns with identical params. Jobs can be **Suspended** when idle (machine powered off) — resume by starting it again.

### 5.3 Job output folder

`Jobs/<job-id>` under your drive (also listed on the completed progress view). Contains:

- `stdout.txt` — the program's stdout (first stop when debugging a failed run),
- `JobParameters.json` — exact submission params (reuse via Import),
- `job-report.csv` — resource sampling (only if sample rate set),
- `job-0.sh` etc. — backend start command.

## 6. Post-Launch Automation Recipe (agent step list)

1. **Confirm session**: load `/app`; if it redirects to `/app/login`, do §1.2 (direct login form + TOTP).
2. **Verify workspace**: read the top-right dropdown; switch if wrong (§1.3).
3. **Open the create form** by URL: `/app/jobs/create?app=<app-id>` — read form via AX snapshot; note required fields (marked `*`).
4. **Configure**: set Job name; Hours (+1/+8/+24 or type); Machine type via dialog (§2.1); attach folders via Places (§2.2); set SSH enabled if you'll need `ssh`/`scp`; attach Initialization script if the job must self-bootstrap (§2.3); set sample rate / notifications as needed.
5. **Submit** (⌘⌥ Enter or the Submit button). You land on the job's progress view.
6. **Reach Running**: poll `/app/jobs` (or the progress view text) until State = Running / timeline shows "Job is now running". Queued time varies with machine availability.
7. **Prove readiness before delegating work in**: check the progress view for the SSH command (SSH tab) or use "Open terminal"; inside the job run §8 probes.
8. **Teardown**: Stop the job when done (or let the lifetime elapse); check outputs in `Jobs/<id>` — copy anything you need from the output folder/`stdout.txt` before the job ages out.

Offer, don't assume: submitting a job **consumes credits** and starts compute — confirm the target project/machine size/hours at the point of submission.

## 7. Hotkeys & Navigation Reference (observed)

| Keys | Action |
|---|---|
| ⌘⌥ Enter | Submit job |
| ⌘⌥ T | New terminal (global) |
| Cmd/Ctrl+P | Command palette (any page) |
| ⌥G / ⌥F / ⌥U | Use this folder / Create folder / Upload files (Places) |
| ⌥U / ⌥S | Upload JobParameters.json / Select file from UCloud (Import) |
| ⌥B / ⌥R / ⌥E | Run again / Rename / Properties (jobs row) |
| ⌘⌥ J / S / C / P | Jump to job info / storage / connectivity / parameters |
| ⌘⌥ 1 / 2 | Focus sidebar / files in Places |

---

# Part B — Working Inside a Running Job

## 8. System Snapshot (detect first)

Always probe before heavy work:

```bash
cat /work/JobParameters.json          # allocated resources (truth)
cat /work/.script-params.yaml         # template params
cat /etc/ucloud/nodes.txt             # head node hostname
cat /etc/ucloud/number_of_nodes.txt   # node count
cat /tmp/hostfile 2>/dev/null || echo "single-node"
lscpu | head -20; free -h; df -h /work  # lscpu/free show HOST (e.g. 256 cores / 754 GiB), not your allocation
jq . /work/JobParameters.json  # YOUR allocation: cpu/memory/gpu/nodes/time vary per job — never hardcode 1 vCPU / 3 GiB
env | grep -E "UCLOUD|PI_|MODULEPATH"
```

Key env (discover, don't hardcode):
- `UCLOUD_JOB_ID`, `UCLOUD_RANK`, `UCLOUD_TASK_COUNT`
- `UCLOUD_BASE_URL` (web UI)
- `COLLECTION_ROOT` — your persistent collection dir, e.g. `/work/my-collection` (resolve via `ls /work` or `mount | grep wekafs` or `printenv | grep -i collection`)
- `PI_CODING_AGENT_DIR` — e.g. `$COLLECTION_ROOT/.pi/agent` or `/work/<COLLECTION>/.pi/agent` (not `~/.pi`)
- `MODULEPATH=/opt/easybuild/ubuntu-24.04/amd/modules/all` (or `intel`)

## 9. Filesystem — What Persists?

```
 /work                WekaFS 5.4P shared volume — PERSISTENT across jobs
   /work/<COLLECTION>  Your persistent collection dir (name varies! e.g. `/work/my-collection`)
                      Discover via `ls /work` or `mount | grep wekafs` or `printenv | grep -i collection`
     env.sh           Persistent PATH / npm prefix / pi config  → $COLLECTION_ROOT/env.sh  (or /work/<COLLECTION>/env.sh)
     nodejs/current   Node v22.23.2 (copied from image, do not use /usr/bin/node)
     bin/pi, bin/claude
     .pi/agent        Real pi config (settings, sessions, auth) → $COLLECTION_ROOT/.pi/agent  (or /work/<COLLECTION>/.pi/agent)
   /work/initiation.sh -> $COLLECTION_ROOT/initiation.sh (runs each job; path is /work/<COLLECTION>/initiation.sh)
 /home/ucloud         Container overlay — EPHEMERAL (lost on job end)
 /opt/easybuild/ubuntu-24.04  WekaFS RO mount — modules + software (790604)
 /tmp                 Local XFS scratch — fast but ephemeral, on /dev/mapper/vg0-lv_scratch
 /etc/ucloud          K8s emptyDir — node list, rank, token
 overlay /            Container root — overlayfs, 1.5T, ephemeral
```

> ⚠️ Collection name varies per user (e.g. `/work/my-collection`, `/work/ProjectA`). **Never hardcode** it. Always resolve via `ls /work` or `mount | grep wekafs` — your persistent dir is the wekafs mount at `/work/<COLLECTION>`.

**Rules:**
- Write results to `/work` not `/home` or `/tmp` if you need them after the job.
- Do not write large data to overlay `/` (counts against 1.5T, slow GC).
- `/work/<COLLECTION>` is bind-mounted (e.g. `/work/my-collection` → same files); find yours via `ls /work` or `mount | grep wekafs`.
- Global `npm install -g` goes to `$COLLECTION_ROOT` via `npm_config_prefix=$COLLECTION_ROOT` (see `$COLLECTION_ROOT/env.sh` or `/work/<COLLECTION>/env.sh`). Never `sudo npm`.
- Keep `.bashrc`/`.zshrc` persistent hook: `source $COLLECTION_ROOT/env.sh` (or `source /work/<COLLECTION>/env.sh`) is auto-added; do not remove — it restores PATH/pi/node.

## 10. Modules (Lmod + EasyBuild)

```bash
source /opt/lmod/lmod/init/bash   # required in non-interactive scripts
module use $MODULEPATH            # already in .bashrc if MODULEPATH set
module avail 2>&1 | head -n 100
module list
module load Python/3.12.3-GCCcore-13.3.0  # example
module load GCC/13.3.0 OpenMPI/5.0.6
```

- Vendor path matters: `/opt/easybuild/ubuntu-24.04/amd/modules/all` vs `intel/...`. Chosen at boot from `lscpu Vendor ID` (this host: AMD EPYC 9535 → `amd`). Do not hardcode.
- Default path fallback is `/opt/easybuild/modules/all` — ignore it here.
- EasyBuild software not under `/opt/easybuild/software` but under `/opt/easybuild/ubuntu-24.04/amd/software/...`.
- `module avail` is slow (~4000 modules: GCC, CUDA 12.1–13.3, AOCL, BLIS, FFTW, HDF5, SciPy-bundle, PyTorch, etc.).
- Always load in dependency order: `GCCcore → GCC → OpenMPI → foss → toolchain bundles`.

## 11. Compilers, MPI, CUDA

- System GCC 13.3.0 at `/bin/gcc` — works without modules.
- OpenMPI 5.0.10 at `/usr/local` (configured `--with-slurm --with-pmix=/usr/include/pmix/install/5.0 --with-libevent=external`).
  ```bash
  which mpirun; mpirun --version; ompi_info | head
  mpirun -np 2 --host node0:2 ./a.out   # or --hostfile /tmp/hostfile
  ```
- PMIx: `pkg-config --modversion pmix` → 5.0.x (Slurm uses `MpiDefault=pmix_v$PMIX_VER`).
- CUDA modules 12.1–13.3 available but **no GPU in current allocation** (`nvidia-smi` not found, `/dev/nvidia*` absent). Load `CUDA/12.8.0` only if `gpu-*` product selected.
- NCCL, UCX, UCX-CUDA, GDRCopy modules exist for GPU jobs.

## 12. Scheduler — Slurm is Emulated, Not Systemd

- `sbatch`/`srun`/`sinfo` exist at `/usr/local/bin` but **/etc/slurm/slurm.conf is empty until generated** by `/usr/bin/gen_slurm_conf` (templated from `JobParameters.json`).
- Generation happens in `.script-generated-0.sh` via `sed` replacing `UCORES/UMEMORY/UGPUS/UGPU_TYPE/URANK` and appending `NodeName=` lines from `/tmp/hostfile`.
- Control host = `$(hostname)` (e.g., `j-12374472-job-0...svc.cluster.local`).
- No systemd: `systemctl status slurmd` fails. Slurm daemons are not auto-started unless `ucloud.slurm=true`. Check `/tmp/tm1.sh`/`tm2.sh` if debugging.
- For single-node most jobs just run directly; use `srun` only after confirming `sinfo` works.

```bash
cat /tmp/tm1.sh 2>/dev/null | head   # inspect generated conf
cat /etc/slurm/slurm.conf 2>/dev/null | head -n 60
sinfo 2>&1 | head; squeue 2>&1 | head
```

## 13. Multi-Node

- `/etc/ucloud/nodes.txt` + `/etc/ucloud/node-0.txt` … contain hostnames.
- `/etc/hosts` adds `node0` aliases; `node0` resolves via `getent hosts node0`.
- `/tmp/hostfile` holds one hostname per line (here just `node0`).
- Orchestration: rank 0 runs `update_hosts <N>`, `service ssh start`, `init_user.sh <N>` (populates `/root/.ssh/known_hosts` from `ssh_host_ed25519_key.pub`), then `wait-for node0:22,...`.
- SSH works passwordless to `node<i>` after init. Use `ssh node1 hostname` to test.

## 14. Runtime Environment

- OS: Ubuntu 24.04 Noble, kernel 6.12.0-211 EL10, x86_64, cgroup2.
- CPU: host has `AMD EPYC 9535 64-Core ×2` (256 threads, 2 NUMA nodes) — but your job's vCPUs vary (request determines it). Respect cgroups; don't spawn 256 threads naïvely — use `nproc` or `JobParameters.json` cpu count, pin with `OMP_NUM_THREADS`.
- Memory: host 754 GiB visible via `free -h`, but your job's memory varies per request (e.g. this job was 3 GiB, others may be 16/64/192 GiB). Always check `JobParameters.json` / `JobParameters.json` `memoryInGigs` for true limit — `free` lies.
- `ulimit -n 1048576`, `stack 8192k`, `sudo NOPASSWD:ALL`.
- Locale: `LC_ALL=C.UTF-8` (not `en_US`). Some tools expect UTF-8 — keep it.
- `starship` prompt + `fastfetch` + `tmux -u` preconfigured; `BASH_ENV=/opt/lmod/lmod/init/bash` auto-loads Lmod.
- Web terminal: `ttyd` on port 7681 (`altClickMovesCursor`, `enableSixel`, `fontSize 20`).
- UCloud metrics: `/opt/ucloud/ucmetrics viz` runs in background (do not kill).

## 15. Python / Node / Containers

```bash
python3 --version          # 3.12.3 system; for newer load module: module load Python/3.13.1
pip list | head; pip install --user ...   # --user lands in ~/.local (ephemeral) → prefer venv in /work
/node --version => v22.23.2 at $COLLECTION_ROOT/nodejs/current/bin/node  (e.g. /work/<COLLECTION>/nodejs/current/bin/node)
npm --version => 10.9.8, prefix=$COLLECTION_ROOT  (or /work/<COLLECTION>)
which singularity apptainer docker  # none — WekaFS container, no user containers
```

- Create venvs in `/work`: `python3 -m venv /work/venv && source /work/venv/bin/activate`.
- For reproducible Python use `module load Python-bundle-PyPI` or EasyBuild `SciPy-bundle`.

## 16. Efficient Agent Workflow

1. **Read JobParameters first** — never assume cores/mem.
2. **Check module path** — `echo $MODULEPATH` then `module avail <pattern>` before loading.
3. **Use /tmp for compiles**, `/work` for outputs. WekaFS has `writecache` but high latency — small-file I/O to `/tmp` is faster, then `rsync` to `/work`.
4. **Batch bash calls** — one `bash` tool call per logical group; avoid N× `module list`.
5. **Persist env** — append exports to `$COLLECTION_ROOT/env.sh` (e.g. `/work/<COLLECTION>/env.sh`) not `.bashrc` directly; source it.
6. **Multi-node**: test `srun -N <N> hostname` or `mpirun --hostfile /tmp/hostfile` after SSH ready.
7. **No internet assumptions** — internet works (google/ping ok) but cache downloads to `/work`.

## 17. Common Pitfalls

Portal / launch side:
- **Top-right dropdown is the workspace switcher** (see §1.3) — never treat it as settings/account; verify the active project before submitting or picking folders, or you bill the wrong project.
- **SAML/WAYF flow hangs** under automation (spinner on the ForgeRock consent page) — prefer the direct login form off "Other login options →"; don't fight the IdP redirect loops.
- **TOTP expires fast** (30 s) — fetch/submit promptly; a stale code yields "invalid code" and you must re-enter.
- **Submit consumed credits silently** — check Est. cost vs Balance and the machine availability color before hitting Submit.
- **Import dialog shows "No jobs found with active filters"** even when old jobs exist — filters scope to current workspace/app/version; broaden or upload a JobParameters.json instead.
- **Reading a job row's Actions on the wrong row** — row selection persists; confirm the job id (top of Properties page) matches the intended run before Stop/Run again.

In-job side:
- **Empty slurm.conf** → run `bash /tmp/tm1.sh`? No — `gen_slurm_conf` needs sed replacement; inspect `/tmp/tm1.sh` instead.
- **MODULEPATH overwritten** — `/opt/easybuild/ubuntu-24.04/amd/modules/all` is set in `~/.bashrc`; `module use /opt/easybuild/modules/all` silently masks vendor modules.
- **Writing to /home** → lost on reschedule. Use `/work`.
- **Assuming GPU** → `nvidia-smi` fails; check `JobParameters.json` `gpu` field before `module load CUDA`.
- **256-thread spawn** → OOM-killer (host has 256 threads but job may have 1–64 vCPUs). Pin with `OMP_NUM_THREADS=$(nproc)` or `$(jq .resources[0].memoryInGigs)` / `cpu` from `JobParameters.json`.
- **Systemd** → `systemctl` always fails (`PID 1` is bash). Use direct daemon calls.
- **Locale build failures** → some autotools check for `en_US.UTF-8`; export `LC_ALL=C.UTF-8` is fine, but install `language-pack-en` if needed.

## 18. Quick Reference Commands

```bash
# resources
jq . /work/JobParameters.json
qstat() { cat /work/stdout-*.log 2>/dev/null | tail -50; }

# modules
source /opt/lmod/lmod/init/bash; module avail Python 2>&1 | grep -i python

# mpi smoke test
cat >/tmp/hello.c <<'EOF'
#include <mpi.h>
#include <stdio.h>
int main(int argc,char**argv){MPI_Init(&argc,&argv);int r,s;MPI_Comm_rank(MPI_COMM_WORLD,&r);MPI_Comm_size(MPI_COMM_WORLD,&s);printf("rank %d/%d on %s\n",r,s,"host");MPI_Finalize();return 0;}
EOF
mpicc /tmp/hello.c -o /tmp/hello && mpirun -np 2 /tmp/hello

# slurm gen (if missing) — use YOUR allocation, not hardcoded 1/3:
CORES=$(jq -r '.resources[0].cpu // .machineType.cpu // 1' /work/JobParameters.json 2>/dev/null || echo 1); MEM=$(jq -r '.resources[0].memoryInGigs // .machineType.memoryInGigs // 3' /work/JobParameters.json 2>/dev/null || echo 3); sed "s/UCORES/$CORES/;s/UMEMORY/$MEM/;s/UGPUS/0/;s/UGPU_TYPE/cpu-amd-zen5/" /usr/bin/gen_slurm_conf | head -n 80

# persistent install
npm install -g cowsay        # lands in $COLLECTION_ROOT/bin (e.g. /work/<COLLECTION>/bin) via npm_config_prefix
pip install --target /work/pydeps package
```

## 19. When to Ignore This Skill

Plain Ubuntu container work (e.g., editing `$COLLECTION_ROOT/*.sh` or `/work/<COLLECTION>/*.sh`, using `pi`/`claude` CLI) doesn't need HPC steps, and pure portal browsing (files, dashboards) doesn't need the in-job sections. Invoke HPC logic for compiles, MPI, batch jobs, module loads, multi-node work, and invoke §2–§7 whenever a job must be started, monitored, stopped, or rerun from the web portal.