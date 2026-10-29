from generator.utils import config_error, modify_key, public_api_url


def rule(services, settings):
    if not services.get("checkout"):
        return
    if not services.get("nginx") or not (settings.ONE_DOMAIN_MODE or settings.CHECKOUT_HOST):
        config_error(
            "The checkout is served by the bundled nginx: on BITCART_HOST in one domain mode, "
            "otherwise on BITCART_CHECKOUT_HOST. Enable nginx or nginx-https and set BITCART_CHECKOUT_HOST if needed."
        )
    checkout_url = settings.HOST_URL if settings.ONE_DOMAIN_MODE else settings.CHECKOUT_URL
    with modify_key(services, "checkout", "environment") as environment:
        environment["BITCART_API_URL"] = public_api_url(services, settings)
        environment["BITCART_CHECKOUT_URL"] = checkout_url
        if settings.ONE_DOMAIN_MODE:
            environment["ONE_DOMAIN_MODE"] = "true"
        else:
            environment["VIRTUAL_HOST"] = settings.CHECKOUT_HOST
            environment["LETSENCRYPT_HOST"] = settings.CHECKOUT_HOST
    for service in ("backend", "worker"):
        with modify_key(services, service, "environment") as environment:
            environment["BITCART_CHECKOUT_URL"] = checkout_url
