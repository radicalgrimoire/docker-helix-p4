#!/bin/bash

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

VERSION=$(docker run --rm --entrypoint dpkg-query "$IMAGE_NAME" -W -f='${Version}' helix-auth-svc)

if [ -z "$VERSION" ]; then
    echo "Helix Authentication Service package version was not reported." >&2
    exit 1
fi

echo "Installed Helix Authentication Service package version: $VERSION"
docker run --rm --entrypoint /opt/perforce/helix-auth-svc/bin/node "$IMAGE_NAME" --version
