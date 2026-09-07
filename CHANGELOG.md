# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.1.0] - 2026-09-07

### Added

- **`update.sh`: move between release tags on purpose.** It updates to the latest release (a combination this repository's CI has booted and smoke-tested), refuses to cross a major version unattended, refuses to run over local changes, and names any new required variable before anything has moved. `--dry-run` says what would happen.

where else, and that file is
  tracked; the shipped copy holds a placeholder that the compose command fills
  from `.env` on the way in. CI checks that the placeholder is still there and
  that the render works. The config this descends from once carried a real
  password, and it left the machine before anyone noticed.
- **A health check with no `pgrep -f` fallback.** That branch could only ever
  succeed, because the shell running the check carries the pattern in its own
  command line — measured: `pgrep -f ZZZ_no_such_process` exits 0 in this
  container. One exact match on `linuxjampded` replaces it, and
  `tests/e2e-healthcheck.sh` proves the `pgrep -f` form stays green with the
  game dead.
- **The game files supplied by their owner.** `assets0-3.pk3` go in
  `assets/`; without them the image's start script exits by design, and CI
  starts the real image with an empty directory to prove it refuses.
- **Measured limits.** Resident 51 MB; the 2.4 GB once recorded as a peak was
  page cache, which a limit reclaims rather than kills.
- **Deployment Verification CI**: shell and workflow linting, a Trivy scan of
  the pinned image, a daily freshness check on the pin, the health-check
  suite, the refusal-without-assets proof and the render proof.

[Unreleased]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/releases/tag/v1.0.0
