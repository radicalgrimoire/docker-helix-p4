#!/bin/bash
# update-has-version.sh: Look up the latest Helix Authentication Service tag on GitHub and record it as HAS_VERSION in .env.
# Usage: ./update-has-version.sh [build path]
set -euo pipefail

BUILD_PATH="${1:-$(dirname "$0")}"
ENV_PATH="$BUILD_PATH/.env"
REPO_URL="https://github.com/perforce/helix-authentication-service.git"

if [ ! -f "$ENV_PATH" ]; then
    echo "Build configuration not found: $ENV_PATH" >&2
    exit 1
fi

LATEST=$(git ls-remote --tags --refs "$REPO_URL" \
    | sed 's#.*refs/tags/##' \
    | grep -E '^[0-9]{4}\.[0-9]+(\.[0-9]+)?$' \
    | sort -V \
    | tail -1)

if [ -z "$LATEST" ]; then
    echo "No version tag found in $REPO_URL" >&2
    exit 1
fi

if grep -q '^HAS_VERSION=' "$ENV_PATH"; then
    sed -i "s/^HAS_VERSION=.*/HAS_VERSION=$LATEST/" "$ENV_PATH"
else
    printf 'HAS_VERSION=%s\n' "$LATEST" >> "$ENV_PATH"
fi

echo "HAS_VERSION=$LATEST"
