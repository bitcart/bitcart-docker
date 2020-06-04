#!/usr/bin/env bash
set -e
BITCARTGEN_DOCKER_IMAGE='mrnaif/docker-compose-generator'
set +e
docker pull $BITCARTGEN_DOCKER_IMAGE
docker rmi $(docker images mrnaif/docker-compose-generator --format "{{.Tag}};{{.ID}}" | grep "^<none>" | cut -f2 -d ';') > /dev/null 2>&1
set -e

docker run -v "$PWD/compose:/app/compose" \
    -e "BITCART_INSTALL=${BITCART_INSTALL:-all}" \
    -e "BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}" \
    -e "BITCART_REVERSEPROXY=${BITCART_REVERSEPROXY:-nginx-https}" \
    -e "BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS" \
    --env-file <(set | awk -F "=" '{print "\n"$0}' | grep "BITCART_") \
    --rm $BITCARTGEN_DOCKER_IMAGE