def rule(services, settings):
    store = services.get("store")
    admin = services.get("admin")
    backend = services.get("backend")
    if backend:
        if store:
            store["links"] = ["backend"]
        if admin:
            admin["links"] = ["backend"]
