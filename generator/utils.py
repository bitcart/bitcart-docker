import os

from .constants import CRYPTO_COMPONENTS, ENV_PREFIX, HOST_COMPONENTS
from .exceptions import ConfigError


def env(name, default=None, prefix=None):
    env_prefix = prefix if prefix is not None else ENV_PREFIX
    value = os.getenv(f"{env_prefix}{name}", default)
    if not value:  # additional checks for empty values
        value = default
    return value


def custom_port_allowed(service, no_nginx):
    return (service not in CRYPTO_COMPONENTS and no_nginx) or env(f"{service.upper()}_EXPOSE", False)


def preferred_service(components):
    for variant in HOST_COMPONENTS:
        if components.get(variant):
            return variant


def config_error(message):
    raise ConfigError(f"ERROR: {message}")


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


def apply_recursive(data, func):
    if isinstance(data, dict):
        new_data = {}
        for key, value in data.items():
            to_delete, new = apply_recursive(value, func)
            if not to_delete:
                new_data[key] = new
        return False, new_data
    elif isinstance(data, list):
        new_data = []
        for value in data:
            to_delete, new = apply_recursive(value, func)
            if not to_delete:
                new_data.append(new)
        return False, new_data
    else:
        return func(data)
