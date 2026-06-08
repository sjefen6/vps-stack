#!/usr/bin/env bash
# Quick deploy script: build → down → up
# Stack stays running if build fails
set -euo pipefail

echo "=== Pulling external images ==="
# We use --profile "*" so it doesn't ignore services like certbot/backup
docker compose --profile "*" pull --ignore-buildable

if [ "${1:-}" != "--skip-build" ]; then
    echo ""
    echo "=== Building local images ==="
    if ! ./build.sh; then
        echo ""
        echo "✗ Build failed!" >&2
        exit 1
    fi
else
    echo ""
    echo "=== Skipping local build phase ==="
fi

# ── Phase 2: Host Filesystem Setup ───────────────────────────────────
# Prepare directories and permissions before stopping the stack.

echo ""
echo "=== Fixing permissions ==="
sudo chown -R 1000:1000 www/
sudo chmod 600 secrets/*.ini secrets/*.txt 2>/dev/null || true

echo ""
echo "=== Ensuring log directories exist ==="
mkdir -p logs/apache logs/certbot logs/icecast
sudo chown -R 1000:1000 logs/icecast

echo ""
echo "=== Stopping containers ==="
docker compose down

echo ""
echo "=== Starting containers ==="
docker compose up -d

echo ""
echo "=== Deployment complete! ==="
docker compose ps
