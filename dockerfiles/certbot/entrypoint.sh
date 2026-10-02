#!/bin/bash
set -euo pipefail


# Install the bundled hook into the mounted certificate directory at startup.
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cp /usr/local/libexec/reload-containers.sh /etc/letsencrypt/renewal-hooks/deploy/reload-containers.sh
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-containers.sh

# Write crontab and start scheduler
echo "${CERTBOT_RENEW_SCHEDULE} certbot renew >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

echo "Certbot renewal schedule: $CERTBOT_RENEW_SCHEDULE"
exec crond -f -d 8
