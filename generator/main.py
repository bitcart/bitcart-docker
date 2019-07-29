import shutil
from os import getenv
from os.path import join as path_join, exists
from typing import List, Set, Set

import oyaml as yaml

COMPOSE_DIR = 'compose' if getenv("IN_DOCKER") else '../compose'
BACKEND = path_join(COMPOSE_DIR, 'backend-compose.yml')
FRONTEND = path_join(COMPOSE_DIR, 'frontend-compose.yml')
BACKEND_DEV = path_join(COMPOSE_DIR, 'backend-compose.dev.yml')
FRONTEND_DEV = path_join(COMPOSE_DIR, 'frontend-compose.dev.yml')
COMPONENTS_DIR = 'docker-components'
GENERATED_NAME = 'generated.yml'

CRYPTOS = {
    'btc': {'component': 'bitcoin'},
    'ln': {'component': 'lightning'}
}
BACKEND_COMPONENTS = ['backend', 'dramatiq', 'postgres', 'redis']
FRONTEND_COMPONENTS = ['frontend']


def add_components() -> Set[str]:
    components: Set[str] = set()
    # components.update()
    # add daemons
    for i in range(1, 10):
        crypto = getenv(f'BITCART_CRYPTO{i}')
        if crypto:
            value = CRYPTOS.get(crypto)
            if value:
                components.add(value["component"])
    # bitcart backend and frontend
    to_install = getenv("BITCART_INSTALL", "all")
    if not to_install:
        to_install = "all"
    if to_install == "all":
        components.update(BACKEND_COMPONENTS + FRONTEND_COMPONENTS)
    elif to_install == "backend":
        components.update(BACKEND_COMPONENTS)
    elif to_install == "frontend":
        components.update(FRONTEND_COMPONENTS)
    if not components:
        components.add(CRYPTOS['btc']['component'])
    return components


def load_component(component: str):
    path = path_join(COMPONENTS_DIR, component + ".yml")
    if not exists(path):
        return {}
    with open(path) as f:
        data = yaml.load(f, Loader=yaml.SafeLoader)
        return data or {}


def generate(components: Set[str]):
    # generated yaml
    data = {}
    services = []
    networks = []
    volumes = []
    for i in components:
        doc = load_component(i)
        if doc.get("services"):
            services.append(doc["services"])
        if doc.get("networks"):
            networks.append(doc["networks"])
        if doc.get("volumes"):
            volumes.append(doc["volumes"])
    services = {j: i[j] for i in services for j in i}
    networks = {j: i[j] for i in networks for j in i}
    volumes = {j: i[j] for i in volumes for j in i}
    data = {
        "version": "3",
        "services": services,
        "networks": networks,
        "volumes": volumes}
    with open(path_join(COMPOSE_DIR, GENERATED_NAME), "w") as f:
        yaml.dump(data, f, default_flow_style=False)


components = add_components()
generate(components)
