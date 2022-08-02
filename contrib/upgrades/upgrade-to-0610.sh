#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/../../helpers.sh"
load_env

docker exec -i $(container_name database-1) sed -i 's/host all all all md5/host all all all trust/' /var/lib/postgresql/data/pg_hba.conf
bitcart_restart
