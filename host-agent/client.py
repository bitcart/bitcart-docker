import os
import socket
import sys
from urllib.parse import urlsplit

url = urlsplit(os.environ["BITCART_AGENT_URL"])
fields = sys.argv[1:]
if url.scheme == "tcp":
    fields.append("auth=" + os.environ["BITCART_AGENT_TOKEN"])
request = b"".join(field.encode() + b"\0" for field in fields) + b"\0"

if url.scheme == "ssh":
    import paramiko  # type: ignore[import]

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        url.hostname,
        port=url.port or 22,
        username=url.username,
        key_filename=os.environ["BITCART_AGENT_SSH_KEY_FILE"],
        allow_agent=False,
        look_for_keys=False,
        timeout=30,
    )
    stdin, stdout, _ = client.exec_command("bitcart-agent", timeout=60)
    stdin.write(request)
    stdin.channel.shutdown_write()
    reply = stdout.read()
    client.close()
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
