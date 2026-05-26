FROM mariadb:latest

COPY restore-dbs.sh /docker-entrypoint-initdb.d/restore-dbs.sh
RUN chmod +x /docker-entrypoint-initdb.d/restore-dbs.sh
