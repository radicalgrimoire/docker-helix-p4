#!/usr/bin/env bash

set -euo pipefail

DOCKERFILE_NAME="${1:-Dockerfile}"
BUILD_PATH="${2:-./build}"
ENV_PATH="$BUILD_PATH/.env"

if [ ! -f "$ENV_PATH" ]; then
    echo "Build configuration not found: $ENV_PATH" >&2
    exit 1
fi

set -a
. "$ENV_PATH"
set +a

: "${IMAGE_NAME:?IMAGE_NAME must be set in $ENV_PATH}"

docker build \
    --build-arg "SWARM_CACHE_BUST=$(date +%s%N)" \
    -t "$IMAGE_NAME" \
    -f "$BUILD_PATH/$DOCKERFILE_NAME" \
    "$BUILD_PATH"
