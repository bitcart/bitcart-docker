from constants import CRYPTO_COMPONENTS


def rule(services):
    items = ["backend", "frontend"]
    items.extend(CRYPTO_COMPONENTS)
    for i in items:
        if services.get(i):
            services[i]["ports"] = services[i].get("expose", [])
