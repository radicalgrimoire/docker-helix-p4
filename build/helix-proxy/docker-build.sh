#!/bin/bash
# docker-build.sh: Load build values from .env and pass them to docker build.
# Usage: ./docker-build.sh [Dockerfile name] [build path]
set -e

DOCKERFILE_NAME="${1:-Dockerfile}"
BUILD_PATH="${2:-./build}"
IMAGE_NAME=""
BUILD_ARGS=""

ENV_PATH="$BUILD_PATH/.env"
if [ ! -f "$ENV_PATH" ]; then
    echo "Build configuration not found: $ENV_PATH" >&2
    exit 1
fi

while IFS='=' read -r key value || [ -n "$key" ]; do
    key=$(echo "$key" | sed 's/^\s*//;s/\s*$//;s/^export //')
    if [[ "$key" =~ ^# ]] || [[ -z "$key" ]]; then continue; fi

    value=$(echo "$value" | sed 's/^\s*//;s/\s*$//')
    if [ "$key" = "IMAGE_NAME" ]; then
        IMAGE_NAME="$value"
    else
        BUILD_ARGS+=" --build-arg $key=$value"
    fi
done < "$ENV_PATH"

: "${IMAGE_NAME:?IMAGE_NAME must be set in $ENV_PATH}"

docker build -t "$IMAGE_NAME" $BUILD_ARGS -f "$BUILD_PATH/$DOCKERFILE_NAME" "$BUILD_PATH"