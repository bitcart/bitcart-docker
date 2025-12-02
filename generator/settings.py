from shlex import shlex

from generator.constants import ALL_REVERSE_PROXIES, AVAILABLE_SETTINGS, HTTPS_REVERSE_PROXIES
from generator.utils import config_error, env


class Settings:
    def __init__(self):
        self.settings = {}
        self.load_settings()

    def load_settings(self):
        for setting in AVAILABLE_SETTINGS:
            default = None
            if len(setting) == 3:
                name, env_name, default = setting
            elif len(setting) == 2:  # pragma: no cover
                name, env_name = setting
            else:
                name = env_name = setting[0]
            self.settings[name] = env(env_name, default)
        self.add_custom_settings()
        self.apply_checks()

    def add_custom_settings(self):
        self.CRYPTOS = self.load_comma_separated("CRYPTOS", "btc")
        self.ADDITIONAL_COMPONENTS = self.load_comma_separated("ADDITIONAL_COMPONENTS")
        self.EXCLUDE_COMPONENTS = self.load_comma_separated("EXCLUDE_COMPONENTS")
        self.ONE_DOMAIN_MODE = (
            self.REVERSE_PROXY in ALL_REVERSE_PROXIES
            and not self.ADMIN_HOST
            and not self.STORE_HOST
            and not self.ADMIN_API_URL
            and not self.STORE_API_URL
        )
        self.PROTOCOL = "https" if self.HTTPS_ENABLED or self.REVERSE_PROXY in HTTPS_REVERSE_PROXIES else "http"
        self.DEFAULT_API_PORT = "443" if self.PROTOCOL == "https" else "80"
        self.API_PORT = env(f"REVERSEPROXY_{self.PROTOCOL.upper()}_PORT", self.DEFAULT_API_PORT, prefix="")
        self.API_PORT = self.API_PORT.rsplit(":", 1)[-1]
        port_suffix = f":{self.API_PORT}" if not self.BEHIND_REVERSE_PROXY and self.API_PORT != self.DEFAULT_API_PORT else ""
        self.API_URL = f"{self.PROTOCOL}://{self.HOST}{port_suffix}"

    def apply_checks(self):
        if self.ONE_DOMAIN_MODE and self.INSTALLATION_PACK == "frontend":
            config_error(
                "Frontend installation pack is enabled and no API URL set. "
                "Please set BITCART_ADMIN_API_URL and BITCART_STORE_API_URL."
            )

    @staticmethod
    def load_comma_separated(name, default=""):
        value = env(name, default)
        splitter = shlex(value, posix=True)
        splitter.whitespace = ","
        splitter.whitespace_split = True
        return [item.strip() for item in splitter]

    def __getattr__(self, name):
        return self.settings.__getitem__(name)

    def __setattr__(self, name, value):
        if name.isupper():
            self.settings.__setitem__(name, value)
        else:
            super().__setattr__(name, value)
