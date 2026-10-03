# Docker Helix P4

This repository runs Perforce Helix Core (P4D) in a Docker container. It is primarily intended for development and validation.

## Overview

- Exposes port 1666 over SSL
- Persists server data in the Docker volume named `servers`
- Uses a custom network `app_net` with subnet `172.16.238.0/24`
- Uses the case consistency trigger script `CheckCaseTrigger3.py` on change submit
- Keeps service runtime assets and build assets separate for future multi-service support

## Repository Structure

- `helix-p4d/docker-compose.yml`: Service definition for Helix Core
- `helix-p4d/Makefile`: Daily operation commands
- `helix-p4d/p4d/Dockerfile`: Runtime Dockerfile based on `ghcr.io/radicalgrimoire/docker-helix-p4/helix-p4d:latest`
- `helix-p4d/p4d/download-certs.sh`: Helper script to download certificate archives from GitHub Releases
- `build/helix-p4d/Dockerfile`: Dockerfile for rebuilding the base image
- `build/helix-p4d/docker-build.sh`: Build wrapper that assembles `--build-arg` values from `.env` and environment variables
- `build/helix-p4d/files/init.sh`: First-time initialization logic
- `build/helix-p4d/files/run.sh`: Startup logic

## Prerequisites

- Docker
- Docker Compose (`docker-compose` command)
- GNU Make (`make`)
- `winpty` on Windows if you use `make shell`

## Quick Start

Run the commands from the repository root.

| Step | Command | Description |
| --- | --- | --- |
| 1 | `make -C helix-p4d start` | Start the Helix Core container in detached mode. |
| 2 | `make -C helix-p4d logs` | Follow container logs to confirm startup and runtime status. |
| 3 | `make -C helix-p4d shell` | Open an interactive shell inside the running container. |
| 4 | `make -C helix-p4d stop` | Stop the running container without removing it. |
| 5 | `make -C helix-p4d remove` | Remove the container and network created by `docker-compose down`. |

Direct Docker Compose command:

```bash
docker-compose -f helix-p4d/docker-compose.yml -p helixcore up -d
```

## Makefile Commands

- `make -C helix-p4d start`: Start containers
- `make -C helix-p4d stop`: Stop containers
- `make -C helix-p4d remove`: Run `docker-compose down`
- `make -C helix-p4d logs`: Follow logs
- `make -C helix-p4d shell`: Open bash in the container
- `make -C helix-p4d build`: Build the runtime image from the Compose definition
- `make -C helix-p4d rebuild`: Rebuild the runtime image without cache
- `make -C helix-p4d change-password`: Change the `super` user password

Example for `change-password`:

```bash
OLD_PASS=<current-password> NEW_PASS=<new-password> make -C helix-p4d change-password
```

After changing the password, update `P4PASSWD` in your Compose, environment, or secret settings before restart.

## Network and Persistence

- Container name: `helix-p4d`
- Static IP: `172.16.238.10`
- Published port: `1666:1666`
- Volume: `servers:/opt/perforce/servers`

Data remains available across container recreation unless you remove the volume.

## Environment Variables

Main variables used by this project:

| Variable | Description | Example |
| --- | --- | --- |
| `P4NAME` | Perforce server name | `master` |
| `P4PORT` | Server port | `ssl:1666` |
| `P4USER` | Admin user | `super` |
| `P4PASSWD` | Admin password | Any secure value |
| `P4HOME` | Perforce home | `/opt/perforce/servers` |
| `P4ROOT` | Server root | `/opt/perforce/servers/master` |
| `CASE_INSENSITIVE` | Case mode (`0` = case-sensitive, `1` = case-insensitive) | `0` |
| `P4CONFIG` | P4 config path | `/opt/perforce/.p4config` |

Notes:

- The current Compose file does not explicitly define environment values.
- Effective values depend on the base image configuration and build arguments.
- To pin values, add `services.helixcore.environment` in `helix-p4d/docker-compose.yml`.

