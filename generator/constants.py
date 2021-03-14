import os
from os.path import join as path_join

# Essential files lookup
CURRENT_DIR = os.path.dirname(__file__)
COMPOSE_DIR = path_join(CURRENT_DIR, "..", "compose")
COMPONENTS_DIR = path_join(CURRENT_DIR, "docker-components")
RULES_DIR = path_join(CURRENT_DIR, "rules")
RULES_PYTHON_PKG = "generator"
RULES_PYTHON_DIR = "generator.rules"
GENERATED_NAME = "generated.yml"
GENERATED_PATH = path_join(COMPOSE_DIR, GENERATED_NAME)

# Crypto constants
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

# Installation packs
BACKEND_COMPONENTS = ["backend", "worker", "postgres", "redis"]
FRONTEND_COMPONENTS = ["store", "admin"]

# One domain mode constants
HTTPS_REVERSE_PROXIES = ["nginx-https"]
ALL_REVERSE_PROXIES = ["nginx"] + HTTPS_REVERSE_PROXIES
# Note: do not change the order, it's the order preferred (root) service is chosen
HOST_COMPONENTS = ["store", "admin", "backend"]

# Settings to load
AVAILABLE_SETTINGS = [
    ("INSTALLATION_PACK", "INSTALL", "all"),
    ("REVERSE_PROXY", "REVERSEPROXY", "nginx-https"),
    ("HOST",),
    ("ADMIN_HOST",),
    ("STORE_HOST",),
    ("ADMIN_API_URL",),
    ("STORE_API_URL",),
]
