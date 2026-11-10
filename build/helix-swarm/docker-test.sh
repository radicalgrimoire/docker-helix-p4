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
data_volume=""
cleanup() {
    if [ -n "$container_id" ]; then
        docker rm -f "$container_id" >/dev/null
    fi
    if [ -n "$redis_volume" ]; then
        docker volume rm "$redis_volume" >/dev/null
    fi
    if [ -n "$data_volume" ]; then
        docker volume rm "$data_volume" >/dev/null
    fi
}
trap cleanup EXIT

expect_missing() {
    local setting=$1
    shift
    local missing_output
    if missing_output=$(docker run --rm "$@" "$IMAGE_NAME" 2>&1); then
        echo "Swarm unexpectedly started without $setting." >&2
        exit 1
    fi
    if ! printf '%s\n' "$missing_output" | grep -Fq "$setting is required"; then
        printf '%s\n' "$missing_output" >&2
        echo "Swarm did not report missing $setting." >&2
        exit 1
    fi
}

expect_missing P4D_PORT
expect_missing SWARM_USER -e P4D_PORT=p4.example:1666
expect_missing SWARM_PASSWD -e P4D_PORT=p4.example:1666 -e SWARM_USER=swarm

redis_volume=$(docker volume create)
data_volume=$(docker volume create)
expected_password="test'\\password\$special"
start_container() {
    container_id=$(docker run -d \
        --mount "type=volume,source=$redis_volume,target=/opt/perforce/swarm/redis" \
        --mount "type=volume,source=$data_volume,target=/opt/perforce/swarm/data" \
        -e "P4D_PORT=$1" -e "SWARM_USER=$2" -e "SWARM_PASSWD=$3" -e "SWARM_HOST=$4" \
        --entrypoint /bin/bash "$IMAGE_NAME" -ec '
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

verify_initial_config() {
    docker exec -e "EXPECTED_PASSWORD=$expected_password" "$container_id" php -r '
        $config = require "/opt/perforce/swarm/data/config.php";
        if ($config["p4"]["port"] !== "p4.example:1666" ||
            $config["p4"]["user"] !== "first-swarm" ||
            $config["p4"]["password"] !== getenv("EXPECTED_PASSWORD") ||
            $config["environment"]["hostname"] !== "swarm.example") {
            exit(1);
        }
    '
    docker exec "$container_id" /bin/bash -ec '
        test "$(stat -c "%U:%G:%a" /opt/perforce/swarm/data/config.php)" = "www-data:www-data:600"
        runuser -u www-data -- test -r /opt/perforce/swarm/data/config.php
        if runuser -u swarm-cron -- test -r /opt/perforce/swarm/data/config.php; then
            echo "Swarm config.php is readable by swarm-cron." >&2
            exit 1
        fi
        runuser -u swarm-cron -- find /opt/perforce/swarm/data/queue/tokens -maxdepth 1 -type f | grep -q .
    '
}

start_container 'p4.example:1666' 'first-swarm' "$expected_password" 'swarm.example'
wait_for_services
echo "Apache serves the Swarm document root and Redis listens on port 7379."
verify_initial_config
if docker logs "$container_id" 2>&1 | grep -Fq "$expected_password"; then
    echo "Swarm initialization logged the password." >&2
    exit 1
fi
docker exec "$container_id" /opt/perforce/swarm/sbin/redis-cli-swarm \
    -h 127.0.0.1 -p 7379 set image-test-key image-test-value | grep -Fxq 'OK'
sleep 2
docker rm -f "$container_id" >/dev/null
container_id=""
start_container 'other.example:1666' 'other-swarm' 'other-password' 'other.example'
wait_for_services
verify_initial_config
docker exec "$container_id" /opt/perforce/swarm/sbin/redis-cli-swarm \
    -h 127.0.0.1 -p 7379 get image-test-key | grep -Fxq 'image-test-value'
echo "Redis data survives container recreation."
echo "Initial configuration is preserved on container recreation."

docker rm -f "$container_id" >/dev/null
container_id=""
start_container '' '' '' ''
wait_for_services
verify_initial_config
echo "Existing configuration starts without initialization variables."
