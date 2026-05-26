#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build.sh [service ...]
# Examples: ./build.sh          (builds all)
#           ./build.sh backup   (builds only backup)

DATE_TAG=$(date +%Y%m%d-%H%M)

echo "=== Building images (Tag: latest, $DATE_TAG) ==="
# Use --profile "*" to ensure services with profiles (like backup/certbot) are included
docker compose --profile "*" build --no-cache --parallel "$@"

echo ""
echo "=== Applying datestamp tags ==="

# Use jq to robustly map services to their base image names
# This handles the JSON output of 'docker compose config'
SERVICES_JSON=$(docker compose --profile "*" config --format json)

if [ $# -gt 0 ]; then
    REQUESTED_SERVICES=("$@")
else
    REQUESTED_SERVICES=$(echo "$SERVICES_JSON" | jq -r '.services | keys[]')
fi

for SERVICE in $REQUESTED_SERVICES; do
    IMAGE=$(echo "$SERVICES_JSON" | jq -r ".services[\"$SERVICE\"].image // empty")
    
    if [ -n "$IMAGE" ]; then
        # Remove any existing tag (e.g. vps-db:latest -> vps-db)
        BASE_IMAGE=$(echo "$IMAGE" | cut -d: -f1)
        echo "Tagging $BASE_IMAGE as $BASE_IMAGE:$DATE_TAG..."
        docker tag "$BASE_IMAGE:latest" "$BASE_IMAGE:$DATE_TAG"
    else
        echo "Skipping $SERVICE (no image defined or service not found)"
    fi
done

echo ""
echo "✓ All builds complete and tagged!"

