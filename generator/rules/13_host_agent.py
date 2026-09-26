from generator.utils import modify_key

AGENT_DIR = "/run/bitcart-agent"


def worker_connection(settings):
    if settings.AGENT_TRANSPORT == "systemd":
        return "unix:///run/bitcart-agent/agent.sock", f"/run/bitcart{'-' + settings.NAME if settings.NAME else ''}"
    if settings.AGENT_TRANSPORT == "launchd":
        return f"tcp://host.docker.internal:{settings.AGENT_PORT}", None
    if settings.AGENT_TRANSPORT == "ssh":
        return f"ssh://root@host.docker.internal:{settings.SSH_PORT}", f"{settings.BASE_DIRECTORY}/.agent/ssh"
    return None, None


def rule(services, settings):
    url, mount = worker_connection(settings)
    if not url:
        return
    with modify_key(services, "worker", "environment") as environment:
        environment["BITCART_AGENT_URL"] = url
        if url.startswith("tcp://"):
            environment["BITCART_AGENT_TOKEN"] = "${BITCART_AGENT_TOKEN}"  # noqa: S105
        if url.startswith("ssh://"):
            environment["BITCART_AGENT_SSH_KEY_FILE"] = f"{AGENT_DIR}/id_ed25519"
    if mount:
        with modify_key(services, "worker", "volumes", []) as volumes:
            volumes.append(f"{mount}:{AGENT_DIR}{':ro' if url.startswith('ssh://') else ''}")
    if url.startswith(("tcp://", "ssh://")):
        with modify_key(services, "worker", "extra_hosts", []) as extra_hosts:
            extra_hosts.append("host.docker.internal:host-gateway")
