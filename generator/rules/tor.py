from constants import CRYPTOS
from utils import modify_key


def rule(services):
    items = ["backend", "store", "admin"]
    has_nginx = services.get("nginx")
    if services.get("tor"):
        for i in items:
            if services.get(i):
                with modify_key(services[i], "environment") as environment:
                    if has_nginx:
                        environment["HIDDENSERVICE_REVERSEPROXY"] = "nginx"
                    else:
                        environment[
                            "HIDDENSERVICE_IP"
                        ] = "172.17.0.1"  # TODO: check if always available
        for env_name, service in CRYPTOS.items():
            service_name = service["component"]
            if services.get(service_name):
                with modify_key(services[service_name], "environment") as environment:
                    environment[f"{env_name.upper()}_PROXY_URL"] = "socks5://tor:9050"
