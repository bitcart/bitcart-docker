from os.path import join as urljoin

from generator.utils import modify_key


def _modify_backend_env(services, service_name, settings, STORE_AVAILABLE, ADMIN_AVAILABLE):
    if not services.get(service_name):
        return
    if service_name == "backend" and (ADMIN_AVAILABLE or STORE_AVAILABLE):
        with modify_key(services, service_name, "environment") as environment:
            environment["BITCART_BACKEND_ROOTPATH"] = environment["BITCART_BACKEND_ROOTPATH"].replace("-}", "-/api}")
    if ADMIN_AVAILABLE:
        with modify_key(services, service_name, "environment") as environment:
            environment["BITCART_ADMIN_HOST"] = settings.HOST or ""
            if STORE_AVAILABLE:
                environment["BITCART_ADMIN_ROOTPATH"] = environment["BITCART_ADMIN_ROOTPATH"].replace("/", "/admin")


def rule(services, settings):
    if not settings.ONE_DOMAIN_MODE:
        return
    API_URL = urljoin(settings.API_URL, "api")
    STORE_AVAILABLE = services.get("store")
    ADMIN_AVAILABLE = services.get("admin")
    # replace defaults
    if STORE_AVAILABLE:
        with modify_key(services, "store", "environment") as environment:
            environment["BITCART_STORE_API_URL"] = API_URL
        if ADMIN_AVAILABLE:
            with modify_key(services, "admin", "environment") as environment:
                environment["BITCART_ADMIN_ROOTPATH"] = environment["BITCART_ADMIN_ROOTPATH"].replace("/", "/admin")
                environment["BITCART_ADMIN_API_URL"] = API_URL
                environment["BITCART_STORE_HOST"] = settings.HOST or ""
            with modify_key(services, "store", "environment") as environment:
                environment["BITCART_ADMIN_HOST"] = urljoin(settings.HOST or "", "admin")
                environment["BITCART_ADMIN_ROOTPATH"] = environment["BITCART_ADMIN_ROOTPATH"].replace("/", "/admin")
    elif ADMIN_AVAILABLE:
        with modify_key(services, "admin", "environment") as environment:
            environment["BITCART_ADMIN_API_URL"] = API_URL
    _modify_backend_env(services, "backend", settings, STORE_AVAILABLE, ADMIN_AVAILABLE)
    _modify_backend_env(services, "worker", settings, STORE_AVAILABLE, ADMIN_AVAILABLE)
