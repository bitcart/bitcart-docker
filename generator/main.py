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
    return components


def load_component(component: str):
    path = path_join(COMPONENTS_DIR, component + ".yml")
    if not exists(path):
        return
    with open(path) as f:
        data = yaml.load(f, Loader=yaml.SafeLoader)
        print(data)


def generate(components: Set[str]):
    # generated yaml
    data = {}
    for i in components:
        load_component(i)
    with open(path_join(COMPOSE_DIR, GENERATED_NAME), "w") as f:
        yaml.dump(data, f, default_flow_style=False)


components = add_components()
print(components)
generate(components)
'''if not to_install:
    to_install = "all"
if to_install == "all":
    with open(BACKEND) as f:
        data1 = yaml.load(f, Loader=yaml.SafeLoader)
    with open(FRONTEND) as f:
        data2 = yaml.load(f, Loader=yaml.SafeLoader)
    data1["services"].update(data2["services"])
    data1["volumes"].update(data2["volumes"])
    s = data1["services"]
    if s.get("nginx"):
        s["nginx"]["links"] = ["backend", "frontend"]
    if s.get("frontend"):
        s["frontend"]["links"] = ["backend"]
    with open(path_join(COMPOSE_DIR, GENERATED_NAME), "w") as f:
        yaml.dump(data1, f, default_flow_style=False)
else:
    if to_install == "backend":
        f_name = BACKEND
    else:
        f_name = FRONTEND

    shutil.copy2(f_name, path_join(COMPOSE_DIR, GENERATED_NAME))'''
