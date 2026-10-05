# Building the Helix Proxy (P4P) Image

This directory contains the sources and scripts for building the Helix Proxy
base image. For running the published image with Docker Compose, see
[the service README](../../helix-proxy/README.md).

## Build Assets

- `Dockerfile`: Dockerfile for rebuilding the base image
- `.env`: Build configuration, including the target image name
- `docker-build.sh`: Build wrapper that assembles `--build-arg` values from
  `.env`
- `docker-test.sh`: Integration test for the built image
- `files/run.sh`: Proxy startup logic
- `files/p4p`: Proxy configuration
- `files/p4p-master.conf`: Master proxy configuration

## Build the Image

From the repository root:

```bash
bash build/helix-proxy/docker-build.sh Dockerfile ./build/helix-proxy
```

`docker-build.sh` passes the variables in `build/helix-proxy/.env` as
`--build-arg` values, except `IMAGE_NAME`, which specifies the target image
tag.

## Test the Image

After building the image, run its integration test from the repository root:

```bash
bash build/helix-proxy/docker-test.sh ./build/helix-proxy
```

The test runs `p4p -V` in a temporary container to verify that the proxy
executable is available.
