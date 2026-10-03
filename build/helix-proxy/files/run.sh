#!/bin/bash

: "${P4P_CACHE_PURGE_DAYS:=30}"

case "$P4P_CACHE_PURGE_DAYS" in
	''|*[!0-9]*)
		echo "P4P_CACHE_PURGE_DAYS must be a non-negative integer" >&2
		exit 1
		;;
esac

sed -i -e "s/ssl:helix-p4d:1666/${P4PORT}/g" /etc/perforce/p4dctl.conf.d/p4p-master.conf

p4 trust -y -f
yes $P4PASSWD | p4 login
sudo -E -u perforce yes $P4PASSWD | p4 login
cat /root/.p4trust > /opt/perforce/.p4trust
cat /root/.p4tickets > /opt/perforce/.p4tickets

cat > /etc/cron.d/p4p-cache-purge <<EOF
0 3 * * * perforce /usr/sbin/p4p --cache-purge -r ${P4PCACHE} -v proxy.clearcachethresh=${P4P_CACHE_PURGE_DAYS} >> $(dirname "${P4PLOGFILE}")/p4p-cache-purge.log 2>&1
EOF
chmod 0644 /etc/cron.d/p4p-cache-purge

sudo service cron start
sudo -E -u perforce p4dctl start -t p4p p4p-master

exec /usr/bin/tail -f ${P4PLOGFILE}