"""A stand-in that speaks just enough idTech3 to test tools/healthcheck.sh and
tools/rcon.sh. Not a server.

    python3 fake-getstatus.py <mode> <port> <bind>

mode   answers    statusResponse to every getstatus; rcon answered as idTech3
                  does: "print" and the status table for the password in the
                  RCON_PASSWORD file, "Bad rconpassword." for any other
       silent     binds the port and never answers
       noloop     answers, except a query from 127.0.0.1, as a server bound
                  to 0.0.0.0 may
       slow       answers, two seconds late (rcon.sh is sampled meanwhile)
bind   an address, or "iface" for the container's own interface address
"""
import os
import socket
import sys
import time

mode, port, bind = sys.argv[1], int(sys.argv[2]), sys.argv[3]
if bind == "iface":
    bind = socket.gethostbyname(socket.gethostname())
password = ""
if os.path.exists("/rcon-password"):
    password = open("/rcon-password").read().strip()
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind((bind, port))
print("bound", bind, port, flush=True)
OOB = b"\xff\xff\xff\xff"
while True:
    data, peer = s.recvfrom(1400)
    if mode == "silent" or (mode == "noloop" and peer[0] == "127.0.0.1"):
        continue
    if mode == "slow":
        time.sleep(2)
    if data.startswith(OOB + b"getstatus"):
        s.sendto(OOB + b"statusResponse\n\\sv_hostname\\stand-in\\mapname\\mp/ffa3\n", peer)
    elif data.startswith(OOB + b"rcon "):
        parts = data[len(OOB) + 5:].decode(errors="replace").split(" ", 1)
        if password and parts[0] == password:
            s.sendto(OOB + b"print\nmap: mp/ffa3\nnum score ping name\n", peer)
        else:
            s.sendto(OOB + b"print\nBad rconpassword.\n", peer)
