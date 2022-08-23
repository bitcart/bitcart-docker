from ..constants import HOST_COMPONENTS, TOR_CRYPTOS
from ..utils import modify_key


def rule(services, settings):
    items = HOST_COMPONENTS
    has_nginx = services.get("nginx")
    if services.get("tor"):
        for i in items:
            if services.get(i):
                with modify_key(services, i, "environment") as environment:
                    if has_nginx:
                        environment["HIDDENSERVICE_REVERSEPROXY"] = "$<DEPLOYENT_NAME>?-nginx-1"
                    else:
                        environment["HIDDENSERVICE_IP"] = "172.17.0.1"
                        environment["HIDDENSERVICE_VIRTUAL_PORT"] = int(environment.get("VIRTUAL_PORT", "80"))
        for env_name, service in TOR_CRYPTOS.items():
            service_name = service["component"]
            if services.get(service_name):
                with modify_key(services, service_name, "environment") as environment:
                    environment[f"{env_name.upper()}_PROXY_URL"] = "socks5://tor:9050"
