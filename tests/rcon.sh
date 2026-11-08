#!/bin/bash
# Does tools/rcon.sh talk idTech3 rcon, and keep the password off every
# command line?
#
# Against a stand-in that answers rcon as idTech3 does
# (tests/fixtures/fake-getstatus.py), in its own network namespace:
#
#   the password   status comes back, exit 0
#   a wrong one    "the server refused the password", exit 2
#   silence        a stand-in that never answers: exit 1, no hang
#   no argv        while a reply is two seconds late, no command line on this
#                  machine or in the test's own containers carries the
#                  password; and the control, a process that does carry it,
#                  is seen by the same sampler
#
# The real server cannot run in public CI (its assets cannot be
# redistributed); the protocol is the same one quake3's CI proves on a real
# idTech3 server.
# shellcheck disable=SC2015   # pass and fail always exit 0, so "A && pass || fail" is if-then-else here
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASSED=0; FAILED=0
pass() { echo "  PASS: $1"; PASSED=$((PASSED+1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED+1)); }
PY=python:3.13-alpine@sha256:7984cf56ceaddebe4fefeb75d64000b9f45d8b77b11a09b24524da6cdc3af0c8
T=$(mktemp -d); chmod 700 "$T"
NET="jka-rcon-net-$$"
cleanup() { docker rm -f "$NET" >/dev/null 2>&1; rm -rf "$T"; }
trap cleanup EXIT

mkdir -p "$T/tools"
cp tools/rcon.sh "$T/tools/rcon.sh"
pw=$(openssl rand -hex 16)
umask 077
printf '%s\n' "$pw" > "$T/pw"
printf 'JKA_SERVER_RCON_PASSWORD=%s\nJKA_SERVER_PORT=29070\n' "$pw" > "$T/.env"
umask 022
chmod 644 "$T/pw"   # read by the stand-in's user

standin() {  # mode
  docker rm -f "$NET" >/dev/null 2>&1
  docker run -d --name "$NET" -v "$PWD/tests/fixtures/fake-getstatus.py:/fake.py:ro" -v "$T/pw:/rcon-password:ro" \
    "$PY" python3 -u /fake.py "$1" 29070 0.0.0.0 >/dev/null || return 1
  for _ in $(seq 1 40); do docker logs "$NET" 2>&1 | grep -q '^bound' && return 0; sleep 0.25; done
  return 1
}
run() { out=$(JKA_RCON_CONTAINER="$NET" "$T/tools/rcon.sh" "$@" 2>&1); rc=$?; }

echo "=== tools/rcon.sh against a stand-in ==="
echo
standin answers || { fail "the stand-in never bound its port"; echo; echo "passed: $PASSED   failed: $FAILED"; exit 1; }
run status
[ "$rc" = 0 ] && grep -q '^map:' <<<"$out" && pass "the password: the status table, exit 0" || fail "status: exit $rc, $out"

sed -i.bak 's/^JKA_SERVER_RCON_PASSWORD=.*/JKA_SERVER_RCON_PASSWORD=not-the-password/' "$T/.env"
run status
[ "$rc" = 2 ] && grep -q 'refused the password' <<<"$out" && pass "a wrong password: refused, exit 2" || fail "wrong password: exit $rc, $out"
mv "$T/.env.bak" "$T/.env"

standin silent
s=$SECONDS; run status; took=$((SECONDS - s))
[ "$rc" = 1 ] && [ "$took" -le 8 ] && pass "a server that never answers: exit 1 in ${took}s" || fail "silent: exit $rc in ${took}s, $out"

standin slow
( JKA_RCON_CONTAINER="$NET" "$T/tools/rcon.sh" status >/dev/null 2>&1 ) &
bg=$!
hits=0
for _ in 1 2 3 4 5 6 7 8; do
  sleep 0.2
  # shellcheck disable=SC2009  # every command line on this machine, not one process
  h=$(ps -eo args= 2>/dev/null | grep -cF -f "$T/pw" || true)
  # shellcheck disable=SC2016  # expanded by the container's shell
  c=$(for id in $(docker ps -q --filter "ancestor=$PY"); do docker exec "$id" sh -c 'for f in /proc/[0-9]*/cmdline; do tr "\000" " " < "$f" 2>/dev/null; echo; done' 2>/dev/null; done | grep -cF -f "$T/pw" || true)
  hits=$((hits + h + c))
done
wait "$bg"
[ "$hits" = 0 ] && pass "while the reply was late, no command line here or in a container carried the password" || fail "the password was on a command line $hits time(s)"

# The control: the same sampler must see a password that IS on a command line,
# or the zero above proves nothing.
( sh -c 'sleep 2; :' "$(cat "$T/pw")" ) &
bg=$!
sleep 0.5
# shellcheck disable=SC2009  # every command line on this machine, not one process
seen=$(ps -eo args= 2>/dev/null | grep -cF -f "$T/pw" || true)
wait "$bg"
[ "${seen:-0}" -gt 0 ] && pass "the control: a password on a command line is seen by the same sampler" || fail "the sampler missed a password that was on a command line"

echo
echo "passed: $PASSED   failed: $FAILED"
[ "$FAILED" -eq 0 ]
