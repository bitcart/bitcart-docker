#!/bin/bash

set -e

export BITCART_HOST=bitcart.local
export REVERSEPROXY_DEFAULT_HOST=bitcart.local
export BITCART_CRYPTOS=btc,ltc
export BITCART_REVERSEPROXY=nginx
export BTC_LIGHTNING=true
# Use current repo's generator
export BITCARTGEN_DOCKER_IMAGE=bitcart/docker-compose-generator:local

./setup.sh

timeout 1m bash .github/test-connectivity.sh

# # Testing scripts are not crashing and installed
./start.sh
./stop.sh
