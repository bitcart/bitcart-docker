from generator.utils import env, modify_key


def rule(services, settings):
    if not env("REVERSEPROXY_PROXYPROTOCOL", prefix=""):
        return
    if not services.get("nginx"):  # pragma: no cover
        return
    with modify_key(services, "nginx", "ports", []) as ports:
        ports.append("${REVERSEPROXY_PROXYPROTOCOL_PORT:-10082}:10082")
