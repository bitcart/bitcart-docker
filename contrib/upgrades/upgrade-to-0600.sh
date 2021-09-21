#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/../../helpers.sh"
load_env
COMPOSE_DIR="$(realpath "${SCRIPT_DIR}/../../compose")"

volumes_dir=/var/lib/docker/volumes
datadir="$volumes_dir/$(container_name bitcart_datadir)/_data"
logdir="$volumes_dir/$(container_name bitcart_logs)/_data"
cp -rv --preserve $logdir/* $datadir/logs/
docker volume rm $(container_name bitcart_logs)
cp -rv --preserve $COMPOSE_DIR/images/* $datadir/images/
rm -rf "$COMPOSE_DIR/images"
rm -rf "$COMPOSE_DIR/conf"
