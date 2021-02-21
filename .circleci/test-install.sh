#!/bin/bash

set -e

apt-get remove docker-ce
rm -rf /usr/local/bin/docker-compose

cd ../..

[ -d bitcart-docker ] || mv repo bitcart-docker

cd bitcart-docker

export BITCART_HOST=bitcart.local
export REVERSEPROXY_DEFAULT_HOST=bitcart.local
export BITCART_CRYPTOS=btc,ltc
export BITCART_REVERSEPROXY=nginx
export BTC_LIGHTNING=true
# Use current repo's generator
export BITCARTGEN_DOCKER_IMAGE=bitcartcc/docker-compose-generator:local
./setup.sh

timeout 1m bash .circleci/test-connectivity.sh

# Testing scripts are not crashing and installed
./start.sh
./stop.sh
