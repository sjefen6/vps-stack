#!/usr/bin/env bash
set -euo pipefail

STEP="init"
START=$(date +%s)
DB_DUMP_DIR="/vps-stack/db-dumps"
BACKUP_TEST="${BACKUP_TEST:-0}"
INI="/vps-stack/secrets/backup.ini"
LOG=$(mktemp)

ini_get() {
    grep -E "^\s*$1\s*=" "$INI" | sed -E 's/^\s*[^=]+=\s*//' | tr -d '\r' | head -1
}

if [[ "$BACKUP_TEST" == "1" ]]; then
    export RESTIC_PASSWORD="${RESTIC_PASSWORD:-test}"
    export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/tmp/restic-test-repo}"
else
    export RESTIC_PASSWORD="${RESTIC_PASSWORD:-$(ini_get password)}"
    export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-$(ini_get repository)}"
    export B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-$(ini_get account_id)}"
    export B2_ACCOUNT_KEY="${B2_ACCOUNT_KEY:-$(ini_get account_key)}"
fi

notify() {
    [[ "$BACKUP_TEST" == "1" ]] && { echo "[notify] TEST MODE: $1"; return; }
    notify.sh "$1" "$(cat "$LOG")"
}

on_error() {
    local exit_code=$?
    notify "Backup FAILED (step: $STEP, exit: $exit_code)"
    rm -f "$DB_DUMP_DIR"/*.sql "$LOG"
    exit $exit_code
}
trap on_error ERR

# Tee all output to log and stdout
exec > >(tee -a "$LOG") 2>&1

# Step 1: DB dumps
STEP="db-dump"
echo "[$(date)] Starting DB dump..."
dump-dbs.sh "$DB_DUMP_DIR"

# Step 2: restic backup
STEP="restic-backup"
echo "[$(date)] Starting restic backup..."
cd /vps-stack
restic backup \
    --exclude=.git \
    --exclude=logs \
    .

# Step 3: forget + prune
STEP="restic-forget"
echo "[$(date)] Pruning old snapshots..."
KEEP_DAILY="${KEEP_DAILY:-$(ini_get keep_daily 2>/dev/null || echo 14)}"
KEEP_WEEKLY="${KEEP_WEEKLY:-$(ini_get keep_weekly 2>/dev/null || echo 8)}"
KEEP_MONTHLY="${KEEP_MONTHLY:-$(ini_get keep_monthly 2>/dev/null || echo 24)}"
KEEP_YEARLY="${KEEP_YEARLY:-$(ini_get keep_yearly 2>/dev/null || echo 10)}"
restic forget --prune \
    --keep-daily   "$KEEP_DAILY" \
    --keep-weekly  "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --keep-yearly  "$KEEP_YEARLY"

# Step 4: integrity check — weekly on Sundays
if [[ "$(date +%u)" == "7" ]]; then
    STEP="restic-check"
    echo "[$(date)] Running weekly integrity check..."
    restic check
fi

rm -f "$DB_DUMP_DIR"/*.sql

END=$(date +%s)
DURATION=$(( END - START ))
echo "[$(date)] Backup complete in ${DURATION}s"
notify "Backup successful"
rm -f "$LOG"
