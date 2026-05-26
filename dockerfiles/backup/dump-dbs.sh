#!/usr/bin/env bash
# Dump all user databases and grants to .sql files
# Runs inside the backup container, connects to mariadb via Docker network
set -euo pipefail

DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-$(cat /vps-stack/secrets/db-root-password.txt 2>/dev/null)}"
OUTPUT_DIR="${1:-/tmp/db-dumps}"

if [[ -z "$DB_PASS" ]]; then
    echo "ERROR: DB_PASS not set and /secrets/db_root_password not found" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

MYSQL="mariadb -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS"
MYSQLDUMP="mariadb-dump -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS"

# Databases to skip — system DBs
EXCLUDE_DBS="'information_schema','performance_schema','mysql','sys','phpmyadmin'"

# Users to skip — system/maintenance users
EXCLUDE_USERS="'root','mysql.sys','mysql.session','mysql.infoschema','debian-sys-maint','healthcheck','mariadb.sys','phpmyadmin'"

echo "=== Dumping databases to $OUTPUT_DIR ==="

DATABASES=$($MYSQL -N -e "SHOW DATABASES WHERE \`Database\` NOT IN ($EXCLUDE_DBS);")

if [[ -z "$DATABASES" ]]; then
    echo "ERROR: No databases found or connection failed" >&2
    exit 1
fi

for DB in $DATABASES; do
    echo "  Dumping $DB..."
    $MYSQLDUMP \
        --single-transaction \
        --routines \
        --triggers \
        --databases \
        "$DB" > "$OUTPUT_DIR/$DB.sql"
done

echo "  Dumping grants..."
DB_LIST=$(echo "$DATABASES" | tr ' \n' '|' | sed 's/|$//')
$MYSQL -N -e \
    "SELECT DISTINCT CONCAT('SHOW GRANTS FOR \'',user,'\'@\'',host,'\';')
     FROM mysql.db
     WHERE db REGEXP '^($DB_LIST)$'
     AND user NOT IN ($EXCLUDE_USERS)" \
  | $MYSQL -N \
  | sed "s/$/;/" \
  | sed "s/@\`localhost\`/@\`%\`/g" \
  | sed "s/@'localhost'/@'%'/g" \
  > "$OUTPUT_DIR/grants.sql"

echo "=== Dump complete ==="
ls -lh "$OUTPUT_DIR"
