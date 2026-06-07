#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build.sh
# Builds all services and tags them with datestamp.

DATE_TAG=$(date +%Y%m%d-%H%M)

echo "=== Building images (Tag: latest, $DATE_TAG) ==="
# Pass monthly CACHE_BYPASS token to automatically invalidate cached installs once a month.
# Use --profile "*" to ensure services with profiles (like backup/certbot) are included.
docker compose --profile "*" build --build-arg CACHE_BYPASS="$(date +%Y%m)" --parallel

echo ""
echo "=== Applying datestamp tags ==="

# Use jq to robustly map services to their base image names
# This handles the JSON output of 'docker compose config'
SERVICES_JSON=$(docker compose --profile "*" config --format json)
SERVICES=$(echo "$SERVICES_JSON" | jq -r '.services | keys[]')

for SERVICE in $SERVICES; do
    IMAGE=$(echo "$SERVICES_JSON" | jq -r ".services[\"$SERVICE\"].image // empty")
    
    if [ -n "$IMAGE" ]; then
        BASE_IMAGE=$(echo "$IMAGE" | cut -d: -f1)
        echo "Tagging $BASE_IMAGE as $BASE_IMAGE:$DATE_TAG..."
        docker tag "$BASE_IMAGE:latest" "$BASE_IMAGE:$DATE_TAG"
    fi
done

echo ""
echo "✓ All builds complete and tagged!"
