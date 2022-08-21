import pytest

from generator.exceptions import ConfigError
from generator.generator import generate_config
from generator.settings import Settings

from .utils import check_service_list, delete_env, set_env


@pytest.mark.parametrize(
    "pack, expected",
    [
        ("all", ["backend", "admin", "store"]),
        ("backend", ["backend"]),
        ("none", ["backend", "admin", "store"]),
    ],
    ids=["all", "backend", "none"],
)
def test_installation_packs(pack, expected):
    set_env("INSTALL", pack)
    config = generate_config()
    check_service_list(config, expected, is_none=pack == "none")
    # Cleanup
    delete_env("INSTALL")


# Frontend pack requires one domain mode to be off
def test_frontend_pack():
    set_env("INSTALL", "frontend")
    with pytest.raises(ConfigError):
        generate_config()
    set_env("ADMIN_API_URL", "http://localhost:8000")
    set_env("STORE_API_URL", "http://localhost:8000")
    config = generate_config()
    check_service_list(config, ["admin", "store"])
    # Cleanup
    delete_env("INSTALL")
    delete_env("ADMIN_API_URL")
    delete_env("STORE_API_URL")


@pytest.mark.parametrize(
    "proxy, expected",
    [
        ("nginx-https", ["nginx", "nginx-https"]),
        ("nginx", ["nginx"]),
        ("none", ["nginx", "nginx-https"]),
    ],
    ids=["nginx-https", "nginx", "none"],
)
def test_reverse_proxy(proxy, expected):
    set_env("REVERSEPROXY", proxy)
    config = generate_config()
    check_service_list(config, expected, is_none=proxy == "none")
    # Cleanup
    delete_env("REVERSEPROXY")


def test_no_cryptos():
    set_env("CRYPTOS", "invalid")
    assert "bitcoin" in generate_config()["services"]
    # Cleanup
    delete_env("CRYPTOS")


def test_additional_components_basic():
    set_env("ADDITIONAL_COMPONENTS", "invalid")
    assert "invalid" not in generate_config()["services"]
    set_env("ADDITIONAL_COMPONENTS", "test1;test2")
    assert Settings().ADDITIONAL_COMPONENTS == ["test1;test2"]
    set_env("ADDITIONAL_COMPONENTS", "test1,test2")
    assert Settings().ADDITIONAL_COMPONENTS == ["test1", "test2"]
    # Cleanup
    delete_env("ADDITIONAL_COMPONENTS")


@pytest.mark.parametrize(
    "component, expected",
    [
        ("tor", ["tor", "tor-gen"]),
        ("", ["tor", "tor-gen"]),
    ],
    ids=["tor", "none"],
)
def test_additional_components(component, expected):
    set_env("ADDITIONAL_COMPONENTS", component)
    config = generate_config()
    check_service_list(config, expected, is_none=not component)
    # Cleanup
    delete_env("ADDITIONAL_COMPONENTS")


def test_exclude_components_basic():
    set_env("EXCLUDE_COMPONENTS", "invalid")
    assert "invalid" not in generate_config()["services"]
    set_env("EXCLUDE_COMPONENTS", "test1;test2")
    assert Settings().EXCLUDE_COMPONENTS == ["test1;test2"]
    set_env("EXCLUDE_COMPONENTS", "test1,test2")
    assert Settings().EXCLUDE_COMPONENTS == ["test1", "test2"]
    # Cleanup
    delete_env("EXCLUDE_COMPONENTS")


@pytest.mark.parametrize(
    "component, expected",
    [
        ("admin", ["admin"]),
        ("", ["admin"]),
        ("admin,store", ["admin", "store"]),
        ("", ["admin", "store"]),
    ],
    ids=["admin-empty", "admin", "admin-store-empty", "admin-store"],
)
def test_exclude_components(component, expected):
    set_env("EXCLUDE_COMPONENTS", component)
    config = generate_config()
    check_service_list(config, expected, is_none=bool(component))
    # Cleanup
    delete_env("EXCLUDE_COMPONENTS")


def test_https_hint():
    set_env("HTTPS_ENABLED", "true")
    set_env("REVERSEPROXY", "nginx")
    config = generate_config()
    assert "letsencrypt-nginx-proxy-companion" not in config["services"]
    assert config["services"]["admin"]["environment"]["BITCART_ADMIN_API_URL"].startswith("https://")
    # Cleanup
    delete_env("HTTPS_ENABLED")
    delete_env("REVERSEPROXY")
