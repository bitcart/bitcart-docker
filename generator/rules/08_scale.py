from generator.utils import env, modify_key


def rule(services, settings):
    for i in services:
        try:
            scale = int(env(f"{i.upper()}_SCALE", "1"))
        except ValueError:
            continue
        if scale != 1:
            with modify_key(services, i, "deploy") as deploy:
                deploy["replicas"] = scale
