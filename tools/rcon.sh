#!/bin/bash
# rcon.sh - run a console command on the server, over rcon, from inside its
# network namespace.
#
#   tools/rcon.sh status
#   tools/rcon.sh map mp/ffa3
#
# rcon in idTech3 is one UDP packet, `\xff\xff\xff\xffrcon <password> <command>`,
# answered with `print` and the output. The client runs from a pinned python
# image in the server's network namespace, so the port is the server itself
# whatever the network looks like outside.
#
# THE PASSWORD TRAVELS ON STDIN, never in argv, where `ps` on the host would
# show it to every user. It is read from .env, the file the server got it from.
# Up to v1.2.1 the README gave a command that put it in `docker run -e PW=...`,
# in the docker CLI's arguments, and after the image name besides, where docker
# passed it to python as an argument and the command could not work.
#
# Exit codes: 0 answered, 1 the server is not running or nothing answered,
# 2 usage or a wrong password.
#
# Read whole before it runs: one brace group, ending in exit (bash reads a
# script as it runs it, so a file rewritten under a running copy would
# otherwise run the new text from the middle).
{
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
[ "$#" -gt 0 ] || { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
COMPOSE_FILE=${JKA_COMPOSE_FILE:-jediacademy-server-docker-compose.yml}
PROJECT=${COMPOSE_PROJECT_NAME:-jka}
SERVICE=jka-server
PROBE_IMAGE=${JKA_RCON_PROBE_IMAGE:-python:3.13-alpine@sha256:7984cf56ceaddebe4fefeb75d64000b9f45d8b77b11a09b24524da6cdc3af0c8}
PORT=$(sed -n 's/^JKA_SERVER_PORT=\([0-9]*\).*/\1/p' .env 2>/dev/null | tail -1)
PORT=${PORT:-29070}
pw=$(sed -n 's/^JKA_SERVER_RCON_PASSWORD=//p' .env 2>/dev/null | tail -1)
pw=${pw%\"}; pw=${pw#\"}; pw=${pw%\'}; pw=${pw#\'}
[ -n "$pw" ] || { echo "JKA_SERVER_RCON_PASSWORD is not set in .env" >&2; exit 2; }
cid=${JKA_RCON_CONTAINER:-$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT" ps -q --status running "$SERVICE" 2>/dev/null)}
[ -n "$cid" ] || { echo "the server is not running" >&2; exit 1; }
printf '%s\n' "$pw" | docker run --rm -i --network "container:$cid" "$PROBE_IMAGE" python3 -c '
import socket, sys
port, cmd = int(sys.argv[1]), " ".join(sys.argv[2:])
pw = sys.stdin.readline().rstrip("\n")
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)
s.sendto(b"\xff\xff\xff\xffrcon " + pw.encode() + b" " + cmd.encode(), ("127.0.0.1", port))
out = b""
try:
    while True:
        d, _ = s.recvfrom(65535)
        out += d[4:].split(b"\n", 1)[1] if d.startswith(b"\xff\xff\xff\xffprint\n") else d
        s.settimeout(0.5)
except socket.timeout:
    pass
if not out:
    sys.exit("rcon: no answer on port %d" % port)
text = out.decode(errors="replace")
if text.startswith("Bad rconpassword"):
    print("rcon: the server refused the password", file=sys.stderr)
    sys.exit(2)
sys.stdout.write(text)
' "$PORT" "$@"
exit $?
}
