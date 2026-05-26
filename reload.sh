#!/usr/bin/env bash
# Quick reload Apache configuration without rebuilding
set -euo pipefail

echo "=== Testing Apache configuration ==="
if docker exec vps-apache-php apachectl configtest; then
    echo ""
    echo "✓ Configuration OK"
    echo ""
    echo "=== Reloading Apache ==="
    docker exec vps-apache-php apachectl graceful
    echo "✓ Apache reloaded!"
else
    echo ""
    echo "✗ Configuration test failed! Not reloading." >&2
    exit 1
fi
