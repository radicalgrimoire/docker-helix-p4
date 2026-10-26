#!/usr/bin/env bash

set -euo pipefail

if [ ! -r /opt/perforce/swarm/data/config.php ]; then
    echo "Swarm is not configured. Mount an initialized test volume and run the documented upgrade procedure." >&2
    exit 1
fi

rm -f /var/run/apache2/apache2.pid /run/apache2/apache2.pid
/opt/perforce/swarm/sbin/redis-server-swarm --daemonize yes
/etc/init.d/cron start

exec apache2ctl -D FOREGROUND
