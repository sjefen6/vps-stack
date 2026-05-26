#!/bin/bash
set -euo pipefail

INI="/vps-stack/secrets/backup.ini"
BACKUP_TEST="${BACKUP_TEST:-0}"

ini_get() {
    grep -E "^\s*$1\s*=" "$INI" | sed -E 's/^\s*[^=]+=\s*//' | tr -d '\r' | head -1
}

if [[ "$BACKUP_TEST" == "1" ]]; then
    echo "[$(date)] TEST MODE: using local ephemeral repo, skipping B2 and email"
    export RESTIC_PASSWORD="test"
    export RESTIC_REPOSITORY="/tmp/restic-test-repo"
else
    # Load restic config
    export RESTIC_PASSWORD="$(ini_get password)"
    export RESTIC_REPOSITORY="$(ini_get repository)"
    export B2_ACCOUNT_ID="$(ini_get account_id)"
    export B2_ACCOUNT_KEY="$(ini_get account_key)"

    # Write msmtp config
    GMAIL_USER="$(ini_get user)"
    GMAIL_APP_PASSWORD="$(ini_get app_password)"

    cat > /etc/msmtprc << EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account        gmail
host           smtp.gmail.com
port           587
from           $GMAIL_USER
user           $GMAIL_USER
password       $GMAIL_APP_PASSWORD

account default : gmail
EOF
    chmod 600 /etc/msmtprc
fi

# Initialize restic repo on first run (no-op if already exists)
restic init 2>/dev/null || true

# Write crontab and start scheduler
echo "${BACKUP_SCHEDULE} /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

echo "[$(date)] Backup container started. Schedule: ${BACKUP_SCHEDULE}"
exec crond -f -d 8
