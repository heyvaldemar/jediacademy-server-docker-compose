# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **An index pushed again over the same build is no longer reported as drift.** The daily pin check compared each pin with the digest the tag's index has now and failed on any difference, so a publisher re-pushing the index over the very same images (a platform added, an attestation rewritten) turned it red for an image nobody rebuilt, and no pin would ever move to turn it green. It now also compares the linux/amd64 build under both digests, the one CI runs and proves: the same build passes with a notice naming both digests, a new build fails as drift exactly as before, and a build that cannot be read still fails.

## [1.3.0] - 2026-11-08

### Security

- **The README's rcon command put the password on a command line, and could not work.** It passed it as `docker run ... -e PW=<the password>`, in the docker CLI's arguments, where every user on the host reads it with `ps`, and after the image name, where docker hands `-e` to the program as an argument. `tools/rcon.sh` replaces it: the password from `.env` on stdin into a pinned python image in the server's namespace. `tests/rcon.sh` checks it against a stand-in (status, a wrong password, silence) and that no command line carries the password while a reply is late, with a control that does.

### Changed

- **The health check asks the server, not its process.** It looked for `linuxjampded` in `/proc`, which a hung or stopped server keeps. `tools/healthcheck.sh`, mounted read-only, now sends getstatus to the game port and is healthy only on the engine's statusResponse (two tries, within 7 seconds). It is not proven on a real server in CI, which cannot have the game's assets; `tests/e2e-healthcheck.sh` runs it in the pinned image against a stand-in. It asks from inside the container, so it does not prove the port is published on the host or open in a firewall; the README says both.
## [1.2.1] - 2026-11-08

### Security

- **The RCON password is no longer on a command line.** The start command rendered `server.cfg` with `sed "s|__JKA_SERVER_RCON_PASSWORD__|<password>|"`, putting the password in `sed`'s arguments, which every user on the host reads with `ps`. Bash now does the substitution itself (`$(<file)`, `${cfg//…/"$password"}`, `printf`), so no other process sees it, and with the replacement quoted, `&`, `|` and `\` in a password stay literal instead of breaking the expression. The rendered file is mode 600. CI used to check the rendering with its own copy of the `sed` line; it now runs the compose file's own command with a random password and compares the config it leaves behind through a file, so the value is never printed.

### Changed

- **The freshness check has its own workflow, Pin Freshness.** It ran inside Deployment Verification, whose badge is the one at the top of this README. Across the fleet, nine red runs in ten were a pin one version behind - which the fleet's triage moves within the day - and a reader cannot tell that from a stack that does not boot. The badge now says whether the stack boots. The job itself is unchanged.

### Fixed

- **`update.sh` no longer stops without a word when a release adds a variable and no compose file requires one.** The search for `${VAR:?}` came back empty, and under `pipefail` that empty result ended the script with status 1 right after it listed the new variables.
- **`update.sh` stops on a `.env` it cannot read, before the checkout.** It used to fall through: every new required variable read as "not set", or, with none, the tree moved to the new tag and `docker compose up` failed on the permission. Now it names the file, its owner and mode, and changes nothing.

## [1.2.0] - 2026-09-22

### Added

- **`JKA_SERVER_TIMEZONE`: the game gets the household clock too.** Every timestamp this server writes — a ban, a join, the crash it leaves behind — is read next to a log line from somewhere else, and two clocks turn that into arithmetic. Six of this fleet's eleven game templates already carried the setting and this one did not. It defaults to UTC, which is now a choice rather than an accident, and the image carries the whole tz database so any zone name works. Measured against the pinned image: unset gives `UTC`, set gives the zone asked for.

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

[Unreleased]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/releases/tag/v1.0.0
