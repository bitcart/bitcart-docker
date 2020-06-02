import os
from constants import CRYPTO_COMPONENTS


def env(name, default=None):
    value = os.getenv(f"BITCART_{name}", default)
    if not value:  # additional checks for empty values
        value = default
    return value


def custom_port_allowed(service):
    return service not in CRYPTO_COMPONENTS or env(f"{service.upper()}_EXPOSE", False)
