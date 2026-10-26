# Building the Helix Swarm Image

This image installs the current Helix Swarm package on Ubuntu 24.04 (Noble).
It is a replacement candidate for the legacy Swarm 2022.2/PHP 7.4 image; it
does not embed a Swarm configuration or credentials.

The package installation uses the Perforce APT repository and installs:

- `helix-swarm`

The image build upgrades Ubuntu packages before installing Swarm and passes a
fresh cache-busting value to every build. This prevents a cached package layer
from retaining an older PHP or Swarm package when the build is scheduled. Noble
supplies PHP 8.3, which is supported by current Swarm releases and has a
supported security-maintenance path. The build and test both require
`libapache2-mod-php8.3` version `8.3.6-0ubuntu0.24.04.13` or later. Ubuntu
backported the PHP2Shell fixes (CVE-2026-109618 and CVE-2026-109619) to that
package version; the PHP upstream version number alone is not a valid Noble
security check.

`helix-swarm-triggers` is intentionally not installed in this image. Perforce
documents that package as a Helix Core host dependency when triggers are used;
the preferred Swarm Helix Core extension is configured against Helix Core during
the upgrade. `helix-swarm-optional` is also excluded to preserve the legacy
deployment's package set. Add it only after confirming that ImageMagick or
LibreOffice previews are required.

## Build

From the repository root:

```bash
bash build/helix-swarm/docker-build.sh Dockerfile ./build/helix-swarm
```

## Test

```bash
bash build/helix-swarm/docker-test.sh ./build/helix-swarm
```

The test verifies that Swarm is installed and that the Apache PHP package
contains Ubuntu's PHP2Shell fix. It deliberately does not start Swarm because
a valid Swarm configuration and a Helix Core endpoint are required.

## Image version

```bash
bash build/helix-swarm/docker-get-version.sh ./build/helix-swarm
```

The version comes from the installed `helix-swarm` Debian package and is used by
the image publishing workflow.

## Migrating an existing Swarm data volume

Do not attach a production volume to this image for the first upgrade attempt.
The legacy deployment persists its state at `/opt/perforce/swarm/data`; this
includes `config.php`, review data, and migration state. Export it read-only on
the Swarm host, then import it to a newly named local test volume:

```bash
# On the Swarm host
docker run --rm \
  -v swarm_server_swarm-data:/source:ro \
  -v "$PWD":/backup \
  alpine:3.22 tar -C /source -czf /backup/swarm-data.tar.gz .

# On the isolated test host
docker volume create swarm-upgrade-test-data
docker run --rm \
  -v swarm-upgrade-test-data:/target \
  -v "$PWD":/backup:ro \
  alpine:3.22 sh -c 'tar -C /target -xzf /backup/swarm-data.tar.gz'
```

Export the legacy `swarm_server_file` volume separately if it contains data
needed for the test. Preserve the archive securely: it contains Swarm
configuration and may contain credentials or user content.

Before starting the test container, copy and isolate the corresponding Helix
Core service or configure a non-production endpoint. Swarm upgrades can update
the Swarm Helix Core extension or triggers, so testing against production Helix
Core is not safe. Follow the Perforce release-specific upgrade instructions,
including the required extension or trigger upgrade, before any production
cutover.
