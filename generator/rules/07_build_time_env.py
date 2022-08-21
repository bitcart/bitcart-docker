import re

from ..constants import ENV_PREFIX
from ..utils import apply_recursive, env

BUILD_TIME_ENV_REGEX = re.compile(r"\$<(.*?)>\?")


def apply_build_time_env(line):
    if not isinstance(line, str):
        return False, line

    to_delete = False

    def load_env_var(match):
        nonlocal to_delete
        env_name = match.group(1)
        # if env_name.startswith(ENV_PREFIX):
        #    env_name = env_name[len(ENV_PREFIX) :]
        value = env(env_name, "", prefix="")
        if not value:
            to_delete = True
        print(env_name, value, to_delete)
        return value

    line = re.sub(BUILD_TIME_ENV_REGEX, load_env_var, line)
    return to_delete, line


def rule(services, settings):
    services.update(apply_recursive(services, apply_build_time_env)[1])
