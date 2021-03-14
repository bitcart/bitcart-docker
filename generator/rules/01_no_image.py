def rule(services, settings):
    for i in services.copy():
        item = services[i]
        if not item.get("image") and not item.get("build"):
            del services[i]
