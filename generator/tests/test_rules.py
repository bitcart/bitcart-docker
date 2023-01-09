from generator.constants import CRYPTO_COMPONENTS, HOST_COMPONENTS, TOR_CRYPTOS
from generator.generator import generate_config

from .utils import delete_env, set_env


# Rule 1
def test_no_image_rule(config):
    for service in config["services"].values():
        assert service.get("image") or service.get("build")


# Rules 2 and 3: one_domain and root_path
def check_one_domain_setting(name):
    set_env(name, "something")
    assert "ONE_DOMAIN_MODE" not in generate_config()["services"]["store"]["environment"]
    # Cleanup
    delete_env(name)


def check_preferred(services, preferred_service):
    for service in HOST_COMPONENTS:
        if services.get(service):
            if service == preferred_service:
                assert "VIRTUAL_HOST" in services[service]["environment"]
            else:
                assert "VIRTUAL_HOST" not in services[service]["environment"]


def check_root_path(services, service, value):
    if value is None:
        assert service not in services
        return
    root_path = services[service]["environment"][f"BITCART_{service.upper()}_ROOTPATH"]
    default = root_path.split(":-")[1].replace("}", "")
    if value != "/":
        assert default == value
    else:
        assert default in ["/", ""]


def test_one_domain_rule():
    services = generate_config()["services"]
    for service in HOST_COMPONENTS:
        if services.get(service):
            assert services[service]["environment"]["ONE_DOMAIN_MODE"] == "true"
    check_one_domain_setting("REVERSEPROXY")
    check_one_domain_setting("ADMIN_HOST")
    check_one_domain_setting("STORE_HOST")
    check_one_domain_setting("ADMIN_API_URL")
    check_one_domain_setting("STORE_API_URL")
    # Check preferred service setting
    # Store preferred
    check_preferred(services, "store")
    check_root_path(services, "store", "/")
    check_root_path(services, "admin", "/admin")
    check_root_path(services, "backend", "/api")
    # Admin preferred
    set_env("INSTALL", "backend")
    set_env("ADDITIONAL_COMPONENTS", "admin")
    services = generate_config()["services"]
    check_preferred(services, "admin")
    check_root_path(services, "store", None)
    check_root_path(services, "admin", "/")
    check_root_path(services, "backend", "/api")
    # Backend preferred
    delete_env("ADDITIONAL_COMPONENTS")
    set_env("INSTALL", "backend")
    services = generate_config()["services"]
    check_preferred(services, "backend")
    check_root_path(services, "store", None)
    check_root_path(services, "admin", None)
    check_root_path(services, "backend", "/")
    # Cleanup
    delete_env("INSTALL")


# Rule 4
def check_no_ports(services, ports_components):
    for service in services:
        if service in ports_components:
            assert "ports" not in services[service]


def test_no_reverseproxy_rule():
    ports_components = HOST_COMPONENTS + CRYPTO_COMPONENTS
    services = generate_config()["services"]
    check_no_ports(services, ports_components)
    set_env("REVERSEPROXY", "nginx")
    services = generate_config()["services"]
    check_no_ports(services, ports_components)
    set_env("REVERSEPROXY", "none")
    services = generate_config()["services"]
    for service in services:
        if service in ports_components:
            if service in HOST_COMPONENTS:
                assert "ports" in services[service]
            if service in CRYPTO_COMPONENTS:
                assert "ports" not in services[service]
    # check that it works even with nginx on
    delete_env("REVERSEPROXY")
    set_env("BITCOIN_EXPOSE", "true")
    services = generate_config()["services"]
    assert "ports" in services["bitcoin"]
    # Cleanup
    delete_env("BITCOIN_EXPOSE")


# Rule 5
def test_frontend_rule():
    # Backend, store, admin
    services = generate_config()["services"]
    assert services["admin"]["links"] == ["backend"]
    assert services["store"]["links"] == ["backend"]
    # Backend, admin
    set_env("INSTALL", "backend")
    set_env("ADDITIONAL_COMPONENTS", "admin")
    services = generate_config()["services"]
    assert services["admin"]["links"] == ["backend"]
    assert "store" not in services
    # Backend, store
    set_env("ADDITIONAL_COMPONENTS", "store")
    services = generate_config()["services"]
    assert services["store"]["links"] == ["backend"]
    assert "admin" not in services
    # Store, admin
    set_env("INSTALL", "frontend")
    delete_env("ADDITIONAL_COMPONENTS")
    set_env("ADMIN_API_URL", "test")
    services = generate_config()["services"]
    assert "links" not in services["admin"]
    assert "links" not in services["store"]
    # Nothing
    set_env("INSTALL", "none")
    delete_env("ADMIN_API_URL")
    services = generate_config()["services"]
    assert "store" not in services
    assert "admin" not in services
    # Cleanup
    delete_env("INSTALL")


# Rule 6
def test_tor_rule():
    services = generate_config()["services"]
    assert "tor" not in services
    set_env("ADDITIONAL_COMPONENTS", "tor")
    services = generate_config()["services"]
    assert "tor" in services
    for env_name, service in TOR_CRYPTOS.items():
        if services.get(service["component"]):
            assert f"{env_name.upper()}_PROXY_URL" in services[service["component"]]["environment"]
    for service in services:
        if service in HOST_COMPONENTS:
            assert services[service]["environment"]["HIDDENSERVICE_REVERSEPROXY"] == "compose-nginx-1"
    set_env("REVERSEPROXY", "none")
    services = generate_config()["services"]
    for service in services:
        if service in HOST_COMPONENTS:
            assert "HIDDENSERVICE_IP" in services[service]["environment"]
            assert (
                services[service]["environment"]["HIDDENSERVICE_VIRTUAL_PORT"]
                == services[service]["environment"]["VIRTUAL_PORT"]
            )
    # Cleanup
    delete_env("ADDITIONAL_COMPONENTS")
    delete_env("REVERSEPROXY")


# Rule 8
def test_scale():
    services = generate_config()["services"]
    assert "deploy" not in services["backend"]
    set_env("BACKEND_SCALE", "2")
    services = generate_config()["services"]
    assert services["backend"]["deploy"]["replicas"] == 2
    set_env("BACKEND_SCALE", "test")
    services = generate_config()["services"]
    assert "deploy" not in services["backend"]
    # Cleanup
    delete_env("BACKEND_SCALE")


# Rule 9: allow using older versions
def test_bitcart_version():
    services = generate_config()["services"]
    for service in ("backend", "admin", "store", "bitcoin", "worker"):
        assert services[service]["image"].endswith(":stable")
    set_env("VERSION", "test")
    services = generate_config()["services"]
    for service in ("backend", "admin", "store", "bitcoin", "worker"):
        assert services[service]["image"].endswith(":test")
    delete_env("VERSION")
