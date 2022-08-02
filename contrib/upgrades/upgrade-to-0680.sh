#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/../../helpers.sh"
load_env

volumes_dir=/var/lib/docker/volumes
datadir="$volumes_dir/$(volume_name tor_servicesdir)/_data"

find "$datadir" -type d -exec chmod 750 '{}' +
bitcart_restart
