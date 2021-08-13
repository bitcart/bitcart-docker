#!/usr/bin/env bash

. helpers.sh
load_env true
cd "$BITCART_BASE_DIRECTORY"

TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')

tar -C $TEMP_DIR -xvf "$1"

echo "Stopping BitcartCC…"
bitcart_stop

echo "Restoring database …"
bitcart_restore_db $TEMP_DIR/database.sql
echo "Restoring docker volumes…"
cp -r $TEMP_DIR/volumes/ /var/lib/docker

echo "Restarting BitcartCC…"
bitcart_start

rm -rf $TEMP_DIR
