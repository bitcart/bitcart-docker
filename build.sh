#!/usr/bin/env bash
set -e

: "${BITCARTGEN_DOCKER_IMAGE:=bitcartcc/docker-compose-generator}"
if [ "$BITCARTGEN_DOCKER_IMAGE" == "bitcartcc/docker-compose-generator:local" ]; then
    docker build generator --tag $BITCARTGEN_DOCKER_IMAGE
else
    set +e
    docker pull $BITCARTGEN_DOCKER_IMAGE
    docker rmi $(docker images bitcartcc/docker-compose-generator --format "{{.Tag}};{{.ID}}" | grep "^<none>" | cut -f2 -d ';') >/dev/null 2>&1
    set -e
fi

docker run -v "$PWD/compose:/app/compose" \
    --env-file <(env | grep BITCART_) \
    --env NAME=$NAME \
    --rm $BITCARTGEN_DOCKER_IMAGE $@
