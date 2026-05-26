#!/usr/bin/env bash
# Export MySQL databases and their users to individual .sql.gz files
# Run on the old server, then scp the output directory down
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 ROOT_PASSWORD" >&2
    exit 1
fi

DB_PASS="$1"

OUTPUT_DIR="$HOME/db-export-$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# Databases to skip — system DBs and ones managed separately
EXCLUDE_DBS="'information_schema','performance_schema','mysql','sys','phpmyadmin'"

# Users to skip — system/maintenance users created by MariaDB/Debian automatically
EXCLUDE_USERS="'root','mysql.sys','mysql.session','mysql.infoschema','debian-sys-maint','healthcheck','mariadb.sys','phpmyadmin'"

echo "=== Exporting databases to $OUTPUT_DIR ==="
echo ""

DATABASES=$(mysql -u root -p"$DB_PASS" -N -e \
  "SHOW DATABASES WHERE \`Database\` NOT IN ($EXCLUDE_DBS);")

for DB in $DATABASES; do
    echo "Exporting $DB..."
    mysqldump -u root -p"$DB_PASS" \
        --single-transaction \
        --routines \
        --triggers \
        "$DB" | gzip > "$OUTPUT_DIR/$DB.sql.gz"
done

echo "Exporting users and grants..."
DB_LIST=$(echo "$DATABASES" | tr ' \n' '|' | sed 's/|$//')
mysql -u root -p"$DB_PASS" -N -e \
    "SELECT DISTINCT CONCAT('SHOW GRANTS FOR \'',user,'\'@\'',host,'\';')
     FROM mysql.db
     WHERE db REGEXP '^($DB_LIST)$'
     AND user NOT IN ($EXCLUDE_USERS)" \
  | mysql -u root -p"$DB_PASS" -N \
  | sed "s/$/;/" \
  | sed "s/@\`localhost\`/@\`%\`/g" \
  | sed "s/@'localhost'/@'%'/g" \
  | gzip > "$OUTPUT_DIR/grants.sql.gz"

echo ""
echo "✓ Done! Files in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "Download with:"
echo "  scp -r oldserver:$OUTPUT_DIR ./db-export"
