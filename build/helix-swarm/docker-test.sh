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
    test -e /etc/apache2/sites-enabled/perforce-swarm-site.conf
    test ! -e /etc/apache2/sites-enabled/000-default.conf
    apache2ctl configtest
    php_package_version=$(dpkg-query -W -f="\${Version}" libapache2-mod-php8.3)
    dpkg --compare-versions "$php_package_version" ge 8.3.6-0ubuntu0.24.04.13
    php --version
'

container_id=""
cleanup() {
    if [ -n "$container_id" ]; then
        docker rm -f "$container_id" >/dev/null
    fi
}
trap cleanup EXIT

container_id=$(docker run -d --entrypoint /bin/bash "$IMAGE_NAME" -ec '
    mkdir -p /opt/perforce/swarm/data
    printf "%s\n" "<?php return [];" > /opt/perforce/swarm/data/config.php
    printf "%s\n" "swarm-document-root" > /opt/perforce/swarm/public/image-test.txt
    exec /usr/local/bin/run-swarm.sh
')

for attempt in $(seq 1 30); do
    if docker exec "$container_id" curl -fsS http://127.0.0.1/image-test.txt 2>/dev/null \
        | grep -Fxq 'swarm-document-root'; then
        echo "Apache serves the Swarm document root."
        exit 0
    fi
    sleep 1
done

echo "Apache did not serve the Swarm document root." >&2
docker logs "$container_id" >&2
exit 1
