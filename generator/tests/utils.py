import os


def set_env(name, value):
    os.environ[f"BITCART_{name}"] = value


def delete_env(name):
    del os.environ[f"BITCART_{name}"]


def check_service_list(config, expected, is_none=False):
    for service in expected:
        if is_none:
            assert service not in config["services"]
        else:
            assert service in config["services"]
