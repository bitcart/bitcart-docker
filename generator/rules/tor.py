from constants import CRYPTO_COMPONENTS
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
