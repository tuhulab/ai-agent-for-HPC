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

### 1.2 Authentication & Guardrail Protocol

- The SAML path (`Login` button → WAYF via `auth.cloud.sdu.dk`) is a ForgeRock flow that is slow and flaky under automation. Prefer the **direct login form**: on `/app/login` click **"Other login options →"**, which reveals Username + Password textboxes (AX names: "Username", "Password") and a Login button.
- **Interactive Guardrail**: When an automated agent lands on the login page without an active session, it **must prompt the user** for their Username and Password via interactive input (`ask` tool), fill the fields, and submit.
- After submitting credentials, a **"6-digit code"** TOTP field appears when 2FA is enabled. The agent **must immediately prompt the user** for the current 6-digit TOTP code and submit without delay (the code rotates every 30 s).
- Prove login succeeded: page title becomes `UCloud | Dashboard` and the URL is `/app` (not `/app/login`).
- The session lives in the browser cookies and persists across navigations. If `/app/*` redirects back to `/app/login`, the session expired — re-authenticate through the guardrail.

### 1.3 Workspace / project selector — ⚠️ the top-right dropdown

The **top-right dropdown** (shows the current workspace, e.g. `My workspace`) is the **workspace/project switcher** — NOT settings and NOT an app menu.
- DOM structure: `.project-switcher` contains `[data-component="project-switcher"]` and `.context-switcher-trigger74` (or `span[data-dropdown-trigger]`).
- Clicking `.context-switcher-trigger74` opens the searchable project list popover (e.g. `BINF INFIMM`, `CSCC`, `image_analysis`, `Machine Learning`, `VUA clinical data`). Clicking the target project switches the global context for file dialogs, drives, billing, and job creation.
- Before launching, monitoring, or touching files, **read the value of the top-right dropdown and confirm it is the intended project.** An agent clicking around can silently submit a job billed to the wrong project or attach the wrong drive.
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
| SSH access | **native `<select>`** (Enabled/Disabled) | enable to get an `ssh` command in the progress view → see §2.4 |
| Private network #1 / Public IP #1 | readonly textbox | advanced connectivity |
| Job report sample rate | native `<select>`, default 250 ms | writes `/work/job-report.csv` |
| Modules path | readonly textbox | auto-load an Lmod modules folder at startup |
| Initialization | readonly textbox | **startup shell script** — see §2.3 |
| Extra options | textbox | extra args passed to the initialization script |
| E-mail notification settings | native `<select>` (id `job-email-notifications`) | |
| Submit | button "Submit ⌘⌥ Enter" | submit the job |

terminal-ubuntu specifics (observed UCloud 2026.5.0):

- **vCPU slider**: after picking `cpu-amd-zen5`, a range slider appears with markers `1 2 4 8 16 32 64 128`; default = 1 → product `cpu-amd-zen5-1-vcpu`, caption "1 vCPU (AMD EPYC 9535) · 3 GB RAM (DDR5-6000)". The selected product id is staged in a hidden input as JSON: `{"provider":"ucloud","category":"cpu-amd-zen5","id":"cpu-amd-zen5-1-vcpu"}`. Changing the slider updates the product id (e.g. `...-2-vcpu`).
- **Number of nodes** textbox (multi-node: set >1 for a cluster; see §3/§13).
- Additional selects: `Shell type` (Bash/Zsh/Fish), `Enable tmux` (On/Off), `Slurm cluster` (Yes/No), `Job report sample rate` (`app-param-ucMetricSampleRate`), E-mail notifications.
- To programmatically set a select: assign `select.value` and dispatch `change` + `input` (bubbles) — the AX "combobox" snapshot lies; these are native `<select>` elements with `class=select20`.

### 2.1 Machine type dialog

Click `div[data-job-info-field="machine"]` (displays "No machine type selected" initially). A modal table opens with rows: Type | Machine type | Description | Status (e.g. `CPU | cpu-amd-zen5 | General purpose CPU machines.`). Click the `<tr>` corresponding to `cpu-amd-zen5` — the dialog closes and the field updates:

- Hidden input `reservation-machine` is populated with JSON, e.g. `{"provider":"ucloud","category":"cpu-amd-zen5","id":"cpu-amd-zen5-1-vcpu"}`.
- Right side shows queue status text: **"This machine type is available."** (green), a busy warning (yellow), or unavailable/queued (red).
- **Est. cost** (Core-hours) and **Balance** appear after selection; an insufficient balance shows a warning. Never submit past a balance warning without confirming.

