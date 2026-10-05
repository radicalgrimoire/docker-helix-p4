#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="${CONTAINER_NAME:-helix-proxy}"
CONTAINER_PATH="${CONTAINER_PATH:-/opt/perforce/preload-proxy-cache.sh}"
SOURCE_PATH="$SCRIPT_DIR/preload-proxy-cache.sh"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker must be installed on the host." >&2
    exit 1
fi

if [[ "$(docker container inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)" != "true" ]]; then
    echo "Container '$CONTAINER_NAME' is not running or does not exist." >&2
    exit 1
fi

docker cp "$SOURCE_PATH" "${CONTAINER_NAME}:${CONTAINER_PATH}"
docker exec "$CONTAINER_NAME" chmod 0755 "$CONTAINER_PATH"

echo "Copied preload script to ${CONTAINER_NAME}:${CONTAINER_PATH}"