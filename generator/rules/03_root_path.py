from os.path import join as urljoin

from ..constants import BITCART_API_URL, ONE_DOMAIN_MODE
from ..utils import modify_key


def rule(services):
    if not ONE_DOMAIN_MODE:
        return
    API_URL = urljoin(BITCART_API_URL, "api")
    # replace defaults
    if services.get("store"):
        with modify_key(services, "backend", "environment") as environment:
            environment["BITCART_BACKEND_ROOTPATH"] = environment["BITCART_BACKEND_ROOTPATH"].replace("-}", "-/api}")
        with modify_key(services, "admin", "environment") as environment:
            environment["BITCART_ADMIN_ROOTPATH"] = environment["BITCART_ADMIN_ROOTPATH"].replace("/", "/admin")
            environment["BITCART_ADMIN_API_URL"] = API_URL
        with modify_key(services, "store", "environment") as environment:
            environment["BITCART_STORE_API_URL"] = API_URL
    elif services.get("admin"):
        with modify_key(services, "backend", "environment") as environment:
            environment["BITCART_BACKEND_ROOTPATH"] = environment["BITCART_BACKEND_ROOTPATH"].replace("-}", "-/api}")
        with modify_key(services, "admin", "environment") as environment:
            environment["BITCART_ADMIN_API_URL"] = API_URL
