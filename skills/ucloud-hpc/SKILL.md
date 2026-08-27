---
name: ucloud-hpc
description: Work efficiently on UCloud HPC (Kubernetes+WekaFS+EasyBuild). Covers filesystem, modules/Lmod, Slurm emulation, MPI, resource detection, persistence, multi-node SSH, and common pitfalls. Use for any task on this HPC/container environment.
---

# UCloud HPC Skill

This UCloud instance is **not a bare-metal HPC**. It is a **Kubernetes container** with WekaFS shared storage, EasyBuild/Lmod modules, and emulated Slurm. Many traditional HPC assumptions break here.

## 1. System Snapshot (detect first)

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

## 2. Filesystem — What Persists?

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

## 3. Modules (Lmod + EasyBuild)

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

## 4. Compilers, MPI, CUDA

- System GCC 13.3.0 at `/bin/gcc` — works without modules.
- OpenMPI 5.0.10 at `/usr/local` (configured `--with-slurm --with-pmix=/usr/include/pmix/install/5.0 --with-libevent=external`).
  ```bash
  which mpirun; mpirun --version; ompi_info | head
  mpirun -np 2 --host node0:2 ./a.out   # or --hostfile /tmp/hostfile
  ```
- PMIx: `pkg-config --modversion pmix` → 5.0.x (Slurm uses `MpiDefault=pmix_v$PMIX_VER`).
- CUDA modules 12.1–13.3 available but **no GPU in current allocation** (`nvidia-smi` not found, `/dev/nvidia*` absent). Load `CUDA/12.8.0` only if `gpu-*` product selected.
- NCCL, UCX, UCX-CUDA, GDRCopy modules exist for GPU jobs.

## 5. Scheduler — Slurm is Emulated, Not Systemd

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

## 6. Multi-Node

- `/etc/ucloud/nodes.txt` + `/etc/ucloud/node-0.txt` … contain hostnames.
- `/etc/hosts` adds `node0` aliases; `node0` resolves via `getent hosts node0`.
- `/tmp/hostfile` holds one hostname per line (here just `node0`).
- Orchestration: rank 0 runs `update_hosts <N>`, `service ssh start`, `init_user.sh <N>` (populates `/root/.ssh/known_hosts` from `ssh_host_ed25519_key.pub`), then `wait-for node0:22,...`.
- SSH works passwordless to `node<i>` after init. Use `ssh node1 hostname` to test.

## 7. Runtime Environment

- OS: Ubuntu 24.04 Noble, kernel 6.12.0-211 EL10, x86_64, cgroup2.
- CPU: host has `AMD EPYC 9535 64-Core ×2` (256 threads, 2 NUMA nodes) — but your job's vCPUs vary (request determines it). Respect cgroups; don't spawn 256 threads naïvely — use `nproc` or `JobParameters.json` cpu count, pin with `OMP_NUM_THREADS`.
- Memory: host 754 GiB visible via `free -h`, but your job's memory varies per request (e.g. this job was 3 GiB, others may be 16/64/192 GiB). Always check `JobParameters.json` / `JobParameters.json` `memoryInGigs` for true limit — `free` lies.
- `ulimit -n 1048576`, `stack 8192k`, `sudo NOPASSWD:ALL`.
- Locale: `LC_ALL=C.UTF-8` (not `en_US`). Some tools expect UTF-8 — keep it.
- `starship` prompt + `fastfetch` + `tmux -u` preconfigured; `BASH_ENV=/opt/lmod/lmod/init/bash` auto-loads Lmod.
- Web terminal: `ttyd` on port 7681 (`altClickMovesCursor`, `enableSixel`, `fontSize 20`).
- UCloud metrics: `/opt/ucloud/ucmetrics viz` runs in background (do not kill).

## 8. Python / Node / Containers

```bash
python3 --version          # 3.12.3 system; for newer load module: module load Python/3.13.1
pip list | head; pip install --user ...   # --user lands in ~/.local (ephemeral) → prefer venv in /work
/node --version => v22.23.2 at $COLLECTION_ROOT/nodejs/current/bin/node  (e.g. /work/<COLLECTION>/nodejs/current/bin/node)
npm --version => 10.9.8, prefix=$COLLECTION_ROOT  (or /work/<COLLECTION>)
which singularity apptainer docker  # none — WekaFS container, no user containers
```

- Create venvs in `/work`: `python3 -m venv /work/venv && source /work/venv/bin/activate`.
- For reproducible Python use `module load Python-bundle-PyPI` or EasyBuild `SciPy-bundle`.

## 9. Efficient Agent Workflow

1. **Read JobParameters first** — never assume cores/mem.
2. **Check module path** — `echo $MODULEPATH` then `module avail <pattern>` before loading.
3. **Use /tmp for compiles**, `/work` for outputs. WekaFS has `writecache` but high latency — small-file I/O to `/tmp` is faster, then `rsync` to `/work`.
4. **Batch bash calls** — one `bash` tool call per logical group; avoid N× `module list`.
5. **Persist env** — append exports to `$COLLECTION_ROOT/env.sh` (e.g. `/work/<COLLECTION>/env.sh`) not `.bashrc` directly; source it.
6. **Multi-node**: test `srun -N <N> hostname` or `mpirun --hostfile /tmp/hostfile` after SSH ready.
7. **No internet assumptions** — internet works (google/ping ok) but cache downloads to `/work`.

## 10. Common Pitfalls

- **Empty slurm.conf** → run `bash /tmp/tm1.sh`? No — `gen_slurm_conf` needs sed replacement; inspect `/tmp/tm1.sh` instead.
- **MODULEPATH overwritten** — `/opt/easybuild/ubuntu-24.04/amd/modules/all` is set in `~/.bashrc`; `module use /opt/easybuild/modules/all` silently masks vendor modules.
- **Writing to /home** → lost on reschedule. Use `/work`.
- **Assuming GPU** → `nvidia-smi` fails; check `JobParameters.json` `gpu` field before `module load CUDA`.
- **256-thread spawn** → OOM-killer (host has 256 threads but job may have 1–64 vCPUs). Pin with `OMP_NUM_THREADS=$(nproc)` or `$(jq .resources[0].memoryInGigs)` / `cpu` from `JobParameters.json`.
- **Systemd** → `systemctl` always fails (`PID 1` is bash). Use direct daemon calls.
- **Locale build failures** → some autotools check for `en_US.UTF-8`; export `LC_ALL=C.UTF-8` is fine, but install `language-pack-en` if needed.

## 11. Quick Reference Commands

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

## 12. When to Ignore This Skill

Plain Ubuntu container work (e.g., editing `$COLLECTION_ROOT/*.sh` or `/work/<COLLECTION>/*.sh`, using `pi`/`claude` CLI) doesn't need HPC steps. Only invoke HPC logic for compiles, MPI, batch jobs, module loads, or multi-node work.
