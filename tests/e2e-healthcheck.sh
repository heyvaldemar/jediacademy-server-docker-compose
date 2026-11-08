#!/bin/bash
# Does the health check go by the game's own answer, run in the pinned image?
#
# tools/healthcheck.sh sends getstatus, idTech3's status query, to the game
# port and is healthy only on the engine's statusResponse. Here it runs in the image
# the compose file pins, so bash, timeout, head, od and tr are proven to be
# there, against a stand-in that speaks just enough idTech3
# (tests/fixtures/fake-getstatus.py), in the stand-in's network namespace:
#
#   answers     bound to the container's own address: healthy
#   0.0.0.0     bound to every address and deaf to a query from 127.0.0.1:
#               healthy, asked at the container's own address
#   silent      a socket on the port that never answers, on one address and
#               on 0.0.0.0 (two to ask): unhealthy, and the check is over
#               within 8 seconds, inside the 10 Docker gives it
#   no socket   nothing bound to the port, which is a process that stands
#               without a network, as Black Mesa's did on Docker 29.4.2:
#               unhealthy
#
# The stand-in is not a server, and there is no real one in this repository's
# CI: the game's assets cannot be redistributed, so no public runner can start
# it. The refuses-without-assets job checks the check is red there.
# shellcheck disable=SC2015   # pass and fail always exit 0, so "A && pass || fail" is if-then-else here
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASSED=0; FAILED=0
pass() { echo "  PASS: $1"; PASSED=$((PASSED+1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED+1)); }
IMAGE=$(grep -m1 -oE '\$\{JKA_SERVER_IMAGE_TAG:-.*' jediacademy-server-docker-compose.yml | sed -E -e ':a' -e 's/\$\{[A-Z0-9_]+:-([^{}]*)\}/\1/' -e 'ta')
PY=python:3.13-alpine@sha256:7984cf56ceaddebe4fefeb75d64000b9f45d8b77b11a09b24524da6cdc3af0c8
NET="jka-hc-net-$$"
cleanup() { docker rm -f "$NET" >/dev/null 2>&1; }
trap cleanup EXIT

standin() {  # mode bind: a fresh stand-in, waited for until it is bound
  docker rm -f "$NET" >/dev/null 2>&1
  docker run -d --name "$NET" -v "$PWD/tests/fixtures/fake-getstatus.py:/fake-getstatus.py:ro" "$PY" \
    python3 -u /fake-getstatus.py "$1" 29070 "$2" >/dev/null || return 1
  for _ in $(seq 1 40); do
    docker logs "$NET" 2>&1 | grep -q '^bound' && return 0
    sleep 0.25
  done
  return 1
}
empty() {  # a namespace with nothing bound to the port
  docker rm -f "$NET" >/dev/null 2>&1
  docker run -d --name "$NET" "$PY" sleep 300 >/dev/null
}
check() {  # run the health check in the pinned image, in the stand-in's namespace: sets rc, out, secs
  out=$(docker run --rm --platform linux/amd64 --network "container:$NET" --entrypoint bash \
    -v "$PWD/tools/healthcheck.sh:/healthcheck.sh:ro" "$IMAGE" \
    -c 's=$SECONDS; bash /healthcheck.sh 29070; rc=$?; echo "secs=$((SECONDS - s))"; exit $rc' 2>&1); rc=$?
  secs=$(sed -n 's/^secs=//p' <<<"$out"); out=$(grep -v '^secs=' <<<"$out")
}

echo "=== the health check, in the pinned image, against a stand-in ==="
echo

standin answers iface || { fail "the stand-in never bound its port"; echo; echo "passed: $PASSED   failed: $FAILED"; exit 1; }
check
[ "$rc" = 0 ] && grep -q "^healthy:" <<<"$out" && pass "an answer on the container's own address: healthy ($out)" || fail "answers: exit $rc, $out"

standin noloop 0.0.0.0 || fail "the 0.0.0.0 stand-in never bound its port"
check
[ "$rc" = 0 ] && pass "bound to 0.0.0.0 and deaf to 127.0.0.1: healthy, asked at the container's address" || fail "0.0.0.0: exit $rc, $out"

standin silent iface || fail "the silent stand-in never bound its port"
check
[ "$rc" = 1 ] && [[ $out == *"no statusResponse"* ]] && pass "a socket that never answers: unhealthy" || fail "silent: exit $rc, $out"
[ -n "$secs" ] && [ "$secs" -le 8 ] && pass "and the check was over in ${secs}s, inside Docker's 10" || fail "silent: the check took ${secs:-?}s"

standin silent 0.0.0.0 || fail "the silent 0.0.0.0 stand-in never bound its port"
check
[ "$rc" = 1 ] && [ -n "$secs" ] && [ "$secs" -le 8 ] && pass "silent on 0.0.0.0, two addresses asked: unhealthy in ${secs}s" || fail "silent 0.0.0.0: exit $rc in ${secs:-?}s, $out"

empty
check
[ "$rc" = 1 ] && [[ $out == *"nothing is bound"* ]] && pass "no socket on the port: unhealthy" || fail "no socket: exit $rc, $out"

echo
echo "passed: $PASSED   failed: $FAILED"
[ "$FAILED" -eq 0 ]
