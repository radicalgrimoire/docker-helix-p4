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
redis_volume=""
cleanup() {
    if [ -n "$container_id" ]; then
        docker rm -f "$container_id" >/dev/null
    fi
    if [ -n "$redis_volume" ]; then
        docker volume rm "$redis_volume" >/dev/null
    fi
}
trap cleanup EXIT

redis_volume=$(docker volume create)
start_container() {
    container_id=$(docker run -d --mount "type=volume,source=$redis_volume,target=/opt/perforce/swarm/redis" \
        --entrypoint /bin/bash "$IMAGE_NAME" -ec '
        mkdir -p /opt/perforce/swarm/data
        printf "%s\n" "<?php return [];" > /opt/perforce/swarm/data/config.php
        printf "%s\n" "swarm-document-root" > /opt/perforce/swarm/public/image-test.txt
        exec /usr/local/bin/run-swarm.sh
    ')
}

wait_for_services() {
    for attempt in $(seq 1 30); do
        if docker exec "$container_id" curl -fsS http://127.0.0.1/image-test.txt 2>/dev/null \
            | grep -Fxq 'swarm-document-root' \
            && docker exec "$container_id" /opt/perforce/swarm/sbin/redis-cli-swarm \
                -h 127.0.0.1 -p 7379 ping 2>/dev/null | grep -Fxq 'PONG'; then
            return 0
        fi
        sleep 1
    done
    echo "Apache or the Swarm Redis service did not start." >&2
    docker logs "$container_id" >&2
    return 1
}

start_container
wait_for_services
echo "Apache serves the Swarm document root and Redis listens on port 7379."
docker exec "$container_id" /opt/perforce/swarm/sbin/redis-cli-swarm \
    -h 127.0.0.1 -p 7379 set image-test-key image-test-value | grep -Fxq 'OK'
sleep 2
docker rm -f "$container_id" >/dev/null
container_id=""
start_container
wait_for_services
docker exec "$container_id" /opt/perforce/swarm/sbin/redis-cli-swarm \
    -h 127.0.0.1 -p 7379 get image-test-key | grep -Fxq 'image-test-value'
echo "Redis data survives container recreation."
