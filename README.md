# Jedi Academy server using Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/jediacademy-server-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/jediacademy-server-docker-compose/actions/workflows/deployment-verification.yml)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/14893/badge)](https://www.bestpractices.dev/projects/14893)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Jedi Knight: Jedi Academy free-for-all server with the JA+ mod, pinned by digest, bots filling the room, and a health check that stopped lying.

```bash
git clone https://github.com/heyvaldemar/jediacademy-server-docker-compose
cd jediacademy-server-docker-compose
cp .env.example .env && $EDITOR .env          # an rcon password
cp "/path/to/Jedi Academy/GameData/base/assets"[0-3].pk3 assets/
docker compose -f jediacademy-server-docker-compose.yml -p jka up -d
```

The image cannot ship the game: `assets0.pk3` through `assets3.pk3` belong to whoever owns a copy of Jedi Academy, and on Steam they are in `GameData/base/`. Put them in `assets/` and the start script copies them in. Without them it exits, on purpose, and CI proves that it does.

```bash
docker compose -p jka logs -f jka-server
docker compose -p jka ps          # healthy once linuxjampded is up
```

Players add `your-address:29070` to their favourites. The original master server is gone, so the in-game browser will not find you.

## What this file knows that a fresh one does not

**The rcon password is rendered into the config at start and never kept in it.** idTech3 reads `rconpassword` from `server.cfg` and nowhere else, and `server.cfg` is a tracked file. The one shipped here holds a placeholder; the command in the compose file substitutes the value from `.env` into the copy the image's own start script picks up, then runs that script exactly as shipped. CI checks both halves: that the tracked file still has the placeholder, and that the render produces the value. This exists because the config this template descends from once carried a real password, and it left the machine before anyone noticed.

**The health check has no `pgrep -f` fallback.** It used to end in `|| pgrep -f jampded`, and that branch could only ever succeed: `pgrep -f` searches whole command lines, and the shell running the check carries the pattern in its own. Measured in this container, `pgrep -f ZZZ_no_such_process` exits 0. So the branch reached only when the game was gone was the branch that always passed. The comm of the running server is exactly `linuxjampded`; the wrapper's is `start_server.sh`; one exact match is enough. `tests/e2e-healthcheck.sh` proves it against a real container, including that the `pgrep -f` form stays green with the game dead.

**The memory ceiling is measured, not guessed.** The server is resident at 51 MB. The 2.4 GB once recorded as its peak was the pk3 files in the page cache, which a limit reclaims rather than kills. 3 GB leaves that room and still bounds it.

**The port is published under the number it binds**, because the address in a player's favourites is the address the server has to answer on.

## Hiding your home address

If you run this at home and want nothing listening on your router, put the game container in the network namespace of a WireGuard sidecar that dials out to a cheap relay: [game-server-wireguard-relay-docker-compose](https://github.com/heyvaldemar/game-server-wireguard-relay-docker-compose).

## Administration

rcon in idTech3 is a UDP packet, not a TCP session; any Quake 3 rcon tool works. From inside the container's namespace, with the password from `.env`:

```bash
docker run --rm --network "container:$(docker compose -p jka ps -q jka-server)" python:3.13-alpine \
  python3 -c 'import socket,os; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(5)
s.sendto(b"\xff\xff\xff\xffrcon "+os.environ["PW"].encode()+b" status", ("127.0.0.1",29070)); print(s.recv(4096).decode(errors="replace"))' \
  -e PW="$(grep ^JKA_SERVER_RCON_PASSWORD= .env | cut -d= -f2-)"
```

Everything else — the server name, the game type, the bot count, the rotation — is in `cfg/server.cfg`. Edit and `docker compose -p jka restart jka-server`.

## Updating

The pin lives in the `x-images` block at the top of the compose file, as an interpolation default, so a `git pull` delivers the image this repository has tested. The server inside is Raven's 2009 dedicated build plus JA+; neither is going to change, so the pin will move rarely, and the daily freshness check says when. `./update.sh` does that on purpose: it moves to the latest release tag, refuses to cross a major unattended, and names any new required variable before anything has moved.

## Testing

CI starts the real image with an empty `assets/` directory and asserts that it refuses — the start script's own message must be in the log, and the container must never reach healthy. It renders the rcon placeholder from a placeholder `.env` and checks the result, and checks that the tracked config never carries a rendered value. `tests/e2e-healthcheck.sh` runs the health check in both directions against a fixture with no game download. All of it on every push, alongside shell and workflow linting, a Trivy scan of the pinned image, and a daily check that the pin still resolves to what upstream publishes.

CI does not play the game. That needs the pk3 files, and they are not the repository's to have.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
