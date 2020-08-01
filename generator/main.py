import glob
import importlib
import shutil
from collections import UserDict
from os.path import basename, exists, isfile
from os.path import join as path_join
from shlex import shlex
from typing import Union

import oyaml as yaml

from constants import (
    BACKEND_COMPONENTS,
    COMPONENTS_DIR,
    COMPOSE_DIR,
    CRYPTO_COMPONENTS,
    CRYPTOS,
    FRONTEND_COMPONENTS,
    GENERATED_NAME,
    RULES_DIR,
    RULES_PYTHON_DIR,
    RULES_PYTHON_PKG,
)
from utils import env


class OrderedSet(UserDict):
    def add(self, v):
        self.data[v] = None

    def update(self, *args, **kwargs):
        for s in args:
            for e in s:
                self.add(e)

    def __repr__(self):
        return f"{{{', '.join(map(repr, self.data.keys()))}}}"


def add_components() -> OrderedSet:
    components = OrderedSet()
    # add daemons
    cryptos = env("CRYPTOS", "btc")
    splitter = shlex(cryptos, posix=True)
    splitter.whitespace = ","
    splitter.whitespace_split = True
    cryptos = [item.strip() for item in splitter]
    for crypto in cryptos:
        if crypto:
            value = CRYPTOS.get(crypto)
            if value:
                components.add(value["component"])
    # bitcart backend and frontend
    to_install = env("INSTALL", "all")
    if to_install == "all":
        components.update(BACKEND_COMPONENTS + FRONTEND_COMPONENTS)
    elif to_install == "backend":
        components.update(BACKEND_COMPONENTS)
    elif to_install == "frontend":
        components.update(FRONTEND_COMPONENTS)
    # reverse proxy
    reverseproxy = env("REVERSEPROXY", "nginx-https")
    if reverseproxy == "nginx-https":
        components.update(["nginx", "nginx-https"])
    elif reverseproxy == "nginx":
        components.update(["nginx"])
    # additional components
    additional_components = env("ADDITIONAL_COMPONENTS", "")
    splitter = shlex(additional_components, posix=True)
    splitter.whitespace = ","
    splitter.whitespace_split = True
    components.update([item.strip() for item in splitter])
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
            elif a[key] == b[key]:
                pass
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
    modules = glob.glob(path_join(RULES_DIR, "*.py"))
    loaded = [
        importlib.import_module(
            f"{RULES_PYTHON_DIR}." + basename(f)[:-3], RULES_PYTHON_PKG
        )
        for f in modules
        if isfile(f) and not f.endswith("__init__.py")
    ]
    for i in loaded.copy():
        if not getattr(i, "rule", None) or not callable(i.rule):
            loaded.remove(i)
    return loaded


def execute_rules(rules, services):
    for i in rules:
        i.rule(services)


def generate(components: OrderedSet):
    # generated yaml
    services: Union[dict, list] = []
    networks: Union[dict, list] = []
    volumes: Union[dict, list] = []
    for i in components:
        doc = load_component(i)
        if doc.get("services"):
            services.append(doc["services"])  # type: ignore
        if doc.get("networks"):
            networks.append(doc["networks"])  # type: ignore
        if doc.get("volumes"):
            volumes.append(doc["volumes"])  # type: ignore
    services = merge(services)
    rules = load_rules()
    execute_rules(rules, services)
    networks = {j: i[j] for i in networks for j in i}
    volumes = {j: i[j] for i in volumes for j in i}
    data = {
        "version": "3",
        "services": services,
        "networks": networks,
        "volumes": volumes,
    }
    with open(path_join(COMPOSE_DIR, GENERATED_NAME), "w") as f:
        yaml.dump(data, f, default_flow_style=False)


components = add_components()
generate(components)
