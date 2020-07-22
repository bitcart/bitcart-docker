def rule(services):
    items = ["backend", "store", "admin"]
    has_nginx = services.get("nginx")
    if services.get("tor"):
        for i in items:
            if services.get(i):
                environment = services[i].get("environment", {}).copy()
                if has_nginx:
                    environment["HIDDENSERVICE_REVERSEPROXY"] = "nginx"
                else:
                    environment[
                        "HIDDENSERVICE_IP"
                    ] = "172.17.0.1"  # TODO: check if always available
                services[i]["environment"] = environment
