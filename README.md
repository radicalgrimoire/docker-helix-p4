# Docker Helix P4

- [Helix Core (P4D)](helix-p4d/README.md)
- [Helix Proxy (P4P)](helix-proxy/README.md)
- [Helix Swarm build](build/helix-swarm/README.md)
- [P4 Code Review deployment](helix-swarm/README.md)
- [Helix Authentication Service build](build/helix-auth-svc/README.md)（テスト中）

## CI/CD workflows

The build, version detection, image deletion, publish, and scan workflow definitions are maintained
in [radicalgrimoire/radicalgrimoire](https://github.com/radicalgrimoire/radicalgrimoire/tree/main/.github/workflows).
[build-develop.yml](.github/workflows/build-develop.yml) and
[build-test.yml](.github/workflows/build-test.yml) call them at `@main`;
[scheduled-build.yml](.github/workflows/scheduled-build.yml) remains the scheduled
entry point.

Scheduled builds run daily at 01:00 JST (16:00 UTC on the previous day) for
Helix Core, Helix Proxy, Helix Swarm, and Helix Authentication Service. The
`scheduled-build` workflow can also be started manually from GitHub Actions.
Manual runs build the same services from `main` and may commit an updated
Helix Authentication Service version to `main`, but do not publish the
`nightly` tag. Images use the upstream version as their tag, without a workflow
run number. After version detection and
the required scan succeeds (or is skipped for services without a scan),
`publish.yml` pushes the version tag and `latest`; scheduled runs also push
`nightly`. Once publishing succeeds, `delete-image.yml` removes untagged GHCR
images while preserving tagged images and their referenced manifests. A cleanup
with no eligible images is a no-op; cleanup errors still fail the job.
Builds for the same service are serialized across publication and cleanup.

Only the definitions are centralized. Runs and jobs still belong to this
repository. Checkout uses this repository and `source_ref`; artifacts remain in
the same run, and images are still published under
`ghcr.io/radicalgrimoire/docker-helix-p4/`. Actions secrets, variables, and token
permissions continue to come from this repository.

The caller repository's Actions policy must allow reusable workflows from
`radicalgrimoire/radicalgrimoire`. Deploy the updated reusable `delete-image.yml`
on `main` before updating the caller. The reusable workflow retains its previous
behavior for callers that do not set `cleanup_untagged`.