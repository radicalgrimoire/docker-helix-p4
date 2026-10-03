# Helix Proxy (P4P)

This service is part of the Docker Helix P4 repository. The published image is available from GitHub Container Registry at `ghcr.io/radicalgrimoire/docker-helix-p4/helix-proxy:latest`.

# How to use

## Configure the Service

```
    environment:
      P4PORT: ssl:p4d:1666
```

### Cache purge

`P4P_CACHE_PURGE_DAYS` sets the number of inactive days before proxy cache
files are purged. It defaults to `30`; set it to `0` to disable deletion.
The container runs the purge daily at 03:00 Asia/Tokyo time.

```yaml
    environment:
      P4P_CACHE_PURGE_DAYS: 30
```

### Cache preload

Set `DEPOT_PATH` in `scripts/preload-proxy-cache.sh`, then run the script on a
host with the `p4` CLI installed and authenticated. It uses `p4 sync -Z
proxyload` through `ssl:localhost:1777` by default, without writing files to a
client workspace. On its first run it creates the dedicated
`p4proxy-preload` client. Override `P4PORT`, `P4USER`, `P4CLIENT`, and
`P4CLIENT_ROOT` in the environment when needed.

## Start the Container

```
make -C helix-proxy start
```

Or run Docker Compose directly from the repository root:

```bash
docker-compose -f helix-proxy/docker-compose.yml -p helix-proxy up -d
```

## Build the Image

```bash
bash build/helix-proxy/docker-build.sh Dockerfile ./build/helix-proxy
```
