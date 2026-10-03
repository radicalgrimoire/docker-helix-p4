#!/bin/bash
set -euo pipefail

: "${P4CONFIG:?P4CONFIG is not set}"

if ! p4dctl list 2>/dev/null | grep -Fqx -- "$P4NAME"; then

run_p4_as_perforce() {
	sudo -H -E -u perforce "$@"
}

/opt/perforce/sbin/configure-helix-p4d.sh "${P4NAME}" -n -p "${P4PORT}" -r "${P4ROOT}" -u "${P4USER}" -P "${P4PASSWD}" --case "${CASE_INSENSITIVE}" --unicode
echo bash /opt/perforce/sbin/configure-helix-p4d.sh "${P4NAME}" -n -p "${P4PORT}" -r "${P4ROOT}" -u "${P4USER}" -P "****" --case "${CASE_INSENSITIVE}" --unicode
run_p4_as_perforce p4 trust -y -f

cat > "${P4CONFIG}" <<EOF
P4USER=$P4USER
P4PORT=$P4PORT
P4PASSWD=$P4PASSWD
EOF

chmod 0600 "${P4CONFIG}"
chown perforce:perforce "${P4CONFIG}"

run_p4_as_perforce p4 login <<EOF
$P4PASSWD
EOF

run_p4_as_perforce p4 configure set server.extensions.allow.unsigned=1
run_p4_as_perforce p4 configure set net.keepalive.idle=10
run_p4_as_perforce p4 configure set net.keepalive.interval=30
run_p4_as_perforce p4 configure set net.keepalive.count=3

TRIGGERS_FILE="$(mktemp)"
run_p4_as_perforce p4 triggers -o > "${TRIGGERS_FILE}"
echo '   CheckCaseTrigger change-submit //... "python3 /usr/local/bin/CheckCaseTrigger3.py %changelist% port=ssl:1666 user=super"' >> "${TRIGGERS_FILE}"
run_p4_as_perforce p4 triggers -i < "${TRIGGERS_FILE}"
rm -f "${TRIGGERS_FILE}"

if [ -f /opt/perforce/.p4trust ]; then
	chown perforce:perforce /opt/perforce/.p4trust || true
	chmod 600 /opt/perforce/.p4trust || true
fi

if [ -f /opt/perforce/.p4tickets ]; then
	chown perforce:perforce /opt/perforce/.p4tickets || true
	chmod 600 /opt/perforce/.p4tickets || true
fi

run_p4_as_perforce p4 -p "${P4PORT}" group -i < /opt/perforce/admin.txt
rm -f /opt/perforce/admin.txt

exit

fi
