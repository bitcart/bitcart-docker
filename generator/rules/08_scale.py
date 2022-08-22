from ..utils import env


def rule(services, settings):
    for i in services:
        try:
            scale = int(env(f"{i.upper()}_SCALE", "1"))
        except ValueError:
            continue
        if scale != 1:
            services[i]["scale"] = scale
