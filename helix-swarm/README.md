# Running P4 Code Review

This Compose configuration runs the `2026.4` P4 Code Review image built from
[`build/helix-swarm`](../build/helix-swarm/README.md).

The image refuses to start without an initialized
`/opt/perforce/swarm/data/config.php`. This protects a new or empty volume from
being confused with a completed Swarm installation.

## Production deployment

Use the published, fixed image version:

```bash
docker compose -f helix-swarm/docker-compose.yml pull
docker compose -f helix-swarm/docker-compose.yml up -d
```

By default, the service uses these named volumes:

| Volume | Container path |
| --- | --- |
| `swarm_server_swarm-data` | `/opt/perforce/swarm/data` |
| `swarm_server_file` | `/opt/perforce/etc/file` |

These are the volume names created by the existing `SIN-Docker/swarm_server`
Compose project. The default configuration therefore attaches the existing data
when it is run on the same Docker host.

Set `SWARM_HTTP_PORT` or `SWARM_HTTPS_PORT` when the host ports 80 or 443 are
already occupied. Port 80 should be closed or redirected to HTTPS according to
the P4 Code Review Apache configuration.
