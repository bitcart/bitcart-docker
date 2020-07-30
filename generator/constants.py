import os
from os import getenv

COMPOSE_DIR = "compose" if getenv("IN_DOCKER") else "../compose"
COMPONENTS_DIR = "docker-components"
RULES_DIR = "rules"
RULES_PYTHON_PKG = "generator"
RULES_PYTHON_DIR = "rules"
GENERATED_NAME = "generated.yml"

CRYPTOS = {
    "btc": {"component": "bitcoin"},
    "ltc": {"component": "litecoin"},
    "gzro": {"component": "gravity"},
    "bsty": {"component": "globalboost"},
    "bch": {"component": "bitcoincash"},
}
TOR_CRYPTOS = {
    "btc": CRYPTOS["btc"]
}  # cryptos to enable tor proxy for, restricted by coingecko (cloudflare) blocking tor exit nodes
CRYPTO_COMPONENTS = [CRYPTOS[i]["component"] for i in CRYPTOS]
BACKEND_COMPONENTS = ["backend", "dramatiq", "postgres", "redis"]
FRONTEND_COMPONENTS = ["store", "admin"]
