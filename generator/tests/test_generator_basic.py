import pytest

from generator.generator import load_component

THIRD_PARTY_IMAGES = ["nginx", "redis", "database", "letsencrypt-nginx-proxy-companion"]


def test_basic_structure(config):
    assert isinstance(config, dict)
    assert config.keys() == {"version", "services", "networks", "volumes"}
    assert config["version"] == "3"
    assert isinstance(config["services"], dict)
    assert isinstance(config["networks"], dict)
    assert isinstance(config["volumes"], dict)
    assert not config["networks"]
    assert not all(config["volumes"].values())  # all values are None
    assert len(config["services"]) > 0
    assert len(config["volumes"]) > 0


def check_service(service, service_data, full_service=True):
    assert isinstance(service_data, dict)
    assert len(service_data.keys()) > 0
    if full_service:
        assert service_data.keys() >= {"restart", "image"}
        assert service in THIRD_PARTY_IMAGES or "bitcartcc" in service_data["image"]
        assert service_data["restart"] == "unless-stopped"
        # Pin versions
        assert ":" in service_data["image"]
    check_additional_keys(service, service_data)


def check_key(service, service_data, key, key_type=list, value_type=str):
    if key in service_data:
        assert isinstance(service_data[key], key_type)
        if key_type == list:
            assert all(isinstance(value, value_type) for value in service_data[key])


def check_additional_keys(service, service_data):
    check_key(service, service_data, "expose")
    check_key(service, service_data, "ports")
    check_key(service, service_data, "links")
    check_key(service, service_data, "depends_on")
    check_key(service, service_data, "volumes")
    check_key(service, service_data, "command", str)
    check_key(service, service_data, "entrypoint", str)
    if "environment" in service_data:
        assert isinstance(service_data["environment"], dict)
        for key, value in service_data["environment"].items():
            assert isinstance(key, str) and value is None or isinstance(value, (str, int))


@pytest.mark.parametrize(
    "service",
    [
        "admin",
        "backend",
        "bitcoin",
        "database",
        "letsencrypt-nginx-proxy-companion",
        "nginx",
        "nginx-gen",
        "redis",
        "store",
        "worker",
    ],
)
def test_default_services(config, service):
    services = config["services"]
    assert service in services
    check_service(service, services[service])


def test_all_components(all_components):
    for component in all_components:
        component_data = load_component(component)
        assert isinstance(component_data, dict)
        assert component_data.keys() >= {"services"}
        services = component_data["services"]
        for service in services:
            check_service(service, services[service], full_service=service == component)
