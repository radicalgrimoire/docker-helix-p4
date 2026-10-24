# Docker Helix P4

- [Helix Core (P4D)](helix-p4d/README.md)
- [Helix Proxy (P4P)](helix-proxy/README.md)
- [Helix Authentication Service build](build/helix-auth-svc/README.md)（テスト中）

## CI/CD workflows

The build, version detection, image deletion, publish, and scan workflow definitions are maintained
in [radicalgrimoire/radicalgrimoire](https://github.com/radicalgrimoire/radicalgrimoire/tree/main/.github/workflows).
[build-develop.yml](.github/workflows/build-develop.yml) and
[build-test.yml](.github/workflows/build-test.yml) call them at `@main`;
[scheduled-build.yml](.github/workflows/scheduled-build.yml) remains the scheduled
entry point.

Scheduled builds run daily at 01:00 JST (16:00 UTC on the previous day) for
Helix Core, Helix Proxy, and Helix Authentication Service. Images use the upstream
version as their tag, without a workflow run number. The publish pipeline calls
`get-version.yml` -> `delete-image.yml` -> `publish.yml`, with deletion gated on
the required scan succeeding (or being skipped for services without a scan).
Any GHCR image version with that exact tag is deleted, then the version tag and `latest`
are pushed; scheduled runs also push `nightly`. Deleting a GHCR image version
also removes any other tags pointing to it, so those tags may be temporarily
unavailable (and remain absent if publishing fails).
Builds for the same service are serialized across deletion and publication.

Temporary deletion test: the caller currently bypasses `delete-image.yml`, and
publishing uses a numbered version tag plus a run-specific image label to create
a second, distinct image version. Restore the deletion job and unnumbered
publishing after verifying that both versions exist.

Only the definitions are centralized. Runs and jobs still belong to this
repository. Checkout uses this repository and `source_ref`; artifacts remain in
the same run, and images are still published under
`ghcr.io/radicalgrimoire/docker-helix-p4/`. Actions secrets, variables, and token
permissions continue to come from this repository.

When deploying this migration, merge and push the five reusable workflows to
`radicalgrimoire/radicalgrimoire`'s `main` branch **before** updating the callers
and removing the local definitions here. The caller repository's Actions policy
must allow reusable workflows from `radicalgrimoire/radicalgrimoire`.