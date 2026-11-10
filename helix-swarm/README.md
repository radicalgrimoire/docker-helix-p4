# Running P4 Code Review

This Compose configuration runs the `2026.4` P4 Code Review image built from
[`build/helix-swarm`](../build/helix-swarm/README.md).

When the data volume has no `config.php`, the image initializes it using
`P4D_PORT`, `SWARM_USER`, and `SWARM_PASSWD`. `SWARM_HOST` is optional and
defaults to `localhost`. All three required values must be nonempty; startup
fails if any is missing. Initialization creates a worker token and sets data
directory permissions, but does not connect to Helix Core, create a user,
modify protections, install extensions, or validate the credentials.

An existing `config.php` is never overwritten, even if environment variables
change. To change an existing configuration, update it using the documented
Swarm configuration procedures and clear the relevant Swarm config cache.

For a new installation, supply values using the environment or a local
`helix-swarm/.env` file:

```dotenv
P4D_PORT=ssl:perforce.example.com:1666
SWARM_USER=swarm
SWARM_PASSWD='<password-or-login-ticket>'
SWARM_HOST=swarm.example.com
```

Replace the placeholders before starting. The `.env` file is Git-ignored but
still contains a credential: restrict its permissions and do not share it.
Use single quotes around `SWARM_PASSWD` so Compose does not interpolate `$`;
escape a literal single quote as `\'`.
Environment variables are also visible through Docker container inspection.
The generated `config.php` contains the credential and must be protected and
backed up securely. The built-in Swarm code automatically accepts an unknown
Helix Core SSL fingerprint on first connection. Verify and establish server
trust independently before allowing it to connect; environment-based
initialization does not verify the server certificate.

## Production deployment

After an image containing the initialization changes has been built and
published, use the fixed image version:

```bash
cd helix-swarm
docker compose pull
docker compose up -d
```

By default, the service uses these named volumes:

| Volume | Container path |
| --- | --- |
| `swarm_server_swarm-data` | `/opt/perforce/swarm/data` |
| `swarm_server_file` | `/opt/perforce/etc/file` |
| `swarm_server_redis` | `/opt/perforce/swarm/redis` |

The first two are the volume names created by the existing
`SIN-Docker/swarm_server` Compose project. The Redis volume is new and does not
automatically import data from an external Redis instance. The image enables
Redis append-only persistence; recent writes can still be lost on an unexpected
shutdown. Check that the existing Swarm configuration uses `localhost:7379`
before switching to the bundled Redis.

Set `SWARM_HTTP_PORT` or `SWARM_HTTPS_PORT` when the host ports 80 or 443 are
already occupied. Port 80 should be closed or redirected to HTTPS according to
the P4 Code Review Apache configuration.
