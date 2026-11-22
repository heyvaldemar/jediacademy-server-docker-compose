# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **The secret probe no longer counts a place of blank lines as read.** `collect()` checked that each place (compose logs, command lines, the host's `ps`) was not empty with `-s`, which a file of nothing but line ends passes: a process with an empty command line still ends its line. It now needs one line with something in it, or the probe fails, naming the place. CI only; nothing a deployment runs changes.
- **The secret probe no longer fails when a process ends while it reads the container.** `tests/secret-probe.sh` read each process's command line in a loop that ended on the status of its last test, so a short-lived process last in glob order and gone by the read failed the whole container as unreadable, while an unreadable process anywhere else passed. Now a process gone by the read is not counted, every process still there must be read, and a container that cannot be entered or has nothing to read still fails. Found on the HumanitZ template, where it turned a digest refresh red; against a container starting processes in a loop the old loop failed 170 of 200 reads there and the new one none ([heyvaldemar/humanitz-server-docker-compose#3](https://github.com/heyvaldemar/humanitz-server-docker-compose/pull/3)). CI only; nothing a deployment runs changes.

### Changed

- **The secret probe's selftest makes its Steam IDs and addresses at run time, out of the ranges real accounts and hosts use**, so the file names none. Tests only.
- **The probe's selftest on the stand-in start loop is retried when the container restarts under it.** The canary it holds on a command line in the container went with a round of the loop that ended under it, once (run 43624579301); that miss is now looked at again, and only when the container did restart. Tests only.

## [1.3.2] - 2026-11-14

### Fixed

- **A stop no longer waits out the grace period.** The compose file's command ends in `exec ./start_server.sh`, the image's bash script, which has no handler for SIGTERM, and as process 1 it ignored Docker's stop: every stop and restart waited 15 seconds and ended in Docker's SIGKILL. Docker's init (tini) is process 1 now, with `TINI_KILL_PROCESS_GROUP`, so SIGTERM reaches the start script, the image's restart loop and the server together. CI measures it with stand-in game files and fails a stop that is not ended by SIGTERM: 0 seconds of 15, exit 143 ([run 43622997760](https://github.com/heyvaldemar/jediacademy-server-docker-compose/actions/runs/43622997760)). The game keeps no world on disk, so nothing was lost, only the wait.
- **The secret probe's excerpt of a leaked line replaces Steam IDs and addresses too**, and its selftest reaches the log through any process that shares process 1's output.

## [1.3.1] - 2026-11-14

### Added

- **CI looks for the rcon password on the path it takes at start.** The game files are not redistributable, so the real server never runs in CI. With four empty stand-in `assets*.pk3`, which the image's start script accepts and the server cannot load, the start runs as it would for real: the compose file's command renders the password into `server.cfg`, the start script copies it, the server is started with `+exec server.cfg`, exits, and the image's loop starts it again. `tests/secret-probe.sh` gives the password a value of its own, samples every command line in the container and on the host for 40 seconds of that loop, then reads `docker compose logs` and the command lines again; it names the place, never the value. It found nothing ([run 43621157391](https://github.com/heyvaldemar/jediacademy-server-docker-compose/actions/runs/43621157391)). The CI step that wrote the password into `.env` no longer has it on `sed`'s command line.
- **The README says how to see a crash, and what a stop does.** A crash ends the container and Docker starts it again, with the health check green afterwards: `docker inspect -f '{{.RestartCount}}'` counts them, and this template has no timer to do it for you. The image's start script, process 1, has no handler for SIGTERM, so a stop waits out the 15-second grace period and is killed (read in the pinned image; not measurable without the game, whose stand-in exits on its own). The game keeps no world on disk.

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

[Unreleased]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/jediacademy-server-docker-compose/releases/tag/v1.0.0
