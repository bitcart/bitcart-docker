from generator.utils import env


def rule(services, settings):
    version = env("VERSION", "stable")
    for i in services:
        if "image" in services[i]:
            parts = services[i]["image"].split(":")
            if len(parts) == 2 and parts[1] == "stable" and parts[0].startswith("bitcart/"):
                services[i]["image"] = parts[0] + f":{version}"
