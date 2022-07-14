from ..constants import CRYPTO_COMPONENTS, HOST_COMPONENTS
from ..utils import custom_port_allowed, env, modify_key


def rule(services, settings):
    no_nginx = not services.get("nginx")
    custom_web_services = [
        key for key, service in services.items() if service.get("environment", {}).get("BITCART_WEBSERVICE", False)
    ]
    items = HOST_COMPONENTS + CRYPTO_COMPONENTS + custom_web_services
    for i in items:
        if services.get(i) and custom_port_allowed(i, no_nginx):
            with modify_key(services, i, "expose", [], "ports") as expose:
                custom_port = env(f"{i.upper()}_PORT")
                for key, port in enumerate(expose):
                    expose[key] = f"{custom_port or port}:{port}"
