#!/usr/bin/env bash

. helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY"

# First, update to latest stable release, then we can apply staging changes
./update.sh

COMPONENTS=$(./build.sh --components-only | tail -1)
IFS=', ' read -r -a CRYPTOS <<<"$BITCART_CRYPTOS"

./dev-setup.sh

cd compose

if [[ " ${COMPONENTS[*]} " =~ " backend " ]]; then
    docker build -t bitcartcc/bitcart:stable -f backend.Dockerfile . || true
fi

for coin in "${CRYPTOS[@]}"; do
    docker build -t bitcartcc/bitcart-$coin:stable -f $coin.Dockerfile . || true
done

cd ..
rm -rf compose/bitcart

build_additional_image() {
    if [[ " ${COMPONENTS[*]} " =~ " $1 " ]]; then
        OLDDIR="$PWD"
        TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')
        cd $TEMP_DIR
        git clone https://github.com/bitcartcc/bitcart-$1
        cd bitcart-$1
        docker build -t bitcartcc/bitcart-$1:stable . || true
        cd "$OLDDIR"
        rm -rf $TEMP_DIR
    fi
}

build_additional_image admin
build_additional_image store
bitcart_start
