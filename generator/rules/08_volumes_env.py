from ..utils import modify_key


def rule(services, settings):
    for i in services:
        with modify_key(services, i, "environment") as environment:
            volumes = list(
                map(lambda x: x.split(":")[1], filter(lambda x: not x.startswith("/"), services[i].get("volumes", [])))
            )
            environment["BITCART_VOLUMES"] = " ".join(volumes)
