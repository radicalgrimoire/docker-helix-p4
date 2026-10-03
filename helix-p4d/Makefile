STACK=helixcore
COMPOSE_FILE=docker-compose.yml
CONTAINER=helix-p4d

.PHONY: start stop remove logs shell build rebuild change-password

start:
	docker-compose -f ${COMPOSE_FILE} -p ${STACK} up -d
stop:
	docker-compose -p ${STACK} stop
remove:
	docker-compose -p ${STACK} down
logs:
	docker-compose -p ${STACK} logs -f
shell:
	winpty docker exec -it ${CONTAINER} bash

build:
	docker-compose -f ${COMPOSE_FILE} build
rebuild:
	docker-compose -f ${COMPOSE_FILE} build --no-cache

change-password:
	@docker exec -e OLD_PASS="${OLD_PASS}" -e NEW_PASS="${NEW_PASS}" ${CONTAINER} bash -lc "set -e; if [ -z \"$$OLD_PASS\" ] || [ -z \"$$NEW_PASS\" ]; then echo \"Usage: OLD_PASS=<current-password> NEW_PASS=<new-password> make change-password\" >&2; exit 1; fi; printf '%s\n%s\n%s\n' \"$$OLD_PASS\" \"$$NEW_PASS\" \"$$NEW_PASS\" | sudo -H -E -u perforce p4 passwd; printf 'P4USER=%s\nP4PORT=%s\nP4PASSWD=%s\n' \"$$P4USER\" \"$$P4PORT\" \"$$NEW_PASS\" > /opt/perforce/.p4config; chown perforce:perforce /opt/perforce/.p4config; chmod 600 /opt/perforce/.p4config"
	@echo "Password changed. Update P4PASSWD in your compose/env/secret settings before restarting the container."
