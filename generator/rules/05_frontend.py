def rule(services):
    store = services.get("store")
    admin = services.get("admin")
    back = services.get("backend")
    if back and store:
        store["links"] = ["backend"]
    if back and admin:
        admin["links"] = ["backend"]
