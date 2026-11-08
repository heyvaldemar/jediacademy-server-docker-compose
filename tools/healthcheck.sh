#!/bin/bash
# healthcheck.sh - healthy only when the game itself answers.
#
# Sends getstatus, idTech3's out-of-band status query (the one every server
# browser sends), to the game port inside the container, and exits 0 only on
# the engine's statusResponse. Only a running server loop writes one.
#
# NOT THE PROCESS. Up to v1.2.1 the check looked for linuxjampded in /proc. A
# hung or stopped server keeps its process, and linuxjampded is 32-bit, the
# kind of program Docker Engine 29.4.2's seccomp profile leaves running with
# no socket at all (Black Mesa's did, in its template, while a check like the
# old one stayed green).
#
# NOT THE LOG. An empty server writes nothing for hours while it is perfectly
# well; it still answers getstatus.
#
# A MAP CHANGE stops the answers for the moment the next map takes to load,
# so one check tries twice, a second apart, and Docker's retries cover the
# rest: three misses in a row at the compose file's interval. Every read
# times out after 1.5 seconds; with two addresses to try, a silent server costs
# the whole check 7 seconds, inside the 10 Docker gives it.
#
# THE ADDRESS IT ANSWERS ON. The addresses come from /proc/net/udp, every
# socket bound to the game port; no socket there at all is unhealthy at once.
# Bound to one address, that address; bound to 0.0.0.0, the container's own
# address from /etc/hosts first, then 127.0.0.1.
#
# NOT PROVEN ON A REAL SERVER IN CI. The game's assets cannot be
# redistributed, so no public CI can start this server; tests/e2e-healthcheck.sh
# runs this check in the pinned image against a stand-in that speaks getstatus.
#
# INSIDE THE CONTAINER. This proves the server answers in its own network
# namespace. It does not prove the port is published on the host, nor that a
# firewall lets players in.
#
# Usage: healthcheck.sh [port]   (default 29070). Needs bash, timeout, head,
# od and tr, which the image has (tests/e2e-healthcheck.sh runs it there).
#
# Read whole before it runs: one brace group, ending in exit (bash reads a
# script as it runs it, so a file rewritten under a running copy would
# otherwise run the new text from the middle).
{
set -u
port=${1:-29070}
req='\xff\xff\xff\xffgetstatus\n'
status=ffffffff737461747573526573706f6e7365   # \xff\xff\xff\xff statusResponse

addrs=()   # every address a UDP socket on the game port is bound to
want=$(printf '%04X' "$port")
while read -r _ local _; do
  [[ $local == *:"$want" ]] || continue
  h=${local%%:*}
  if [ "$h" = 00000000 ]; then
    cands=()
    read -r me < /etc/hostname 2>/dev/null || me=
    while read -r ip name _; do
      [[ -n $me && $name == "$me" && $ip == *.*.*.* ]] && cands+=("$ip")
    done < /etc/hosts
    cands+=(127.0.0.1)
  else
    cands=("$(printf '%d.%d.%d.%d' "0x${h:6:2}" "0x${h:4:2}" "0x${h:2:2}" "0x${h:0:2}")")
  fi
  for a in "${cands[@]}"; do
    [[ " ${addrs[*]-} " == *" $a "* ]] || addrs+=("$a")
  done
done < <(tail -n +2 /proc/net/udp)
if [ "${#addrs[@]}" = 0 ]; then
  echo "unhealthy: nothing is bound to UDP port $port" >&2
  exit 1
fi

ask() {  # address, a printf format of the request -> the reply's first 18 bytes, in hex
  { exec 3<>"/dev/udp/$1/$port"; } 2>/dev/null || return 0
  # shellcheck disable=SC2059   # the request is a printf format on purpose: \xHH escapes
  printf "$2" >&3
  timeout 1.5 head -c 18 <&3 | od -An -v -tx1 | tr -d ' \n'
  exec 3>&-
}

for try in 1 2; do
  for a in "${addrs[@]}"; do
    r=$(ask "$a" "$req")
    if [ "$r" = "$status" ]; then
      echo "healthy: the game answered getstatus on $a:$port"
      exit 0
    fi
  done
  [ "$try" = 1 ] && sleep 1
done
echo "unhealthy: a socket is bound to UDP port $port (${addrs[*]}), and no statusResponse came" >&2
exit 1
}
