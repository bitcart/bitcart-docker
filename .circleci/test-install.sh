#!/bin/bash

set -e

# We remove installed docker to test that our scripts can install it by themselves
apt-get purge docker-ce docker-ce-cli containerd.io
rm -rf /usr/local/bin/docker-compose
# To simulate reboot
systemctl reset-failed docker.service
systemctl reset-failed docker.socket

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
