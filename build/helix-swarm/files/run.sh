#!/usr/bin/env bash

set -euo pipefail

data_dir=/opt/perforce/swarm/data
config_file="$data_dir/config.php"

if [ -e "$config_file" ] || [ -L "$config_file" ]; then
    if [ ! -f "$config_file" ] || [ ! -r "$config_file" ]; then
        echo "Existing Swarm config.php is not a readable file." >&2
        exit 1
    fi
else
    : "${P4D_PORT:?P4D_PORT is required to initialize Swarm}"
    : "${SWARM_USER:?SWARM_USER is required to initialize Swarm}"
    : "${SWARM_PASSWD:?SWARM_PASSWD is required to initialize Swarm}"

    chown www-data:www-data "$data_dir"
    chmod 751 "$data_dir"
    install -d -o www-data -g swarm-cron -m 750 "$data_dir/queue"
    install -d -o www-data -g swarm-cron -m 750 "$data_dir/queue/tokens"
    existing_token=$(find "$data_dir/queue/tokens" -maxdepth 1 -type f -print -quit)
    if [ -z "$existing_token" ]; then
        token=$(php -r 'echo bin2hex(random_bytes(16));')
        install -o www-data -g www-data -m 600 /dev/null "$data_dir/queue/tokens/$token"
        unset token
    fi
    unset existing_token
    php /usr/local/lib/swarm/init-config.php
    echo "Initialized Swarm configuration."
fi

unset SWARM_PASSWD
rm -f /var/run/apache2/apache2.pid /run/apache2/apache2.pid
/opt/perforce/swarm/sbin/redis-server-swarm /opt/perforce/etc/redis-server.conf --daemonize yes --supervised no
/etc/init.d/cron start

exec apache2ctl -D FOREGROUND
