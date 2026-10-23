ARG UBUNTU_IMAGE=ubuntu:noble

# Node.js from the official nodejs.org distribution, checksum-verified
FROM ${UBUNTU_IMAGE} AS node
ARG NODE_MAJOR=24
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) NODE_ARCH=x64 ;; \
      arm64) NODE_ARCH=arm64 ;; \
      *) echo "Unsupported architecture" >&2; exit 1 ;; \
    esac; \
    BASE="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x"; \
    curl -fsSLO "$BASE/SHASUMS256.txt"; \
    FILE=$(grep -oE "node-v[0-9.]+-linux-${NODE_ARCH}\.tar\.xz" SHASUMS256.txt | head -1); \
    curl -fsSLO "$BASE/$FILE"; \
    grep " $FILE\$" SHASUMS256.txt | sha256sum -c -; \
    mkdir -p /opt/node; \
    tar -xJf "$FILE" -C /opt/node --strip-components=1 --exclude='*/include' --exclude='*/share'; \
    /opt/node/bin/node --version

FROM ${UBUNTU_IMAGE} AS build
# Empty means "use the latest release tag"; set it to pin a version
ARG HAS_VERSION=
COPY --from=node /opt/node /usr/local
# Build tools are only needed to compile native modules; they are not copied to the final image
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl git python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/perforce/helix-auth-svc
RUN set -eux; \
    REPO="https://github.com/perforce/helix-authentication-service"; \
    if [ -z "${HAS_VERSION}" ]; then \
      HAS_VERSION=$(git ls-remote --tags --refs "$REPO" \
        | sed 's|.*refs/tags/||' | grep -E '^[0-9]{4}\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -1); \
    fi; \
    echo "Building HAS ${HAS_VERSION}"; \
    curl -fsSL "$REPO/archive/refs/tags/${HAS_VERSION}.tar.gz" | tar -xz --strip-components=1

# Admin web UI (same steps as the official containers/hub/Dockerfile)
RUN cd client \
    && npm ci --no-audit --no-fund \
    && npx vite build --outDir ../private/admin --emptyOutDir

RUN npm ci --omit=dev --omit=optional --no-audit --no-fund \
    && npm cache clean --force

FROM ${UBUNTU_IMAGE}

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node /opt/node/bin/node /usr/local/bin/node

WORKDIR /opt/perforce/helix-auth-svc
# Only what the service needs at runtime (mirrors the official image)
COPY --from=build /opt/perforce/helix-auth-svc/bin bin
COPY --from=build /opt/perforce/helix-auth-svc/certs certs
COPY --from=build /opt/perforce/helix-auth-svc/defaults.env defaults.env
COPY --from=build /opt/perforce/helix-auth-svc/lib lib
COPY --from=build /opt/perforce/helix-auth-svc/package.json /opt/perforce/helix-auth-svc/package-lock.json ./
COPY --from=build /opt/perforce/helix-auth-svc/private private
COPY --from=build /opt/perforce/helix-auth-svc/public public
COPY --from=build /opt/perforce/helix-auth-svc/routes routes
COPY --from=build /opt/perforce/helix-auth-svc/views views
COPY --from=build /opt/perforce/helix-auth-svc/node_modules node_modules

# Same defaults as the official image
ENV NODE_ENV=production \
    CA_CERT_FILE=certs/ca.crt \
    PORT=3000 \
    PROTOCOL=http
USER ubuntu
EXPOSE 3000

HEALTHCHECK CMD curl --insecure --fail --silent --head ${PROTOCOL}://localhost:${PORT}/ || exit 1

ENTRYPOINT ["node", "bin/www.js"]
