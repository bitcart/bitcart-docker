from ..constants import HOST_COMPONENTS
from ..utils import modify_key
from ..utils import preferred_service as get_pref


def rule(services, settings):
    if not settings.ONE_DOMAIN_MODE:
        return
    for service in HOST_COMPONENTS:
        if services.get(service):
            with modify_key(services, service, "environment") as environment:
                del environment["VIRTUAL_HOST"]
                environment["ONE_DOMAIN_MODE"] = "true"  # strings in yaml
    preferred_service = get_pref(services)
    if preferred_service:
        with modify_key(services, preferred_service, "environment") as environment:
            environment["VIRTUAL_HOST"] = settings.HOST
