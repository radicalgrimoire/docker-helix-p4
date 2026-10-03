#!/bin/bash
# docker-get-version.sh: Get version values from the built Helix Core image.
# Usage: ./docker-get-version.sh [build path]
set -e

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

VERSION_OUTPUT=$(docker run --rm "$IMAGE_NAME" p4d -V)
printf '%s\n' '--- p4d -V output ---' >&2
printf '%s\n' "$VERSION_OUTPUT" >&2

VERSION_RAW=$(printf '%s\n' "$VERSION_OUTPUT" | grep '^Rev\.' || true)
VERSION=$(printf '%s\n' "$VERSION_RAW" | grep -oE '[0-9]{4}\.[0-9]+' | head -1 || true)

: "${VERSION_RAW:=unknown}"
: "${VERSION:=unknown}"

printf 'raw_version=%s\n' "$VERSION_RAW"
printf 'version=%s\n' "$VERSION"