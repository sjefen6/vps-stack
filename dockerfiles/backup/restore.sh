#!/usr/bin/env bash
# Restore a restic snapshot to /restore inside the container.
#
# Usage (via restore-backup.sh on the host):
#   restore.sh [snapshot-id]     — restore snapshot (default: latest)
#   restore.sh snapshots         — list available snapshots
set -euo pipefail

INI="/vps-stack/secrets/backup.ini"

ini_get() {
    grep -E "^\s*$1\s*=" "$INI" | sed -E 's/^\s*[^=]+=\s*//' | tr -d '\r' | head -1
}

if [[ ! -f "$INI" ]]; then
    echo "ERROR: $INI not found. Mount secrets with -v <host-secrets>:/vps-stack/secrets:ro" >&2
    exit 1
fi

export RESTIC_REPOSITORY="$(ini_get repository)"
export RESTIC_PASSWORD="$(ini_get password)"
export B2_ACCOUNT_ID="$(ini_get account_id)"
export B2_ACCOUNT_KEY="$(ini_get account_key)"

ARG="${1:-latest}"

if [[ "$ARG" == "snapshots" ]]; then
    restic snapshots --no-lock
    exit 0
fi

SNAPSHOT="$ARG"
LOG="/restore/restore.log"

on_error() {
    echo "ERROR: restore failed (exit $?). Check log: $LOG" | tee -a "$LOG" >&2
}
trap on_error ERR

mkdir -p /restore
echo "Restoring snapshot '$SNAPSHOT' to /restore..." | tee "$LOG"
echo "Started: $(date)" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# Preserve existing .env — it will be restored from backup only if missing
EXISTING_ENV=""
[[ -f /restore/.env ]] && EXISTING_ENV="$(cat /restore/.env)"

RESTIC_EXTRA_FLAGS=""
[[ "${DELETE_EXTRA:-0}" == "1" ]] && RESTIC_EXTRA_FLAGS="--delete"

restic restore "$SNAPSHOT" --target /restore --json --no-lock --exclude=.git $RESTIC_EXTRA_FLAGS 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "Completed: $(date)" | tee -a "$LOG"

# Put back the pre-existing .env (overrides what restic restored)
if [[ -n "$EXISTING_ENV" ]]; then
    echo "$EXISTING_ENV" > /restore/.env
    echo "Preserved existing .env (not overwritten)" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "  Files:    /restore/"
echo "  DB dumps: /restore/db-dumps/"
echo "  Log:      /restore/restore.log"

if [[ "${KEEP_ALIVE:-0}" == "1" ]]; then
    echo ""
    echo "Container staying alive for inspection. Press Ctrl+C or run 'docker rm -f vps-restore' to clean up."
    trap 'exit 0' TERM INT
    sleep infinity &
    wait
fi
