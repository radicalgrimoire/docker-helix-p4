FROM ubuntu:noble AS auth-extension

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG HAE_CACHE_BUST
RUN set -eu; \
    REPO="https://github.com/perforce/helix-authentication-extension.git"; \
    HAE_VERSION=$(git ls-remote --tags --refs "$REPO" \
      | sed -nE 's|.*refs/tags/([0-9]{4}\.[0-9]+(\.[0-9]+)?)$|\1|p' \
      | sort -V | tail -n 1); \
    : "${HAE_VERSION:?No release tags found for Helix Authentication Extension}"; \
    echo "Fetching Helix Authentication Extension ${HAE_VERSION}"; \
    git clone --depth 1 --branch "$HAE_VERSION" "$REPO" /opt/helix-authentication-extension; \
    rm -rf /opt/helix-authentication-extension/.git

FROM ubuntu:noble
LABEL org.opencontainers.image.maintainer="ueno.s <ueno.s@gamestudio.co.jp>"

# Add external files
COPY files/run.sh /usr/local/bin/run.sh
COPY files/init.sh /usr/local/bin/init.sh
COPY files/p4.* /etc/logrotate.d/
COPY files/CheckCaseTrigger*.py /usr/local/bin/
COPY files/P4Triggers.py /usr/local/bin/P4Triggers.py
COPY files/admin.txt /opt/perforce/admin.txt
COPY --from=auth-extension /opt/helix-authentication-extension /opt/helix-authentication-extension

ARG P4NAME
ARG P4PORT
ARG P4USER
ARG P4PASSWD
ARG P4HOME
ARG P4ROOT
ARG CASE_INSENSITIVE

ENV P4NAME=$P4NAME \
    P4PORT=$P4PORT \
    P4USER=$P4USER \
    P4PASSWD=$P4PASSWD \
    P4HOME=$P4HOME \
    P4ROOT=$P4ROOT \
    CASE_INSENSITIVE=$CASE_INSENSITIVE \
    P4CONFIG=/opt/perforce/.p4config

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
    && apt-get update \
    && apt-get install -y gnupg language-pack-ja-base language-pack-ja tzdata curl jq openssl cron logrotate sudo \
    && echo 'export LANG=ja_JP.UTF-8' >> ~/.bashrc \
    && echo 'export LANGUAGE="ja_JP:ja"' >> ~/.bashrc \
    && curl -sS https://package.perforce.com/perforce.pubkey | gpg --dearmor -o /usr/share/keyrings/perforce.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] http://package.perforce.com/apt/ubuntu noble release" > /etc/apt/sources.list.d/perforce.list \
    && apt-get update && apt-get install -y helix-p4d python3 perforce-p4python3 \
    && chmod +x /usr/local/bin/init.sh \
    && chmod +x /usr/local/bin/run.sh \
    && chmod 644 /etc/logrotate.d/p4.* \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && bash /usr/local/bin/init.sh

EXPOSE 1666

HEALTHCHECK \
    --interval=2m \
    --timeout=30s \
    CMD p4 -p ssl:1666 info -s > /dev/null || exit 1

CMD ["/usr/local/bin/run.sh"]
