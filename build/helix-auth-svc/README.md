# Building the Helix Authentication Service Image

This directory builds the Perforce Helix Authentication Service (HAS) image from the official Perforce APT package. It does not use the published `perforce/helix-auth-svc` image.

## Package installation

The Dockerfile follows the same Ubuntu Noble and Perforce APT repository setup as the Helix Core image. It installs the latest `helix-auth-svc` package available when the image is built:

```bash
apt-get install helix-auth-svc
```

`.env` defines the local image name only. It contains no SAML, Azure Entra ID, certificate, or other runtime configuration. The package installs HAS and its Node.js runtime under `/opt/perforce/helix-auth-svc`. The image starts the package's `bin/www.js` directly rather than starting a systemd service.

The official "Easy way to install Node.js" instructions apply to manual HAS installations. Do not install Node.js separately in this image: the version-pinned `helix-auth-svc` package includes its compatible Node.js runtime and service dependencies.

## Build

From the repository root:

```bash
bash build/helix-auth-svc/docker-build.sh Dockerfile ./build/helix-auth-svc
```

## Test

After building, verify that HAS is installed and that its bundled Node.js runtime starts:

```bash
bash build/helix-auth-svc/docker-test.sh ./build/helix-auth-svc
```

Runtime configuration and Docker Compose deployment are intentionally not included yet.

## Experimental vulnerability scan

When the [build workflow](../../.github/workflows/build-develop.yml) builds
`helix-auth-svc`, it calls the reusable [scan workflow](../../.github/workflows/scan.yml)
as an independent job after testing. The scan downloads the saved Docker image
artifact and scans the archive with Trivy in parallel with version detection.
Publishing waits for both jobs. For other images, the scan is skipped and
publishing proceeds after version detection. Test-only workflows do not call the
scan workflow.

The Trivy action is pinned to a commit and the scanner to an explicit version.
The scan reports OS and language-package vulnerabilities at all severities,
including those without a fix. Findings do not block publishing during this
trial, but scanner errors do fail the job. Results are printed as a table in the
scan job's `Scan Docker image` step log; no report artifact is uploaded. No
Docker Hub credentials or Code scanning upload permissions are required.
