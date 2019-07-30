def rule(services):
    front = services.get("frontend")
    back = services.get("backend")
    if back and front:
        front["links"] = ["backend"]
