# Static constants
import os
from os import getenv
from os.path import join as path_join

from .utils import env

CURRENT_DIR = os.path.dirname(__file__)
COMPOSE_DIR = "compose" if getenv("IN_DOCKER") else path_join(CURRENT_DIR, "..", "compose")
COMPONENTS_DIR = path_join(CURRENT_DIR, "docker-components")
RULES_DIR = path_join(CURRENT_DIR, "rules")
RULES_PYTHON_PKG = "generator"
RULES_PYTHON_DIR = "generator.rules"
GENERATED_NAME = "generated.yml"
HTTPS_REVERSE_PROXIES = ["nginx-https"]
ALL_REVERSE_PROXIES = ["nginx"] + HTTPS_REVERSE_PROXIES

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
BACKEND_COMPONENTS = ["backend", "worker", "postgres", "redis"]
FRONTEND_COMPONENTS = ["store", "admin"]

# Dynamic constants (env)

# Host settings
BITCART_HOST = env("HOST")
BITCART_ADMIN_HOST = env("ADMIN_HOST")
BITCART_STORE_HOST = env("STORE_HOST")
BITCART_ADMIN_API_URL = env("ADMIN_API_URL")
BITCART_STORE_API_URL = env("STORE_API_URL")
# Note: do not change the order, it's the order preferred (root) service is chosen
HOST_COMPONENTS = ["store", "admin", "backend"]
REVERSE_PROXY = env("REVERSEPROXY", "nginx-https")

ONE_DOMAIN_MODE = (
    REVERSE_PROXY in ALL_REVERSE_PROXIES
    and not BITCART_ADMIN_HOST
    and not BITCART_STORE_HOST
    and not BITCART_ADMIN_API_URL
    and not BITCART_STORE_API_URL
)

BITCART_PROTOCOL = "https" if REVERSE_PROXY in HTTPS_REVERSE_PROXIES else "http"
BITCART_API_URL = f"{BITCART_PROTOCOL}://{BITCART_HOST}"