### 2.2 Attaching folders (Permanent Storage Mounts — UCloud 2026.5.0 Layout)

Click `Folder #1` (`#app-param-resourceFolder0visual`) → Places browser opens:

- **Sidebar navigation**: The left sidebar lists `Favorites`, `My workspace`, and project drives under the active workspace (e.g. under `BINF INFIMM`: `TB group`, `Adjuvant group`, `Data_backup`, `Bioinformatics`, `Chlamydia group`, `INFIMM Public`, `data_migration`).
- Click the drive name in the sidebar (e.g. `TB group`).
- **Mount Selection**: Click the header button **"Use this folder" (`button[data-tag="Use_this_folder-action"]` or ⌥G)** to select the root of that drive.
- **Mount mapping**: Attached folders mount as subdirectories under `/work/<FolderName>` inside the container (e.g., Folder #1 named `TB group` mounts at `/work/TB group`). Multiple folders can be attached as Folder #1, Folder #2, etc.
- ⚠️ **CRITICAL PERSISTENCE RULE**: The `/work` root directory in the container is an **ephemeral mount point**. Only the subdirectories that correspond to attached folders (`/work/<FolderName>/...`) are backed by persistent WekaFS storage and survive job termination. If a job is launched **without attaching a folder**, `/work` contains no persistent volumes, and all work done in the container is permanently lost on exit.
### 2.3 Initialization script (auto-setup on boot) — key automation lever

"Initialization" attaches a `.sh` script that runs at job startup. Use it to bootstrap the container deterministically every launch:

```bash
#!/bin/bash
set -e
# Discover primary mounted persistent directory under /work
MOUNTED_DIR="$(ls -d /work/*/ 2>/dev/null | grep -v 'lost+found' | head -n 1 | sed 's/\/$//')"
[ -n "$MOUNTED_DIR" ] && source "$MOUNTED_DIR/env.sh" 2>/dev/null || true
[ -n "$MOUNTED_DIR" ] && export PATH="$MOUNTED_DIR/nodejs/current/bin:$PATH"
# load modules, install what's missing, start services…
```

"Extra options" passes CLI args to that script. Pair with a persistent `initiation.sh` in your collection (see §9) for idempotent setup.

### 2.4 SSH access — enable + read the port

Enable `SSH access` (native select → `Enabled`) at submission time; the connection endpoint only exists on SSH-enabled jobs.

After the job starts, the progress view shows an **SSH widget** with a "Copy to clipboard" button containing:

```
ssh ucloud@ssh.cloud.sdu.dk -p <PORT>
```

- The **port is per-job and assigned at startup** (example: `-p 2820`). Parse it out of the progress view (it renders in a `<pre>`/`<code>`, not plain text — query `pre, code` selectors), or click Copy to clipboard.
- `ssh.cloud.sdu.dk` is the gateway; the job itself answers as `ucloud@j-<jobid>-job-0` inside the cluster. Verify: `ssh -p <PORT> ucloud@ssh.cloud.sdu.dk 'hostname'` should print `j-<jobid>-job-0`.
- The only way to get SSH on a running-but-not-ssh-enabled job is to stop it and relaunch with SSH enabled — the setting cannot be added mid-run (the SSH widget is absent for non-SSH jobs).

### 2.5 Human Connection Helper (`connect_ucloud`) — SIT vs Non-SIT

> ℹ️ **FOR HUMAN USERS ONLY**: This utility updates the human operator's local `~/.ssh/config` and launches VSCode Remote-SSH. **AI agents should NOT use this helper or mutate `~/.ssh/config`** — see §6.3 for AI agent SSH workflows.

On the **host machine**, human users connect with the bundled helper:

```bash
# Target Host Options:
#   --vm               Target 'Host ucloud-vm' (default, dedicated KVM VM)
#   --k8s              Target 'Host ucloud-k8s' (Kubernetes container job)

# Statens IT (SIT) managed equipment (SSI network — ProxyJump via uGerm)
connect_ucloud <PORT>                     # auto-detects SIT, updates ucloud-vm
connect_ucloud --vm <PORT>                # target ucloud-vm
connect_ucloud --k8s <PORT>               # target ucloud-k8s
connect_ucloud --sit <PORT>               # explicitly force SIT mode
connect_ucloud --sit --ugerm-user hutu <PORT>

# Non-SIT / Personal / Unrestricted equipment (Direct connection)
connect_ucloud --direct <PORT>            # direct connection without ProxyJump

Source: [`skills/ucloud-hpc/connect_ucloud.sh`](skills/ucloud-hpc/connect_ucloud.sh) in this repo (installed at `/usr/local/bin/connect_ucloud` or `~/bin/connect_ucloud`). It:

1. backs up `~/.ssh/config` → `~/.ssh/config_backups/config_<timestamp>`,
2. normalizes and updates the `Host ucloud` block's `Port`, `ProxyJump`, `LocalForward`, and host-checking directives,
3. opens VSCode Remote-SSH at `vscode-remote://ssh-remote+ucloud/work` (or updates config without launching if `--no-code` is passed).

#### Manual `~/.ssh/config` Reference for Human Users

**1. Statens IT (SIT) Managed Equipment (SSI Network)**
```sshconfig
Host ucloud
  HostName ssh.cloud.sdu.dk
  User ucloud
  Port <PORT>
  ProxyJump <UGERM_USER>@login.ugerm.dksund.dk
  LocalForward 8888 localhost:8888
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

**2. Non-SIT / Personal Equipment (Direct Connection)**
```sshconfig
Host ucloud
  HostName ssh.cloud.sdu.dk
  User ucloud
  Port <PORT>
  LocalForward 8888 localhost:8888
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

Afterwards `ssh ucloud` connects straight to the job. Verify: `ssh ucloud 'hostname'` → `j-<jobid>-job-0`.
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

- **Scheduled/queued**: "Cancel reservation" button removes it before start (**also requires a press-and-hold ~3 s** — a plain click is ignored; `mouse.down()` → wait ~3 s → `mouse.up()`).
- **Suspended** (job paused, machine powered off, e.g. idle expiry): the progress view shows "Your job is temporarily suspended" with ONLY **Cancel reservation** (no Stop application). Hold it the same way — the job then completes ("Your job has completed (ID: …)").
- **Running**: time allocation can be extended; **"Stop application" requires a press-and-hold (~3 s)** — a plain click is ignored, so `mouse.down()` → wait ~3 s → `mouse.up()` on the button center. Terminating early this way completes the job (state flips to "Your job has completed … processed successfully"). "Open terminal" opens an in-browser terminal; the **SSH widget** (see §2.4) shows `ssh ucloud@ssh.cloud.sdu.dk -p <PORT>` with a copy button when SSH was enabled; live CPU/memory/network (+GPU) widgets top-right; the job id shown in the title (`(ID: …)`).
- **Completed**: "Your job has completed" + **Run again** button (reruns with identical params); output folder + results listed (`Jobs/<app>/<id>` in your drive). Jobs can be **Suspended** when idle (machine powered off) — resume by starting it again.

### 5.3 Job output folder & Unmounted `/work` Artifacts

When a job completes, UCloud saves its output into the member's drive under:

```
/Member Files: <User#Tag> (<DriveID>)/Jobs/<AppName>/<JobID>/<User#Tag>/
```
(e.g. `/Member Files: TuHu#2222 (914637)/Jobs/JupyterLab/12378971/TuHu#2222/` or `Jobs/<app>/<job-id>/...`)

Contains:
- `stdout.txt` — program stdout / logs,
- `JobParameters.json` — exact submission params (reuse via Import),
- `job-report.csv` — resource sampling (if enabled),
- `job-0.sh` — backend start command,
- **Any unmounted files/repos created directly in `/work/`** — e.g. if you ran `git clone` or created a folder at `/work/my-repo`, it will NOT appear at `/work/my-repo` in future jobs; instead, it is archived inside this job output folder on your drive.

**How to recover unmounted files from a prior run**:
1. In web UI: go to `Files` (`/app/drives`) → open `Jobs/<AppName>/<JobID>/<User#Tag>/` → Move/Copy the folder into your persistent project drive.
2. In launch form: attach the prior job output folder `Jobs/<AppName>/<JobID>/...` as Folder #1 to access its contents inside a new container.
3. **Best practice**: Avoid recovery altogether by always working inside a pre-mounted persistent folder `/work/<MOUNTED_FOLDER>/...`.
## 6. Programmatic Automation Architecture & End-to-End Recipe

### 6.1 DOM Automation vs. Desktop Screen Automation

> ⚠️ **CRITICAL AUTOMATION DIRECTIVE**:
> - **NEVER use OS desktop pixel automation (`computer` tool / screen recording)**. Desktop screen capture requires OS-level permissions (e.g. macOS Privacy & Security Screen Recording), is brittle across screen resolutions, and fails when headless.
> - **ALWAYS use headless browser DOM automation via Puppeteer (`browser.open` / `tab.run`)**. Interact directly with DOM elements using Javascript evaluation and standard web events.

---

### 6.2 Complete Lifecycle Automation Script (Evaluator Copy-Pasteable)

Below is the complete, proven recipe to automate UCloud job launch and SSH connection:

```javascript
// 1. Open Headless Browser Tab
const tab = await browser.open({ name: "ucloud", url: "https://cloud.sdu.dk/app" });
await new Promise(r => setTimeout(r, 2000));

// 2. Handle Login & Guardrail if session expired
if ((await tab.url()).includes("/app/login")) {
  // Click "Other login options →"
  await tab.run(async ({ page }) => {
    await page.evaluate(() => {
      const other = Array.from(document.querySelectorAll('*')).find(el => el.children.length === 0 && el.textContent.includes('Other login options'));
      if (other) other.click();
    });
  });
  await new Promise(r => setTimeout(r, 1000));

  // Prompt user for credentials (GUARDRAIL)
  // const { username, password } = await ask(...);
  await tab.run(async ({ page }, creds) => {
    await page.evaluate(({ u, p }) => {
      const uIn = Array.from(document.querySelectorAll('input')).find(i => i.placeholder?.includes('Username') || i.name === 'username' || i.type === 'text');
      const pIn = Array.from(document.querySelectorAll('input')).find(i => i.type === 'password');
      if (uIn) { uIn.value = u; uIn.dispatchEvent(new Event('input', { bubbles: true })); }
      if (pIn) { pIn.value = p; pIn.dispatchEvent(new Event('input', { bubbles: true })); }
      const btn = Array.from(document.querySelectorAll('button')).find(b => b.innerText.includes('Login'));
      if (btn) btn.click();
    }, creds);
  }, { args: { u: username, p: password } });
  await new Promise(r => setTimeout(r, 2000));

  // Prompt user for 2FA TOTP (GUARDRAIL)
  // const { totp } = await ask(...);
  await tab.run(async ({ page }, data) => {
    await page.evaluate(({ code }) => {
      const codeIn = Array.from(document.querySelectorAll('input')).find(i => i.placeholder?.includes('code') || i.type === 'text');
      if (codeIn) { codeIn.value = code; codeIn.dispatchEvent(new Event('input', { bubbles: true })); }
      const sub = Array.from(document.querySelectorAll('button')).find(b => b.innerText.includes('Submit'));
      if (sub) sub.click();
    }, data);
  }, { args: { code: totp } });
  await new Promise(r => setTimeout(r, 3000));
}

// 3. Switch Workspace to Target Project (e.g. BINF INFIMM)
await tab.goto("https://cloud.sdu.dk/app/jobs/create?app=terminal-ubuntu");
await new Promise(r => setTimeout(r, 1500));
await tab.run(async ({ page }) => {
  await page.evaluate(async () => {
    const trigger = document.querySelector('.context-switcher-trigger74') || document.querySelector('.project-switcher');
    if (trigger && !trigger.innerText.includes('BINF INFIMM')) {
      trigger.click();
      await new Promise(r => setTimeout(r, 600));
      const item = Array.from(document.querySelectorAll('*')).find(el => el.children.length === 0 && el.textContent.trim() === 'BINF INFIMM');
      if (item) item.click();
    }
  });
});
await new Promise(r => setTimeout(r, 1500));

// 4. Configure Job Parameters
await tab.run(async ({ page }) => {
  await page.evaluate(() => {
    // Job Name
    const name = document.getElementById('reservation-name');
    if (name) { name.value = 'my-analysis-job'; name.dispatchEvent(new Event('input', { bubbles: true })); }
    // Hours
    const hours = document.getElementById('reservation-hours');
    if (hours) { hours.value = '4'; hours.dispatchEvent(new Event('input', { bubbles: true })); }
    // Enable SSH Access
    const selects = Array.from(document.querySelectorAll('select'));
    const ssh = selects.find(s => Array.from(s.options).some(o => o.text === 'Enabled'));
    if (ssh) { ssh.value = 'true'; ssh.dispatchEvent(new Event('change', { bubbles: true })); }
  });
});

// 5. Select Machine Type (cpu-amd-zen5)
await tab.run(async ({ page }) => {
  const machBtn = await page.$('div[data-job-info-field="machine"]');
  if (machBtn) await machBtn.click();
  await new Promise(r => setTimeout(r, 600));
  await page.evaluate(() => {
    const trs = Array.from(document.querySelectorAll('tr'));
    const zen5 = trs.find(r => r.innerText.includes('cpu-amd-zen5'));
    if (zen5) {
      zen5.click();
      Array.from(zen5.querySelectorAll('td, span, div')).forEach(c => c.click());
    }
  });
});
await new Promise(r => setTimeout(r, 800));

// 6. Attach Persistent Drive(s) via Places Modal
await tab.run(async ({ page }) => {
  await page.evaluate(async () => {
    const drivesToAttach = ["TB group"]; // or multiple drives
    for (let i = 0; i < drivesToAttach.length; i++) {
      const driveName = drivesToAttach[i];
      const visual = document.getElementById(`app-param-resourceFolder${i}visual`);
      if (!visual) break;
      visual.click();
      await new Promise(r => setTimeout(r, 1000));
      const dialog = document.querySelector('[role="dialog"]');
      const sidebar = dialog.querySelector('.file-selector-sidebar127') || dialog.querySelector('aside');
      const target = Array.from(sidebar.querySelectorAll('*')).find(el => el.children.length === 0 && el.innerText.trim() === driveName);
      if (target) {
        target.scrollIntoView();
        target.click();
        await new Promise(r => setTimeout(r, 600));
        const useBtn = dialog.querySelector('button[data-tag="Use_this_folder-action"]');
        if (useBtn) useBtn.click();
        await new Promise(r => setTimeout(r, 800));
      }
    }
  });
});
await new Promise(r => setTimeout(r, 1000));

// 7. Submit Job
await tab.run(async ({ page }) => {
  await page.evaluate(() => {
    const submit = Array.from(document.querySelectorAll('button')).find(b => b.innerText.includes('Submit'));
    if (submit) submit.click();
  });
});

// 8. Poll for Running State & Dynamic SSH Port
let sshPort = null;
for (let i = 0; i < 30; i++) {
  await new Promise(r => setTimeout(r, 3000));
  const info = await tab.run(async ({ page }) => {
    return await page.evaluate(() => {
      const text = document.body.innerText;
      const codes = Array.from(document.querySelectorAll('pre, code, span, div')).map(el => el.innerText).filter(Boolean);
      const sshLine = codes.find(c => c.includes('ssh ucloud@ssh.cloud.sdu.dk -p'));
      return { text, sshLine };
    });
  });
  if (info.sshLine) {
    const match = info.sshLine.match(/-p\s+(\d+)/);
    if (match) { sshPort = match[1]; break; }
  }
}
```

---

### 6.3 Agent In-Container Execution vs Human Connection

#### AI Agent Workflow: Parameterized Direct SSH (In-Memory Port)

> ⚠️ **CRITICAL AGENT RULE**: AI agents **MUST NOT modify `~/.ssh/config`**. Retain `sshPort` in memory from step 8 above and execute remote commands directly:

**1. Non-SIT / Personal / Unrestricted Environment (Direct SSH)**:
```bash
# Verify connection
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" ucloud@ssh.cloud.sdu.dk 'hostname'
# Returns: j-<job-id>-job-0

# Execute workload inside persistent mount
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" ucloud@ssh.cloud.sdu.dk 'cd "/work/TB group" && python3 my_script.py'
```

**2. Statens IT (SIT) Managed Equipment (via uGerm Jump Host)**:
```bash
# When running on SSI / Statens IT equipment where outbound high ports are firewalled:
UGERM_USER="${UGERM_USER:-hutu}"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J "${UGERM_USER}@login.ugerm.dksund.dk" -p "$SSH_PORT" ucloud@ssh.cloud.sdu.dk 'hostname'

# Execute workload
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J "${UGERM_USER}@login.ugerm.dksund.dk" -p "$SSH_PORT" ucloud@ssh.cloud.sdu.dk 'cd "/work/TB group" && python3 my_script.py'
```

#### Human Operator Workflow (VSCode / SSH Config Helper)

If a human operator wants to inspect or work inside the running job via VSCode Remote-SSH or a dedicated terminal:

```bash
# Statens IT (SIT) equipment
connect_ucloud <PORT>

# Non-SIT equipment
connect_ucloud --direct <PORT>

# Afterwards, human can use:
ssh ucloud 'hostname'
```

Offer, don't assume: submitting a job **consumes credits** and starts compute — confirm the target project/machine size/hours at the point of submission.

---

### 6.4 Job Teardown & Credit Preservation Protocol (Human Confirmation Guardrail)

> ⚠️ **CRITICAL CREDIT PRESERVATION DIRECTIVE**:
> Active UCloud jobs continuously consume project core-hours (e.g., $32\text{ vCPUs} \times 24\text{ hours} = 768\text{ Core-hours}$). Leaving an instance running idle after workload completion bleeds project allocation.

#### 1. Mandatory Post-Execution Prompt
Whenever an automated workload (analysis, batch transfer, verification, compile, etc.) completes, the agent **MUST prompt the human user** (using `ask` tool or turn confirmation) before ending the turn:

> *"Workload completed successfully on UCloud job `<JOB_ID>` (`<JOB_NAME>`). Would you like me to terminate the job now to stop credit consumption, or keep it running for further interactive work?"*

#### 2. Programmatic Job Termination Recipe (Puppeteer Press-and-Hold)

When confirmed by the user, automate job termination via headless browser:

```javascript
// 1. Open / Navigate to Job Properties View
const tab = await browser.open({ name: "ucloud", url: `https://cloud.sdu.dk/app/jobs/properties/${jobId}` });
await new Promise(r => setTimeout(r, 2000));

// 2. Perform Press-and-Hold (~3.2s) on "Stop application" or "Cancel reservation"
await tab.run(async ({ page }) => {
  const btn = await page.evaluateHandle(() => {
    return Array.from(document.querySelectorAll('button')).find(b => 
      b.innerText && (b.innerText.includes('Stop application') || b.innerText.includes('Cancel reservation'))
    );
  });
  if (btn && (await btn.evaluate(b => !b.disabled))) {
    const box = await btn.boundingBox();
    if (box) {
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.down();
      await new Promise(r => setTimeout(r, 3200));
      await page.mouse.up();
    }
  }
});
await new Promise(r => setTimeout(r, 3000));

// 3. Verify Job Status Flips to Completed
const completed = await tab.run(async ({ page }) => {
  return await page.evaluate(() => {
    return document.body.innerText.includes('Your job has completed') || 
           document.body.innerText.includes('processed successfully');
  });
});
await tab.close();
```
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
# Resources & job metadata (truth)
cat /work/JobParameters.json          # allocated resources
cat /work/.script-params.yaml         # template params
cat /etc/ucloud/nodes.txt             # head node hostname
cat /etc/ucloud/number_of_nodes.txt   # node count
cat /tmp/hostfile 2>/dev/null || echo "single-node"
lscpu | head -20; free -h             # lscpu/free show HOST (e.g. 256 cores / 754 GiB), not your allocation
jq . /work/JobParameters.json        # YOUR allocation: cpu/memory/gpu/nodes/time vary per job — never hardcode 1 vCPU / 3 GiB
env | grep -E "UCLOUD|PI_|MODULEPATH"

# Discover mounted permanent directories under /work (CRITICAL)
df -h | grep wekafs                  # shows mounted WekaFS persistent drives under /work/
mount | grep '/work/'                # shows exact mount points
ls -ld /work/*/                      # lists attached permanent directory candidates
jq -r '.request.parameters | to_entries[] | select(.value.type? == "file") | .value.path' /work/JobParameters.json 2>/dev/null
```

Key env (discover, don't hardcode):
- `UCLOUD_JOB_ID`, `UCLOUD_RANK`, `UCLOUD_TASK_COUNT`
- `UCLOUD_BASE_URL` (web UI)
- `PERSISTENT_ROOT` / `COLLECTION_ROOT` — your persistent mounted dir, e.g. `/work/<MOUNTED_FOLDER>` (resolve via `mount | grep wekafs` or `ls -d /work/*/` or `df -h /work/*`)
- `PI_CODING_AGENT_DIR` — e.g. `/work/<MOUNTED_FOLDER>/.pi/agent` (not `~/.pi`)
- `MODULEPATH=/opt/easybuild/ubuntu-24.04/amd/modules/all` (or `intel`)

## 9. Filesystem — What Persists?

```
 /work/                               Ephemeral container mount root (NOT persistent!)
   ├── <MOUNTED_FOLDER_1>/            WekaFS shared volume (Folder #1) — PERSISTENT across jobs
   │     ├── env.sh                   Persistent PATH / npm prefix / pi config
   │     ├── nodejs/current           Node v22.23.2
   │     ├── bin/pi, bin/claude
   │     ├── .pi/agent                Real pi config (settings, sessions, auth)
   │     ├── initiation.sh            Startup script
   │     └── venv/                    Python virtual environments
   ├── <MOUNTED_FOLDER_2>/            WekaFS shared volume (Folder #2, if attached) — PERSISTENT
   ├── JobParameters.json             Job metadata — EPHEMERAL in container (copied to Jobs/<id>/)
   └── job-report.csv                 Resource metric sampling — EPHEMERAL in container
 /home/ucloud                         Container overlay — EPHEMERAL (lost on job end)
 /opt/easybuild/ubuntu-24.04          WekaFS RO mount — modules + software (790604)
 /tmp                                 Local XFS scratch — fast but ephemeral, on /dev/mapper/vg0-lv_scratch
 /etc/ucloud                          K8s emptyDir — node list, rank, token
 overlay /                            Container root — overlayfs, 1.5T, ephemeral
```

> ⚠️ **Persistent vs Ephemeral under `/work`**:
> - `/work` itself is an ephemeral mount namespace.
> - **If you create a repo/file directly under `/work` (unmounted)** (e.g. `/work/my-repo`), it will **NOT** be at `/work/my-repo` in your next job. Instead, UCloud captures it on job completion and moves it to your drive at `/Member Files: <User#Tag> (<DriveID>)/Jobs/<AppName>/<JobID>/<User#Tag>/my-repo`.
> - **Only subdirectories corresponding to mounted folders** (`/work/<MOUNTED_FOLDER>/...`) persist directly in place across jobs.
> - Always locate your mounted folder via `ls -d /work/*/` or `mount | grep wekafs` (e.g., `/work/my-project` or `/work/my-collection`). Never hardcode folder names.
**Rules:**
- **Never write directly to `/work/` root** — write all code, venvs, configs, and output files to `/work/<MOUNTED_FOLDER>/...`.
- Do not write large data to overlay `/` or `/home` (ephemeral).
- Global `npm install -g` goes to `/work/<MOUNTED_FOLDER>` via `npm_config_prefix=/work/<MOUNTED_FOLDER>`. Never `sudo npm`.
- Keep `.bashrc`/`.zshrc` persistent hook: `source /work/<MOUNTED_FOLDER>/env.sh` restores PATH/pi/node.

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

- Create venvs inside your mounted permanent directory: `python3 -m venv /work/<MOUNTED_FOLDER>/venv && source /work/<MOUNTED_FOLDER>/venv/bin/activate` (NEVER at `/work/venv`).
- For pip cache / target: `pip install --target /work/<MOUNTED_FOLDER>/pydeps package` or configure `PIP_CACHE_DIR=/work/<MOUNTED_FOLDER>/.cache/pip`.
- For conda: configure `pkgs_dirs` and `envs_dirs` in `~/.condarc` to point inside `/work/<MOUNTED_FOLDER>/`.
- For reproducible Python use `module load Python-bundle-PyPI` or EasyBuild `SciPy-bundle`.

## 16. Efficient Agent Workflow

1. **Detect mounted permanent directories first** — run `ls -d /work/*/` or `mount | grep wekafs` to find your persistent mount path `/work/<MOUNTED_FOLDER>`. If none exists, warn immediately: no persistent storage attached.
2. **Read JobParameters** — never assume cores/mem.
3. **Check module path** — `echo $MODULEPATH` then `module avail <pattern>` before loading.
4. **Use /tmp for compiles**, `/work/<MOUNTED_FOLDER>/` for outputs. WekaFS has `writecache` but high latency — small-file I/O to `/tmp` is faster, then `rsync` to `/work/<MOUNTED_FOLDER>/`.
5. **Batch bash calls** — one `bash` tool call per logical group; avoid N× `module list`.
6. **Persist env** — append exports to `/work/<MOUNTED_FOLDER>/env.sh` not `.bashrc` directly; source it.
7. **Multi-node**: test `srun -N <N> hostname` or `mpirun --hostfile /tmp/hostfile` after SSH ready.
8. **Cache downloads** inside `/work/<MOUNTED_FOLDER>/`, not `/tmp` or bare `/work/`.
9. **Post-work Teardown Confirmation** — when automated tasks finish, always prompt the human operator whether to terminate the job to stop continuous credit consumption (see §6.4).
## 17. Common Pitfalls

Portal / launch side:
- **Top-right dropdown is the workspace switcher** (see §1.3) — never treat it as settings/account; verify the active project before submitting or picking folders, or you bill the wrong project.
- **Launching without attaching a folder** (see §2.2) — leaves `/work` purely ephemeral with no mounted persistent volume; all data generated during the job will be destroyed on exit.
- **Destructive actions are press-and-hold (~3 s), not clicks** — Stop application (running jobs) AND Cancel reservation (scheduled/suspended jobs) both ignore a plain click; must `mouse.down()` → ~3 s → `mouse.up()` (§5.2).
- **Form selects are native `<select>`s** even though AX reports "combobox" — set `.value` + dispatch `change`; clicking visible "Enabled/Disabled" options is flaky. SSH access ships as `Enabled`/`Disabled` with `value` `true`/`false`.
- **SSH is a submission-time choice** — the SSH widget (and port) does not exist for jobs launched without it; must stop + relaunch (§2.4).
- **SAML/WAYF flow hangs** under automation (spinner on the ForgeRock consent page) — prefer the direct login form off "Other login options →"; don't fight the IdP redirect loops.
- **TOTP expires fast** (30 s) — fetch/submit promptly; a stale code yields "invalid code" and you must re-enter.
- **Submit consumed credits silently** — check Est. cost vs Balance and the machine availability color before hitting Submit.
- **Import dialog shows "No jobs found with active filters"** even when old jobs exist — filters scope to current workspace/app/version; broaden or upload a JobParameters.json instead.
- **Reading a job row's Actions on the wrong row** — row selection persists; confirm the job id (top of Properties page) matches the intended run before Stop/Run again.
- **AI agents mutating `~/.ssh/config`** (see §6.3) — agents must never mutate host SSH configuration files. Retain the parsed `sshPort` in memory and invoke SSH directly (`-p <PORT>` or `-J <ugerm_user>@login.ugerm.dksund.dk -p <PORT>`).
- **Direct connection failure on Statens IT (SIT) equipment** (see §2.5, §6.3) — on the SSI network, outbound SSH to high ports is blocked; must use uGerm ProxyJump (`-J <user>@login.ugerm.dksund.dk` or `connect_ucloud --sit`).
- **Leaving idle jobs running after workload completion (Credit Bleed)** (see §6.4) — jobs consume project allocations every active hour. Agents must prompt the user upon finishing and execute press-and-hold teardown when confirmed.
- **Empty slurm.conf** → run `bash /tmp/tm1.sh`? No — `gen_slurm_conf` needs sed replacement; inspect `/tmp/tm1.sh` instead.
- **MODULEPATH overwritten** — `/opt/easybuild/ubuntu-24.04/amd/modules/all` is set in `~/.bashrc`; `module use /opt/easybuild/modules/all` silently masks vendor modules.
- **Creating an unmounted repo directly in /work/** → Next job won't find it under `/work/`! It gets archived to `/Member Files: <User#Tag> (<DriveID>)/Jobs/<AppName>/<JobID>/<User#Tag>/`. To avoid having to recover files from job archives, always clone and write inside `/work/<MOUNTED_FOLDER>/`.
- **Writing to /home or /tmp** → lost on reschedule.
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
npm install -g cowsay        # lands in /work/<MOUNTED_FOLDER>/bin via npm_config_prefix
pip install --target /work/<MOUNTED_FOLDER>/pydeps package
```

## 19. When to Ignore This Skill

Plain Ubuntu container work (e.g., editing `$COLLECTION_ROOT/*.sh` or `/work/<COLLECTION>/*.sh`, using `pi`/`claude` CLI) doesn't need HPC steps, and pure portal browsing (files, dashboards) doesn't need the in-job sections. Invoke HPC logic for compiles, MPI, batch jobs, module loads, multi-node work, and invoke §2–§7 whenever a job must be started, monitored, stopped, or rerun from the web portal.