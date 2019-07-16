from os import getenv
from os.path import join as path_join

import oyaml as yaml

COMPOSE_DIR = '../compose'
BACKEND = path_join(COMPOSE_DIR, 'backend-compose.yml')
FRONTEND = path_join(COMPOSE_DIR, 'frontend-compose.yml')
BACKEND_DEV = path_join(COMPOSE_DIR, 'backend-compose.dev.yml')
FRONTEND_DEV = path_join(COMPOSE_DIR, 'frontend-compose.dev.yml')

if getenv('BITCART_ONE_HOST'):
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
    with open(path_join(COMPOSE_DIR, "my_file.yaml"), "w") as f:
        yaml.dump(data1, f, default_flow_style=False)
