import hashlib
from os.path import join as path_join

from generator.constants import COMPOSE_DIR
from generator.utils import modify_key

NGINX_TEMPLATE_PATH = path_join(COMPOSE_DIR, "nginx.tmpl")


def rule(services, settings):
    if not services.get("nginx-gen"):
        return
    with open(NGINX_TEMPLATE_PATH, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    with modify_key(services, "nginx-gen", "labels") as labels:
        labels["org.bitcart.nginx-template-sha256"] = digest
