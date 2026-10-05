# Building the Helix Core (P4D) Image

This directory contains the sources and scripts for building the Helix Core
base image. For running the published image with Docker Compose, see
[the service README](../../helix-p4d/README.md).

## Build Assets

- `Dockerfile`: Dockerfile for rebuilding the base image
- `.env`: Build configuration, including the target image name
- `docker-build.sh`: Build wrapper that assembles `--build-arg` values from
  `.env` and environment variables
- `docker-test.sh`: Integration test for the built image
- `files/init.sh`: First-time initialization logic
- `files/run.sh`: Startup logic

## Build the Image

From the repository root:

```bash
bash build/helix-p4d/docker-build.sh Dockerfile ./build/helix-p4d
```

`docker-build.sh` passes the variables in `build/helix-p4d/.env` as
`--build-arg` values, except `IMAGE_NAME`, which specifies the target image
tag. The following values can also be supplied through the environment:

| Variable | Description | Example |
| --- | --- | --- |
| `P4NAME` | Perforce server name | `master` |
| `P4PORT` | Server port | `ssl:1666` |
| `P4USER` | Admin user | `super` |
| `P4PASSWD` | Admin password | Any secure value |
| `P4HOME` | Perforce home | `/opt/perforce/servers` |
| `P4ROOT` | Server root | `/opt/perforce/servers/master` |
| `CASE_INSENSITIVE` | Case mode (`0` = case-sensitive, `1` = case-insensitive) | `0` |

## Test the Image

After building the image, run its integration test from the repository root:

```bash
bash build/helix-p4d/docker-test.sh ./build/helix-p4d
```

The test starts a temporary container, waits for P4D to become available, logs
in as the configured user, and verifies the server information.

## Initialization and Startup Behavior

`files/init.sh` performs first-time configuration:

- Initializes the server with `configure-helix-p4d.sh`
- Runs `p4 trust` and `p4 login`
- Sets server configuration values such as `server.extensions.allow.unsigned`
- Registers the case consistency trigger
- Imports the admin group definition from `admin.txt`

`files/run.sh` performs startup tasks:

- Starts the server with `p4dctl start -t p4d ${P4NAME}`
- Starts cron
- Attempts login using `P4PASSWD`
- Rewrites `P4CONFIG` only when login succeeds
- Tails `P4ROOT/logs/log`

If `P4PASSWD` does not match the actual server password in an existing volume,
startup continues but automatic login fails. The administrator user `super` is
not intended to have its password changed during normal operation.

## CI/CD Workflows

The `.github/workflows` directory includes:

- `build-test.yml`: Build and integration tests for branches
- `build-develop.yml`: Reusable test-to-publish pipeline and manual Core build
  entry point
- `scheduled-build.yml`: Scheduled build entry point; each service supplies
  its own build path
- `test.yml`: Reusable test workflow
- `get-version.yml`: Extracts `p4d -V` from the built image artifact
- `publish.yml`: Publishes tagged images to GHCR

Main publish tags:

- `<version>.<run_number>`
- `latest`
- `nightly` (only on scheduled runs)
