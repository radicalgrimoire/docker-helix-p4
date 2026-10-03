#!/usr/bin/env bash

set -euo pipefail

BUILD_PATH="${1:-./build}"
ENV_PATH="$BUILD_PATH/.env"

if [ ! -f "$ENV_PATH" ]; then
    echo "Build configuration not found: $ENV_PATH" >&2
    exit 1
fi

set -a
. "$ENV_PATH"
set +a

: "${IMAGE_NAME:?IMAGE_NAME must be set in $ENV_PATH}"

echo "Testing image: $IMAGE_NAME"
docker run --rm "$IMAGE_NAME" p4p -V