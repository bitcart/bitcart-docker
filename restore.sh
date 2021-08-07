#!/usr/bin/env bash

. helpers.sh
load_env true

TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')

tar -C $TEMP_DIR -xvf "$1"
cd $TEMP_DIR

echo "Restoring database …"
bitcart_restore_db database.sql

echo "Stopping BitcartCC…"
bitcart_stop

cp -r volumes/ /var/lib/docker

echo "Restarting BitcartCC…"
bitcart_start

rm -rf $TEMP_DIR
