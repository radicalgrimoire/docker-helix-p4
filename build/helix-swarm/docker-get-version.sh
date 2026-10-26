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

version_raw=$(docker run --rm "$IMAGE_NAME" dpkg-query -W -f='${Version}' helix-swarm)
version=$(printf '%s\n' "$version_raw" | grep -oE '20[0-9]{2}\.[0-9]+' | head -n 1 || true)

if [ -z "$version" ]; then
    echo "Unable to determine Helix Swarm version from: $version_raw" >&2
    exit 1
fi

echo "raw_version=$version_raw"
echo "version=$version"
