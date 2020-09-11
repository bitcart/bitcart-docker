#!/usr/bin/env bash
set -e

: "${BITCARTGEN_DOCKER_IMAGE:=bitcartcc/docker-compose-generator}"
if [ "$BITCARTGEN_DOCKER_IMAGE" == "bitcartcc/docker-compose-generator:local" ]
then
    docker build generator --tag $BITCARTGEN_DOCKER_IMAGE
else
    set +e
    docker pull $BITCARTGEN_DOCKER_IMAGE
    docker rmi $(docker images bitcartcc/docker-compose-generator --format "{{.Tag}};{{.ID}}" | grep "^<none>" | cut -f2 -d ';') > /dev/null 2>&1
    set -e
fi

docker run -v "$PWD/compose:/app/compose" \
    -e "BITCART_INSTALL=${BITCART_INSTALL:-all}" \
    -e "BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}" \
    -e "BITCART_REVERSEPROXY=${BITCART_REVERSEPROXY:-nginx-https}" \
    -e "BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS" \
    --env-file <(env | grep BITCART_) \
    --rm $BITCARTGEN_DOCKER_IMAGE