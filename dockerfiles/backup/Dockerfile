FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    restic \
    mariadb-client \
    msmtp \
    ca-certificates \
    tzdata

COPY dump-dbs.sh   /usr/local/bin/dump-dbs.sh
COPY backup.sh     /usr/local/bin/backup.sh
COPY restore.sh    /usr/local/bin/restore.sh
COPY notify.sh     /usr/local/bin/notify.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x \
    /usr/local/bin/dump-dbs.sh \
    /usr/local/bin/backup.sh \
    /usr/local/bin/restore.sh \
    /usr/local/bin/notify.sh \
    /entrypoint.sh

ENV TZ="Europe/Oslo"
ENV BACKUP_SCHEDULE="0 2 * * *"

ENTRYPOINT ["/entrypoint.sh"]
