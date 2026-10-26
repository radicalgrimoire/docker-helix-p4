FROM ubuntu:noble

LABEL org.opencontainers.image.maintainer="ueno.s <ueno.s@gamestudio.co.jp>"

ARG SWARM_CACHE_BUST

COPY files/run.sh /usr/local/bin/run-swarm.sh

RUN set -eux; \
    echo "Refreshing Swarm packages: ${SWARM_CACHE_BUST}"; \
    ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install --no-install-recommends -y ca-certificates curl gnupg tzdata; \
    curl -fsSL https://package.perforce.com/perforce.pubkey \
      | gpg --dearmor -o /usr/share/keyrings/perforce.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] https://package.perforce.com/apt/ubuntu noble release" \
      > /etc/apt/sources.list.d/perforce.list; \
    apt-get update; \
    apt-get install --no-install-recommends -y helix-swarm; \
    php_version=$(dpkg-query -W -f='${Version}' libapache2-mod-php8.3); \
    dpkg --compare-versions "$php_version" ge 8.3.6-0ubuntu0.24.04.13; \
    echo "Installed Helix Swarm: $(dpkg-query -W -f='${Version}' helix-swarm)"; \
    echo "Installed Apache PHP: $php_version"; \
    php --version; \
    chmod 0755 /usr/local/bin/run-swarm.sh; \
    rm -rf /var/lib/apt/lists/*

EXPOSE 80 443

CMD ["/usr/local/bin/run-swarm.sh"]
