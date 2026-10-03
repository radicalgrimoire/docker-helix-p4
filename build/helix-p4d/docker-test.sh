#!/bin/bash
# docker-test.sh: Run the Helix Core image integration test.
# Usage: ./docker-test.sh [build path]
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

CONTAINER_NAME="${IMAGE_NAME}-test-$$"

cleanup() {
    docker logs "$CONTAINER_NAME" >&2 || true
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
}

trap cleanup EXIT

echo "Starting test container: $CONTAINER_NAME"
docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME" > /dev/null

for attempt in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" p4 info > /dev/null 2>&1; then
        break
    fi

    if [ "$attempt" -eq 30 ]; then
        echo "P4D did not become ready within 30 seconds." >&2
        exit 1
    fi

    sleep 1
done

echo "Logging in as $P4USER"
docker exec "$CONTAINER_NAME" sh -c 'p4 logout > /dev/null 2>&1 || true; printf "%s\n" "$P4PASSWD" | p4 login'

echo "Checking P4D server information"
docker exec "$CONTAINER_NAME" p4 info