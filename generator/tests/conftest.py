import glob
import os
from os.path import basename
from os.path import join as path_join

import pytest

from generator import generate_config
from generator.constants import COMPONENTS_DIR
from generator.settings import Settings


def pytest_generate_tests(metafunc):
    # clean up settings before a test session
    for key in filter(lambda env: env.startswith("BITCART_"), os.environ):
        del os.environ[key]


@pytest.fixture(autouse=True, scope="session")
def settings():
    return Settings()


@pytest.fixture(autouse=True, scope="session")
def config():
    return generate_config()


def convert_component(component):
    return basename(component).replace(".yml", "")


@pytest.fixture(autouse=True, scope="session")
def all_components():
    return sorted(map(convert_component, glob.glob(path_join(COMPONENTS_DIR, "*.yml"))))
