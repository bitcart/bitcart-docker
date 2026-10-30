#!/usr/bin/env bash
set -e

GENERATOR_REPOSITORY=bitcart/docker-compose-generator
if [ -z "$BITCARTGEN_DOCKER_IMAGE" ]; then
    if commit=$(git -C "$(dirname "$0")" rev-parse HEAD 2>/dev/null); then
        BITCARTGEN_DOCKER_IMAGE="$GENERATOR_REPOSITORY:sha-$commit"
    else
        BITCARTGEN_DOCKER_IMAGE="$GENERATOR_REPOSITORY:local"
    fi
fi

if [ "$1" == "--image" ]; then
    echo "$BITCARTGEN_DOCKER_IMAGE"
    exit 0
fi

build_generator() {
    docker build --pull --build-arg "AGENT_OS=$(uname -s | tr '[:upper:]' '[:lower:]')" -f generator/Dockerfile . \
        --tag "$BITCARTGEN_DOCKER_IMAGE"
}

if [ "$BITCARTGEN_DOCKER_IMAGE" == "$GENERATOR_REPOSITORY:local" ]; then
    build_generator
elif [[ "$BITCARTGEN_DOCKER_IMAGE" == "$GENERATOR_REPOSITORY:sha-"* ]]; then
    if ! docker image inspect "$BITCARTGEN_DOCKER_IMAGE" >/dev/null 2>&1 && ! docker pull "$BITCARTGEN_DOCKER_IMAGE"; then
        echo "No published generator image for this commit, building it locally"
        build_generator
    fi
else
    docker pull "$BITCARTGEN_DOCKER_IMAGE" || true
fi
docker images "$GENERATOR_REPOSITORY" --format "{{.Tag}} {{.ID}}" |
    awk -v repository="$GENERATOR_REPOSITORY" -v current="$BITCARTGEN_DOCKER_IMAGE" '
        $1 == "<none>" { print $2 }
        $1 ~ /^sha-/ && repository ":" $1 != current { print repository ":" $1 }' |
    xargs -r docker rmi >/dev/null 2>&1 || true

if [ "$1" == "--pull-only" ]; then
    exit 0
fi

docker run -v "$PWD/compose:/app/compose" \
    --env-file <(env | grep BITCART_) \
    --env-file <(env | grep REVERSEPROXY_) \
    --env NAME="$NAME" \
    --rm "$BITCARTGEN_DOCKER_IMAGE" "$@"
