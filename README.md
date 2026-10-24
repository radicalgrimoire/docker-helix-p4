# Docker Helix P4

- [Helix Core (P4D)](helix-p4d/README.md)
- [Helix Proxy (P4P)](helix-proxy/README.md)
- [Helix Authentication Service build](build/helix-auth-svc/README.md)（テスト中）

## CI/CD workflows

The build, version detection, publish, and scan workflow definitions are maintained
in [radicalgrimoire/radicalgrimoire](https://github.com/radicalgrimoire/radicalgrimoire/tree/main/.github/workflows).
[build-develop.yml](.github/workflows/build-develop.yml) and
[build-test.yml](.github/workflows/build-test.yml) call them at `@main`;
[scheduled-build.yml](.github/workflows/scheduled-build.yml) remains the scheduled
entry point.

Only the definitions are centralized. Runs and jobs still belong to this
repository. Checkout uses this repository and `source_ref`; artifacts remain in
the same run, and images are still published under
`ghcr.io/radicalgrimoire/docker-helix-p4/`. Actions secrets, variables, and token
permissions continue to come from this repository.

When deploying this migration, merge and push the four reusable workflows to
`radicalgrimoire/radicalgrimoire`'s `main` branch **before** updating the callers
and removing the local definitions here. The caller repository's Actions policy
must allow reusable workflows from `radicalgrimoire/radicalgrimoire`.