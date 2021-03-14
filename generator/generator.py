import glob
import importlib
import sys
from collections import UserDict
from os.path import basename, exists, isfile
from os.path import join as path_join
from typing import Union

import oyaml as yaml

from .constants import (
    BACKEND_COMPONENTS,
    COMPONENTS_DIR,
    CRYPTO_COMPONENTS,
    CRYPTOS,
    FRONTEND_COMPONENTS,
    GENERATED_PATH,
    RULES_DIR,
    RULES_PYTHON_DIR,
    RULES_PYTHON_PKG,
)
from .settings import Settings
from .utils import ConfigError


class OrderedSet(UserDict):
    def add(self, v):
        self.data[v] = None

    def update(self, *args, **kwargs):
        for s in args:
            for e in s:
                self.add(e)

    def __repr__(self):
        return f"{{{', '.join(map(repr, self.data.keys()))}}}"


def add_components(settings: Settings) -> OrderedSet:
    components = OrderedSet()
    # add daemons
    for crypto in settings.CRYPTOS:
        if crypto:
            value = CRYPTOS.get(crypto)
            if value:
                components.add(value["component"])
    # installation packs
    if settings.INSTALLATION_PACK == "all":
        components.update(BACKEND_COMPONENTS + FRONTEND_COMPONENTS)
    elif settings.INSTALLATION_PACK == "backend":
        components.update(BACKEND_COMPONENTS)
    elif settings.INSTALLATION_PACK == "frontend":
        components.update(FRONTEND_COMPONENTS)
    # reverse proxy
    if settings.REVERSE_PROXY == "nginx-https":
        components.update(["nginx", "nginx-https"])
    elif settings.REVERSE_PROXY == "nginx":
        components.update(["nginx"])
    # additional components
    components.update(settings.ADDITIONAL_COMPONENTS)
    # Add bitcoin if no valid cryptos specified
    HAS_CRYPTO = False
    for i in components:
        if i in CRYPTO_COMPONENTS:
            HAS_CRYPTO = True
            break
    if not HAS_CRYPTO:
        components.add(CRYPTOS["btc"]["component"])
    return components


def load_component(component: str):
    path = path_join(COMPONENTS_DIR, component + ".yml")
    if not exists(path):
        return {}
    with open(path) as f:
        data = yaml.load(f, Loader=yaml.SafeLoader)
        return data or {}


def _merge(a, b, path=None):
    if path is None:
        path = []
    for key in b:
        if key in a:
            if isinstance(a[key], dict) and isinstance(b[key], dict):
                _merge(a[key], b[key], path + [str(key)])
            elif isinstance(a[key], list) and isinstance(b[key], list):
                a[key] += b[key]
        else:
            a[key] = b[key]
    return a


def merge(services):
    new = []
    for i in services:
        for j in i:
            new.append({j: i[j]})
    d = {}
    new = sorted(new, key=lambda x: list(x)[0])
    for i in new:
        key = list(i)[0]
        try:
            _merge(d[key], i[key])
        except KeyError:
            d[key] = i[key]
    return d


def load_rules():
    modules = sorted(glob.glob(path_join(RULES_DIR, "*.py")))
    loaded = [
        importlib.import_module(f"{RULES_PYTHON_DIR}." + basename(f)[:-3], RULES_PYTHON_PKG) for f in modules if isfile(f)
    ]
    for i in loaded.copy():
        if not getattr(i, "rule", None) or not callable(i.rule):
            loaded.remove(i)
    return loaded


def execute_rules(rules, services, settings):
    for i in rules:
        i.rule(services, settings)


def generate(components: OrderedSet, settings: Settings):
    # generated yaml
    services: Union[dict, list] = []
    networks: Union[dict, list] = []
    volumes: Union[dict, list] = []
    for i in components:
        doc = load_component(i)
        if doc.get("services"):
            services.append(doc["services"])
        if doc.get("networks"):  # pragma: no cover
            networks.append(doc["networks"])
        if doc.get("volumes"):
            volumes.append(doc["volumes"])
    services = merge(services)
    rules = load_rules()
    execute_rules(rules, services, settings)
    networks = {j: i[j] for i in networks for j in i}
    volumes = {j: i[j] for i in volumes for j in i}
    data = {
        "version": "3",
        "services": services,
        "networks": networks,
        "volumes": volumes,
    }
    return data


def save(data, out_path=GENERATED_PATH):
    with open(out_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False)


def generate_config():
    settings = Settings()
    return generate(add_components(settings), settings)


def main():  # pragma: no cover
    try:
        save(generate_config())
    except ConfigError as e:
        sys.exit(str(e))


if __name__ == "__main__":  # pragma: no cover
    main()
