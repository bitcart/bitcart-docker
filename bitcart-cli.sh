#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/helpers.sh"
load_env
docker exec $(container_name worker-1) bitcart-cli "$@"