Example:

```yaml
services:
  helixcore:
    environment:
      P4NAME: master
      P4PORT: ssl:1666
      P4USER: super
      P4PASSWD: your-password
      P4ROOT: /opt/perforce/servers/master
      CASE_INSENSITIVE: 0
```

## Building Images

For standard operation, the image referenced by `helix-p4d/p4d/Dockerfile` is sufficient. Rebuild the base image when you need to customize it.

```bash
bash build/helix-p4d/docker-build.sh Dockerfile ./build/helix-p4d
```

`build/helix-p4d/docker-build.sh` passes these values as `--build-arg`:

- Variables defined in `build/helix-p4d/.env`
- Runtime environment variables: `P4NAME`, `P4PORT`, `P4USER`, `P4PASSWD`, `P4HOME`, `P4ROOT`, and `CASE_INSENSITIVE`

## Startup Behavior

`build/helix-p4d/files/init.sh` performs first-time configuration:

- Initializes the server with `configure-helix-p4d.sh`
- Runs `p4 trust` and `p4 login`
- Sets server configuration values such as `server.extensions.allow.unsigned`
- Registers the case consistency trigger
- Imports the admin group definition from `admin.txt`

`build/helix-p4d/files/run.sh` performs startup tasks:

- Starts the server with `p4dctl start -t p4d ${P4NAME}`
- Starts cron
- Attempts login using `P4PASSWD`
- Rewrites `P4CONFIG` only when login succeeds
- Tails `P4ROOT/logs/log`

If `P4PASSWD` does not match the actual server password in an existing volume, startup continues but automatic login fails. The administrator user `super` is not intended to have its password changed during normal operation.

## Connection Example

For both P4V and CLI:

- Server: `ssl:localhost:1666`
- User: `super` or your configured user
- Password: the value currently configured on the server

CLI:

```bash
p4 -p ssl:localhost:1666 -u super login
```

## Certificate Download Helper

`helix-p4d/p4d/download-certs.sh` downloads and extracts certificate archives from GitHub Releases.

```bash
bash helix-p4d/p4d/download-certs.sh --help
```

Main options:

- `-r`, `--repo`: Repository in `owner/repository` format
- `-t`, `--token`: GitHub token
- `-d`, `--dir`: Download directory
- `-y`, `--yes`: Skip confirmation prompts

## CI/CD Workflows

The `.github/workflows` directory includes:

- `build-test.yml`: Build and integration tests for branches
- `build-develop.yml`: Reusable test-to-publish pipeline and manual Core build entry point
- `scheduled-build.yml`: Scheduled build entry point; each service supplies its own build path
- `test.yml`: Reusable test workflow
- `get-version.yml`: Extracts `p4d -V` from the built image artifact
- `publish.yml`: Publishes tagged images to GHCR

Main publish tags:

- `<version>.<run_number>`
- `latest`
- `nightly` (only on scheduled runs)

## Troubleshooting

If startup fails:

- Check whether port 1666 is already in use.
- Check errors with `make -C helix-p4d logs`.
- Check container state with `docker ps -a`.

If connection fails:

- Verify the target server is `ssl:localhost:1666`.
- First connection may require `p4 trust`.

Server status check example:

```bash
make -C helix-p4d shell
p4dctl status
```

## References

- [Perforce Helix Core Documentation](https://www.perforce.com/manuals/p4sag/)
- [Container Image](https://github.com/radicalgrimoire/docker-helix-p4/pkgs/container/docker-helix-p4%2Fhelix-p4d)
- [Helix Authentication Extension](https://github.com/perforce/helix-authentication-extension)

## Notes

This setup is intended for development and validation. For production, at minimum, design and validate:

- Authentication and authorization
- Network restrictions
- Backup and restore procedures
- Monitoring and alerting
- Certificate distribution and rotation