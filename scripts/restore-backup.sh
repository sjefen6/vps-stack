#!/usr/bin/env bash
# Run a backup restore via the vps-backup Docker image.
#
# Prerequisites:
#   None (the script automatically builds the required Docker image).
#
# Usage:
#   ./scripts/restore-backup.sh --snapshots                       # list available snapshots
#   ./scripts/restore-backup.sh <target-dir> [snapshot]           # restore snapshot
#   ./scripts/restore-backup.sh <target-dir> [snapshot] --delete  # restore and remove files not in snapshot
#   ./scripts/restore-backup.sh --dry-run [snapshot]              # restore into Docker storage (no host mount)
#   ./scripts/restore-backup.sh --dry-run [snapshot] --delete     # same, with --delete
#                                                                  # useful on Windows — avoids slow WSL filesystem
#                                                                  # container stays alive for inspection via exec
#
# After restore, files will be under:
#   <target-dir>/          — full VPS-Stack directory
#   <target-dir>/db-dumps/  — database SQL dumps
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"

# Enforce VPS_HOSTNAME is configured in .env
if [[ ! -f "$REPO_ROOT/.env" ]]; then
    echo "ERROR: .env file not found at $REPO_ROOT" >&2
    exit 1
fi

VPS_HOSTNAME=$(grep -E "^\s*VPS_HOSTNAME\s*=" "$REPO_ROOT/.env" | sed -E 's/^\s*[^=]+=\s*//' | tr -d '\r' | tr -d '"' | tr -d "'" | head -1)
if [[ -z "$VPS_HOSTNAME" ]]; then
    echo "ERROR: VPS_HOSTNAME is not configured in your .env file." >&2
    exit 1
fi

if [[ ! -f "$SECRETS_DIR/backup.ini" ]]; then
    echo "ERROR: $SECRETS_DIR/backup.ini not found" >&2
    exit 1
fi

echo "=== Building backup/restore image ==="
docker build -t vps-backup --build-arg CACHE_BYPASS="$(date +%Y%m)" "$REPO_ROOT/dockerfiles/backup"

if [[ "${1:-}" == "--snapshots" ]]; then
    docker run --rm \
        --hostname "$VPS_HOSTNAME" \
        --entrypoint /usr/local/bin/restore.sh \
        -v "$SECRETS_DIR:/vps-stack/secrets:ro" \
        -v restic-cache:/root/.cache/restic \
        vps-backup snapshots
    exit 0
fi

# Parse all flags and positional args
DRY_RUN=0
DELETE=0
TARGET=""
SNAPSHOT="latest"
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --delete)  DELETE=1;  shift ;;
        --*)       echo "Unknown option: $1" >&2; exit 1 ;;
        *)         POSITIONAL+=("$1"); shift ;;
    esac
done

if [[ "$DRY_RUN" == "1" ]]; then
    SNAPSHOT="${POSITIONAL[0]:-latest}"
else
    TARGET="${POSITIONAL[0]:?Usage: $0 <target-dir> [snapshot-id] [--delete]}"
    SNAPSHOT="${POSITIONAL[1]:-latest}"
fi

EXTRA_ARGS=()

if docker inspect vps-restore &>/dev/null; then
    STATUS=$(docker inspect -f '{{.State.Status}}' vps-restore 2>/dev/null)
    if [[ "$STATUS" == "running" ]]; then
        read -rp "Container 'vps-restore' is already running. Remove it? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    fi
    docker rm -f vps-restore
fi

if [[ "$DRY_RUN" == "1" ]]; then
    EXTRA_ARGS=(-e KEEP_ALIVE=1 -v restic-restore:/restore)
    echo ""
    echo "Volume 'restic-restore' contains the restored files."
    echo "  docker run --rm -it -v restic-restore:/restore alpine sh  # re-inspect files"
    echo "  docker volume rm restic-restore                           # delete restored files"
    echo ""
else
    mkdir -p "$TARGET"
    TARGET="$(realpath "$TARGET")"
    EXTRA_ARGS=(-v "$TARGET:/restore")
fi

docker run --rm \
    --name vps-restore \
    --hostname "$VPS_HOSTNAME" \
    --entrypoint /usr/local/bin/restore.sh \
    -e DELETE_EXTRA="$DELETE" \
    -v "$SECRETS_DIR:/vps-stack/secrets:ro" \
    -v restic-cache:/root/.cache/restic \
    "${EXTRA_ARGS[@]}" \
    vps-backup "$SNAPSHOT"
