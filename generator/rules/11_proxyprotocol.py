from generator.utils import env, modify_key


def rule(services, settings):
    if not env("REVERSEPROXY_PROXYPROTOCOL", prefix=""):
        return
    if not services.get("nginx"):  # pragma: no cover
        return
    with modify_key(services, "nginx", "ports", []) as ports:
        ports.append("${REVERSEPROXY_PROXYPROTOCOL_HTTP_PORT:-10082}:10082")
        ports.append("${REVERSEPROXY_PROXYPROTOCOL_HTTPS_PORT:-10083}:10083")
