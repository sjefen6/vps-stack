#!/usr/bin/env bash
# Restore all .sql.gz dumps from /docker-entrypoint-initdb.d/dumps/
# Runs automatically on first container start via docker-entrypoint-initdb.d
set -euo pipefail

DUMPS_DIR="/dumps"
# Support password file (production) or env var (restore compose)
if [ -f "/secrets/db-root-password.txt" ]; then
    DB_PASS="$(cat /secrets/db-root-password.txt)"
else
    DB_PASS="${MARIADB_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}"
fi

echo "=== Restoring database dumps ==="

shopt -s nullglob
# Support both plain .sql (restic backups) and legacy .sql.gz
DUMPS=("$DUMPS_DIR"/*.sql "$DUMPS_DIR"/*.sql.gz)
if [ ${#DUMPS[@]} -eq 0 ]; then
    echo "⚠ No dumps found in $DUMPS_DIR, skipping restore."
    exit 0
fi

for DUMP in "${DUMPS[@]}"; do
    BASENAME=$(basename "$DUMP")
    if [[ "$BASENAME" == *.sql.gz ]]; then
        DB="${BASENAME%.sql.gz}"
        READ_CMD="gunzip -c $DUMP"
    else
        DB="${BASENAME%.sql}"
        READ_CMD="cat $DUMP"
    fi

    if [ "$DB" = "grants" ]; then
        echo "Restoring users and grants..."
        $READ_CMD | mariadb -u root -p"$DB_PASS"
        echo "  ✓ grants restored"
    else
        echo "Restoring $DB..."
        mariadb -u root -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB\`;"
        $READ_CMD | mariadb -u root -p"$DB_PASS" "$DB"
        echo "  ✓ $DB restored"
    fi
done

echo ""
echo "✓ All databases restored!"
