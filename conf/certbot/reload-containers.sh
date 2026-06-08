#!/bin/sh
# This script is executed by Certbot upon successful certificate renewal.

echo "Certificate renewed for: $RENEWED_DOMAINS"

# Always gracefully reload Apache for any certificate renewal
docker exec vps-apache-php apachectl graceful

# Fail fast if ICECAST_CERT_NAME is not defined or empty
if [ -z "${ICECAST_CERT_NAME:-}" ]; then
    echo "ERROR: ICECAST_CERT_NAME environment variable is not defined." >&2
    exit 1
fi

# Only hard-restart Icecast if the stream certificate was the one that renewed
# Certbot passes the renewed domains in the $RENEWED_DOMAINS environment variable
TARGET_CERT="${ICECAST_CERT_NAME}"
case "$RENEWED_DOMAINS" in
    *"$TARGET_CERT"*)
        echo "Stream certificate ($TARGET_CERT) renewed. Restarting Icecast..."
        docker restart vps-icecast
        ;;
    *)
        echo "Icecast does not use this certificate. Skipping Icecast restart."
        ;;
esac
