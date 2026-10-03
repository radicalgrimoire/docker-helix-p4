FROM ubuntu:noble
LABEL org.opencontainers.image.maintainer="ueno.s <ueno.s@gamestudio.co.jp>"

COPY files/run.sh /usr/local/bin/run.sh
COPY files/p4p /etc/logrotate.d/p4p
COPY files/p4p-master.conf /etc/perforce/p4dctl.conf.d/p4p-master.conf

ARG USER
ARG PASSWD
ARG P4HOME
ARG P4PLOGDIR

ENV LANG="ja_JP.UTF-8" \
    LANGUAGE="ja_JP:ja" \
    LC_ALL="ja_JP.UTF-8" \
    P4PCACHE=${P4HOME}/p4p-master \
    P4SSLDIR=${P4HOME}/ssl \
    P4PLOGFILE=${P4PLOGDIR}/p4p.log \
    P4P_CACHE_PURGE_DAYS=30

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
    && apt-get update \
    && apt-get install -y gnupg less language-pack-ja-base language-pack-ja tzdata curl jq git openssl sudo vim unzip cron logrotate \
    && echo 'export LANG=ja_JP.UTF-8' >> ~/.bashrc \
    && echo 'export LANGUAGE="ja_JP:ja"' >> ~/.bashrc \
    && curl -sS https://package.perforce.com/perforce.pubkey | gpg --dearmor -o /usr/share/keyrings/perforce.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] http://package.perforce.com/apt/ubuntu noble release" > /etc/apt/sources.list.d/perforce.list \
    && apt-get update \
    && apt-get install -y helix-p4d helix-proxy \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "$USER:$PASSWD" | chpasswd \
    && echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && chmod +x /usr/local/bin/run.sh \
    && sudo -E -u perforce mkdir -p ${P4PCACHE} ${P4SSLDIR} ${P4PLOGDIR} \
    && sudo -E -u perforce chmod 700 ${P4SSLDIR} \
    && chmod 644 /etc/logrotate.d/p4p \
    && sudo -E -u perforce p4d -Gc \
    && sudo -E -u perforce p4d -Gf \
    && echo ' ' > ${P4PLOGFILE} \
    && chown perforce:perforce ${P4PLOGFILE}

EXPOSE 1777

HEALTHCHECK --interval=2m --timeout=30s CMD p4 -p ssl:1777 info -s > /dev/null || exit 1

CMD ["/usr/local/bin/run.sh"]