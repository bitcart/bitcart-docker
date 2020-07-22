def rule(services):
    if services.get("tor") and services.get("nginx"):
        for i in ["backend", "store", "admin"]:
            if services.get(i):
                environment = services[i].get("environment", []).copy()
                environment["HIDDENSERVICE_REVERSEPROXY"] = "nginx"
                services[i]["environment"] = environment
