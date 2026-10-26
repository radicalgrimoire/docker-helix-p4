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

docker run --rm --entrypoint /bin/sh "$IMAGE_NAME" -ec '
    dpkg-query -W helix-swarm
    test -x /opt/perforce/swarm/sbin/configure-swarm.sh
    php_package_version=$(dpkg-query -W -f="\${Version}" libapache2-mod-php8.3)
    dpkg --compare-versions "$php_package_version" ge 8.3.6-0ubuntu0.24.04.13
    php --version
'
