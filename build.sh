#!/usr/bin/env bash
BITCARTGEN_DOCKER_IMAGE='mrnaif/docker-compose-generator'

docker run -v "$PWD/compose:/app/compose" \
    -e BITCART_INSTALL=$BITCART_INSTALL \
    $BITCARTGEN_DOCKER_IMAGE