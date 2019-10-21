from os import getenv
import os

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
}
CRYPTO_COMPONENTS = [CRYPTOS[i]["component"] for i in CRYPTOS]
BACKEND_COMPONENTS = ["backend", "postgres", "redis"]
FRONTEND_COMPONENTS = ["store", "admin"]
