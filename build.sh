#!/usr/bin/env bash
set -e

: "${BITCARTGEN_DOCKER_IMAGE:=bitcart/docker-compose-generator}"
if [ "$BITCARTGEN_DOCKER_IMAGE" == "bitcart/docker-compose-generator:local" ]; then
    docker build generator --tag $BITCARTGEN_DOCKER_IMAGE
else
    set +e
    docker pull $BITCARTGEN_DOCKER_IMAGE
    docker rmi $(docker images bitcart/docker-compose-generator --format "{{.Tag}};{{.ID}}" | grep "^<none>" | cut -f2 -d ';') >/dev/null 2>&1
    set -e
fi

docker run -v "$PWD/compose:/app/compose" \
    --env-file <(env | grep BITCART_) \
    --env NAME=$NAME \
    --env REVERSEPROXY_HTTP_PORT=$REVERSEPROXY_HTTP_PORT \
    --env REVERSEPROXY_HTTPS_PORT=$REVERSEPROXY_HTTPS_PORT \
    --rm $BITCARTGEN_DOCKER_IMAGE $@
