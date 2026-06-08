#!/usr/bin/env bash
set -euo pipefail

echo "=== Initializing Icecast ==="

# Fail fast if ICECAST_CERT_NAME is not set or empty
if [ -z "${ICECAST_CERT_NAME:-}" ]; then
    echo "ERROR: ICECAST_CERT_NAME environment variable is not defined." >&2
    exit 1
fi

# 1. Combine Let's Encrypt certificates for native SSL
# Icecast requires the full chain and private key in a single .pem file
CERT_DIR="/etc/letsencrypt/live/${ICECAST_CERT_NAME}"
ICECAST_CERT="/usr/share/icecast/icecast.pem"

if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
    echo "Combining Let's Encrypt SSL certificates into $ICECAST_CERT..."
    cat "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem" > "$ICECAST_CERT"
    chown icecast:icecast "$ICECAST_CERT"
    chmod 600 "$ICECAST_CERT"
else
    echo "ERROR: Let's Encrypt certificates not found at $CERT_DIR!" >&2
    exit 1
fi

echo "=== Starting Icecast ==="
# Launch Icecast in foreground
exec icecast -c /etc/icecast.xml
