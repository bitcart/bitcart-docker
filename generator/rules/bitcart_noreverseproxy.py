from constants import CRYPTO_COMPONENTS, HOST_COMPONENTS
from utils import custom_port_allowed, env, modify_key


def rule(services):
    if not services.get("nginx"):
        items = HOST_COMPONENTS + CRYPTO_COMPONENTS
        for i in items:
            if services.get(i) and custom_port_allowed(i):
                with modify_key(services, i, "expose", [], "ports") as expose:
                    custom_port = env(f"{i.upper()}_PORT")
                    for key, port in enumerate(expose):
                        expose[key] = f"{custom_port or port}:{port}"
