from generator.utils import modify_key, public_api_url


def rule(services, settings):
    if settings.ONE_DOMAIN_MODE:
        return
    api_url = public_api_url(services, settings)
    if not api_url:
        return
    for service, override in (("admin", settings.ADMIN_API_URL), ("store", settings.STORE_API_URL)):
        if not override:
            with modify_key(services, service, "environment") as environment:
                environment[f"BITCART_{service.upper()}_API_URL"] = api_url
