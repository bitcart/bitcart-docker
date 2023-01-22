from generator.constants import HOST_COMPONENTS
from generator.utils import modify_key


def rule(services, settings):
    if not settings.HOST or not settings.HOST.endswith(".local"):
        return
    custom_web_services = [
        key for key, service in services.items() if service.get("environment", {}).get("BITCART_WEBSERVICE", False)
    ]
    items = HOST_COMPONENTS + custom_web_services
    for i in items:
        if services.get(i):
            with modify_key(services, i, "extra_hosts", []) as extra_hosts:
                extra_hosts.append(f"{settings.HOST}:172.17.0.1")
