#!/usr/bin/env bash
# Quick deploy script: build → down → up
# Stack stays running if build fails
set -euo pipefail

echo "=== Building images ==="
if ! ./build.sh; then
    echo ""
    echo "✗ Build failed! Stack remains running." >&2
    exit 1
fi

echo ""
echo "=== Pulling base images ==="
docker compose pull --ignore-buildable

echo ""
echo "✓ Build successful, deploying..."

echo ""
echo "=== Fixing permissions ==="
sudo chown -R 1000:1000 www/
sudo chmod 600 secrets/*.ini secrets/*.txt 2>/dev/null || true

echo ""
echo "=== Ensuring log directories exist ==="
mkdir -p logs/apache logs/certbot

echo ""
echo "=== Stopping containers ==="
docker compose down

echo ""
echo "=== Starting containers ==="
docker compose up -d

echo ""
echo "=== Deployment complete! ==="
docker compose ps
