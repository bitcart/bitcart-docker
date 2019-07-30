from constants import CRYPTO_COMPONENTS


def rule(services):
    if not services.get("nginx"):
        items = ["backend", "frontend"]
        items.extend(CRYPTO_COMPONENTS)
        for i in items:
            if services.get(i):
                expose = services[i].get("expose", []).copy()
                for key, port in enumerate(expose):
                    expose[key] = f"{port}:{port}"
                services[i]["ports"] = expose
