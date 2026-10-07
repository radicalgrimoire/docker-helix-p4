FROM ubuntu:noble

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl gnupg \
    && curl -sS https://package.perforce.com/perforce.pubkey | gpg --dearmor -o /usr/share/keyrings/perforce.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] http://package.perforce.com/apt/ubuntu noble release" > /etc/apt/sources.list.d/perforce.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y helix-auth-svc \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 3000

CMD ["/opt/perforce/helix-auth-svc/bin/node", "/opt/perforce/helix-auth-svc/bin/www.js"]
