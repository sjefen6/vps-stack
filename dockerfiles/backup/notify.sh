#!/usr/bin/env bash
# Send an email notification via msmtp
# Usage: notify.sh "Subject" "Body"

SUBJECT="${1:-Backup notification}"
BODY="${2:-}"
NOTIFY_EMAIL="$(grep -E "^\s*email\s*=" /vps-stack/secrets/backup.ini | sed -E 's/^\s*[^=]+=\s*//' | tr -d '\r' | head -1)"

if [[ -z "$NOTIFY_EMAIL" ]]; then
    echo "[notify] No email configured, skipping" >&2
    exit 0
fi

printf "Subject: [vps-backup] %s\nHost: %s\nDate: %s\n\n%s\n" \
    "$SUBJECT" "$(hostname)" "$(date)" "$BODY" \
    | msmtp "$NOTIFY_EMAIL"
