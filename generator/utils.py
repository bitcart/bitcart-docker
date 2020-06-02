import os


def env(name, default=None):
    value = os.getenv(f"BITCART_{name}", default)
    if not value:  # additional checks for empty values
        value = default
    return value
