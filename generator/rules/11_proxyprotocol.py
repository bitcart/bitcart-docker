from generator.utils import env_bool, modify_key


def rule(services, settings):
    enabled = env_bool("REVERSEPROXY_PROXYPROTOCOL", prefix="")
    with modify_key(services, "nginx-gen", "environment") as environment:
        environment["PROXY_PROTOCOL"] = "true" if enabled else "false"
    if not enabled:
        return
    if not services.get("nginx"):  # pragma: no cover
        return
    with modify_key(services, "nginx", "ports", []) as ports:
        ports.append("${REVERSEPROXY_PROXYPROTOCOL_HTTP_PORT:-10082}:10082")
        ports.append("${REVERSEPROXY_PROXYPROTOCOL_HTTPS_PORT:-10083}:10083")
