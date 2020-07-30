import os

from constants import CRYPTO_COMPONENTS


def env(name, default=None):
    value = os.getenv(f"BITCART_{name}", default)
    if not value:  # additional checks for empty values
        value = default
    return value


def custom_port_allowed(service):
    return service not in CRYPTO_COMPONENTS or env(f"{service.upper()}_EXPOSE", False)


class ModifyKey:
    def __init__(self, data, key, default={}, save_key=None):
        self.data = data
        self.key = key
        self.default = default
        self.save_key = save_key or key

    def __enter__(self):
        self.copied = self.data.get(self.key, self.default).copy()
        return self.copied

    def __exit__(self, *args, **kwargs):
        self.data[self.save_key] = self.copied


modify_key = ModifyKey
