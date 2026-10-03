#!/bin/bash
set -e

: "${P4CONFIG:?P4CONFIG is not set}"

run_p4_as_perforce() {
	sudo -H -E -u perforce "$@"
}

write_p4config() {
	local password="$1"
	[ -n "$password" ] || return 1

	cat > "${P4CONFIG}" <<EOF
P4USER=${P4USER}
P4PORT=${P4PORT}
P4PASSWD=${password}
EOF
	chown perforce:perforce "${P4CONFIG}" || true
	chmod 600 "${P4CONFIG}" || true
}

p4dctl start -t p4d "${P4NAME}"
sudo service cron start
run_p4_as_perforce p4 trust -y -f

login_with_password() {
	local password="$1"
	[ -n "$password" ] || return 1

	run_p4_as_perforce p4 logout > /dev/null 2>&1 || true

	if ! printf '%s\n' "$password" | run_p4_as_perforce p4 login > /dev/null 2>&1; then
		return 1
	fi

	return 0
}

CURRENT_PASSWORD=""
if login_with_password "${P4PASSWD}"; then
	CURRENT_PASSWORD="${P4PASSWD}"
fi

if [ -z "${CURRENT_PASSWORD}" ]; then
	echo "This appears to be an existing environment, so startup will continue even though super login failed." >&2
fi

if [ -n "${CURRENT_PASSWORD}" ]; then
	write_p4config "${CURRENT_PASSWORD}"
fi

if [ -f /opt/perforce/.p4trust ]; then
	chown perforce:perforce /opt/perforce/.p4trust || true
	chmod 600 /opt/perforce/.p4trust || true
fi

if [ -f /opt/perforce/.p4tickets ]; then
	chown perforce:perforce /opt/perforce/.p4tickets || true
	chmod 600 /opt/perforce/.p4tickets || true
fi

exec /usr/bin/tail --pid="$(cat "/var/run/p4d.${P4NAME}.pid")" -F "${P4ROOT}/logs/log"