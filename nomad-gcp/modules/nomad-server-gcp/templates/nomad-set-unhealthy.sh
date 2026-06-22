#!/bin/bash
set -euo pipefail
INSTANCE_NAME=$1

METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
METADATA_HEADER="Metadata-Flavor: Google"

meta_get() {
    curl -sf -H "$METADATA_HEADER" "$METADATA_URL/$1"
}

PROJECT=$(meta_get "project/project-id")
ZONE=$(meta_get "instance/zone" | awk -F/ '{print $NF}')
TOKEN=$(meta_get "instance/service-accounts/default/token" | jq -r '.access_token')

CREATED_BY=$(meta_get "instance/attributes/created-by") || { echo "Failed to get created-by attribute" >&2; exit 1; }
MIG_NAME=$(echo "$CREATED_BY" | awk -F/ '{print $NF}')

if [ -z "$MIG_NAME" ]; then
    echo "Could not determine MIG name for instance $INSTANCE_NAME" >&2
    exit 1
fi

INSTANCE_URL="https://www.googleapis.com/compute/v1/projects/$PROJECT/zones/$ZONE/instances/$INSTANCE_NAME"

curl -sf --max-time 10 -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "https://compute.googleapis.com/compute/v1/projects/$PROJECT/zones/$ZONE/instanceGroupManagers/$MIG_NAME/recreateInstances" \
    -d "{\"instances\": [\"$INSTANCE_URL\"]}"
