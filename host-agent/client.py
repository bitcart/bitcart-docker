import os
import socket
import subprocess
import sys
from urllib.parse import urlsplit

url = urlsplit(os.environ["BITCART_AGENT_URL"])
fields = sys.argv[1:]
if url.scheme == "tcp":
    fields.append("auth=" + os.environ["BITCART_AGENT_TOKEN"])
request = b"".join(field.encode() + b"\0" for field in fields) + b"\0"

if url.scheme == "ssh":
    command = [
        "ssh",
        "-i",
        os.environ["BITCART_AGENT_SSH_KEY_FILE"],
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        "-p",
        str(url.port or 22),
        f"{url.username}@{url.hostname}",
    ]
    reply = subprocess.run(
        command, input=request, capture_output=True, timeout=60, check=False
    ).stdout
else:
    if url.scheme == "unix":
        sock = socket.socket(socket.AF_UNIX)
        sock.settimeout(30)
        sock.connect(url.path)
    elif url.scheme == "tcp":
        sock = socket.create_connection((url.hostname, url.port), timeout=30)
    else:
        sys.exit(f"unsupported agent URL scheme {url.scheme}")
    sock.sendall(request)
    reply = sock.makefile("rb").read()
sys.stdout.buffer.write(reply)
