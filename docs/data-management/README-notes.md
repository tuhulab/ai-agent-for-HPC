# Operational Notes

## Access & security

- **Computerome SFTP:** `transfer.computerome.dk`, project `cu_10181`.
- **Two-step login required:** every authenticated session/service triggers a
  **2FA push notification** that must be approved on the account owner's phone.
  Authentication fails if the push is not approved within the auth window.
- **Github:** repo `INFIMM-Bioinformatics/data_management` (private). Push via a
  fine-grained **personal access token (PAT)** that has *Contents: write* on this
  repo. The PAT shown earlier **cannot create new repositories** (no org-admin /
  repo-creation permission) — repo creation must be done by an org admin if a new
  repo is ever needed.

## Deletion policy (IMPORTANT)

- **Never delete or modify anything on Computerome.** The assistant performs
  **read-only** operations on the source; it only *downloads/copies* from
  Computerome and never removes source files or directories.
- Use `rsync` **without `--delete`** (it only copies from source; it will not
  remove source files). The destination-side `--delete` flag must be avoided too
  unless explicitly authorised.
- Any cleanup / deletion of source data on Computerome
  (`/home/projects/cu_10181/...`) is done **by the owner manually**, never by the
  migration tooling.

## Credentials hygiene

- **Never commit** passwords, PATs, or SSH keys to this repository.
- Store long-lived secrets out-of-band (SSO vault / password manager) and pass
  them to runbooks via environment variables (e.g. `CM_PASS`, `GH_TOKEN`).
- If a secret is exposed, revoke it immediately and regenerate.

## Reconnecting to Computerome to finish the migration

The live connection is made with a `paramiko` (or `rsync`) client. Because 2FA
is interactive, plan the remaining transfers to minimise the number of push
approvals (batch `rsync` runs, keep one session alive).

Suggested workflow per dataset (matches what was done before, see
`/work/data_migration/bash_scripts/` on the destination):

```bash
# 1. On the source, build a checksum manifest
find <SRC> -type f -exec md5sum {} \; | sort > source_md5.txt

# 2. Transfer
rsync -avz --progress <user>@transfer.computerome.dk:<SRC> /work/data_migration/

# 3. On the destination, build a checksum manifest and diff
find /work/data_migration/<DST> -type f -exec md5sum {} \; | sort > dest_md5.txt
diff source_md5.txt dest_md5.txt
```

## This repo

- `docs/inventory-computerome.md` — live source snapshot (2026-08-27).
- `docs/migration-status.md` — source→destination comparison + remaining actions.
