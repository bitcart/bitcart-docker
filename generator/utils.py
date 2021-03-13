import os


def env(name, default=None):
    value = os.getenv(f"BITCART_{name}", default)
    if not value:  # additional checks for empty values
        value = default
    return value


def custom_port_allowed(service):
    from .constants import CRYPTO_COMPONENTS

    return service not in CRYPTO_COMPONENTS or env(f"{service.upper()}_EXPOSE", False)


def preferred_service(components):
    from .constants import HOST_COMPONENTS

    for variant in HOST_COMPONENTS:
        if components.get(variant):
            return variant


class ModifyKey:
    def __init__(self, services, service, key, default={}, save_key=None):
        self.services = services
        self.service = service
        self.key = key
        self.default = default
        self.save_key = save_key or key
        self.key_exists = self.services.get(self.service)
        self.copied = self.default

    def __enter__(self):
        if self.key_exists:
            self.copied = self.services[self.service].get(self.key, self.default).copy()
        return self.copied

    def __exit__(self, *args, **kwargs):
        if self.key_exists:
            self.services[self.service][self.save_key] = self.copied


modify_key = ModifyKey
