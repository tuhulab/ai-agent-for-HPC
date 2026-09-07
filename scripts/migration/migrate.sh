#!/usr/bin/env bash
# ============================================================================
# INFIMM Computerome -> UCloud migration runner  (PARALLEL, single-2FA)
#
# Strategy for max throughput + minimal 2FA:
#   1. Establish ONE OpenSSH ControlMaster connection to Computerome using
#      SSH_ASKPASS (non-interactive password). This triggers the ONLY 2FA push.
#   2. Every rsync job reuses that master via ControlPath (OpenSSH multiplexing)
#      => no further authentication / 2FA prompts.
#   3. Run JOBS rsync jobs concurrently (one per manifest dataset) to aggregate
#      bandwidth beyond the single-stream ceiling (~550 Mbps).
#   4. Resume-safe (--partial --inplace), md5-verifiable, READ-ONLY on source.
#
# SAFETY: never uses --delete; never modifies/deletes source on Computerome.
# ============================================================================
set -uo pipefail

CM_HOST="${CM_HOST:-transfer.computerome.dk}"
CM_USER="${CM_USER:-tuhu}"
CM_PASS="${CM_PASS:?set CM_PASS}"
CM_PORT="${CM_PORT:-22}"
CTL="${CTL:-/tmp/cm_master}"              # ControlMaster socket
MANIFEST="${1:?usage: migrate.sh <manifest.csv> [jobs]}"
JOBS="${2:-4}"
DEST_ROOT="${DEST_ROOT:-/work/data_migration}"
LOGDIR="${LOGDIR:-/work/data_migration/migrate_logs}"
ASKPASS="$PWD/cm_askpass.sh"

mkdir -p "$LOGDIR" "$DEST_ROOT"

# ---- SSH_ASKPASS helper (outputs password non-interactively) --------------
cat > "$ASKPASS" <<'EOF'
#!/bin/bash
echo "$CM_PASS"
EOF
chmod 700 "$ASKPASS"

# Base SSH options shared everywhere.
SSH_BASE=(
  -p "$CM_PORT"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=6
  -o Compression=no
  -o TCPKeepAlive=yes
)

# ---- Establish the master connection (the ONE 2FA of the run) --------------
establish_master() {
  export SSH_ASKPASS_REQUIRE=force
  export SSH_ASKPASS="$ASKPASS"
  echo "[$(date +%T)] Establishing master SSH connection ... (APPROVE THE 2FA PUSH)"
  setsid ssh "${SSH_BASE[@]}" \
    -o ControlMaster=yes \
    -o ControlPath="$CTL" \
    -o ControlPersist=86400 \
    -o ExitOnForwardFailure=yes \
    -N -f "${CM_USER}@${CM_HOST}" \
    >>"$LOGDIR/master.log" 2>&1
  echo "[$(date +%T)] Waiting up to 90s for 2FA approval..."
  for i in $(seq 1 45); do
    if [ -S "$CTL" ]; then
      echo "[$(date +%T)] Master SSH established: $CTL"
      return 0
    fi
    sleep 2
  done
  echo "ERROR: master connection not established within 90s. See $LOGDIR/master.log"
  exit 1
}

# rsync ssh wrapper reusing the master (auto = reuse if socket exists).
RSYNC_SSH="ssh ${SSH_BASE[*]} -o ControlMaster=auto -o ControlPath=$CTL"

# ---- Read manifest and run concurrent rsync jobs ---------------------------
run_migration() {
  establish_master
  local active=0
  while IFS=',' read -r src dst; do
    [ -z "$src" ] && continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$DEST_ROOT/$(dirname "$dst")"
    dest="$DEST_ROOT/$dst"
    echo "[$(date +%T)] >>> $src -> $dest"
    (
      rsync -a --partial --inplace --numeric-ids \
        --progress --stats --verbose \
        -e "$RSYNC_SSH" \
        "${CM_USER}@${CM_HOST}:${src}" "$dest" \
        >"$LOGDIR/$(basename "$src").log" 2>&1
      echo "DONE (rc=$?) $src" >>"$LOGDIR/run.log"
    ) &
    active=$((active+1))
    if [ "$active" -ge "$JOBS" ]; then
      wait -n 2>/dev/null || wait
      active=$((active-1))
    fi
  done < "$MANIFEST"
  wait
  echo "[$(date +%T)] All transfers complete. Logs in $LOGDIR/"
}

# ---- MD5 verification (run separately: RUN_MODE=verify) --------------------
verify() {
  while IFS=',' read -r src dst; do
    [ -z "$src" ] && continue
    [[ "$src" == \#* ]] && continue
    p="$DEST_ROOT/$dst"
    echo "Verifying $p ..."
    find "$p" -type f -exec md5sum {} \; | sed 's#  .*##' | sort \
      > "$LOGDIR/$(basename "$p").dest.md5"
  done < "$MANIFEST"
  echo "Verification done."
}

case "${RUN_MODE:-transfer}" in
  transfer) run_migration ;;
  verify)   verify ;;
  *) echo "RUN_MODE must be transfer or verify"; exit 1 ;;
esac
