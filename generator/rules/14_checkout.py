from os.path import join as urljoin

from generator.utils import config_error, modify_key


def rule(services, settings):
    if not services.get("checkout"):
        return
    if not services.get("nginx") or not (services.get("admin") or (settings.ONE_DOMAIN_MODE and services.get("store"))):
        config_error(
            "The checkout component is served on the admin host through the bundled nginx. "
            "Enable the admin component and the nginx or nginx-https reverse proxy."
        )
    if not settings.ONE_DOMAIN_MODE:
        return
    with modify_key(services, "checkout", "environment") as environment:
        environment["BITCART_API_URL"] = urljoin(settings.API_URL, "api")
        environment["ONE_DOMAIN_MODE"] = "true"
    for service in ("backend", "worker"):
        with modify_key(services, service, "environment") as environment:
            environment["BITCART_CHECKOUT_URL"] = settings.API_URL
