from constants import CRYPTO_COMPONENTS


def rule(services):
    if not services.get("nginx"):
        items = ["backend", "frontend"]
        items.extend(CRYPTO_COMPONENTS)
        for i in items:
            if services.get(i):
                services[i]["ports"] = services[i].get("expose", [])
