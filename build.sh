#!/usr/bin/env bash
source generator-env.sh

BITCARTGEN_DOCKER_IMAGE='mrnaif/docker-compose-generator'

docker run -v "$PWD/compose:/app/compose" \
    -e "BITCART_INSTALL=${BITCART_INSTALL:-all}" \
    -e "BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}" \
    -e "BITCART_REVERSEPROXY=${BITCART_REVERSEPROXY:-nginx-https}" \
    -e "BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS" \
    $BITCARTGEN_DOCKER_IMAGE