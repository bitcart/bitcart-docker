#!/usr/bin/env bash

# shellcheck source=helpers.sh
. helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY" || exit 1
bitcart_restart
