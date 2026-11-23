# Keep release-series upgrades deliberate while still receiving patch updates.
# Do not downgrade an existing data volume when changing this pin.
FROM mariadb:13.0

COPY restore-dbs.sh /docker-entrypoint-initdb.d/restore-dbs.sh
RUN chmod +x /docker-entrypoint-initdb.d/restore-dbs.sh
