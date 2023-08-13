#!/usr/bin/env bash

set -e

. helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY"

if [[ "$1" != "--skip-git-pull" ]]; then
    git pull --force
    exec "./update.sh" --skip-git-pull
    return
fi

if ! [ -f "/etc/docker/daemon.json" ] && [ -w "/etc/docker" ]; then
    echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" >/etc/docker/daemon.json
    echo "Setting limited log files in /etc/docker/daemon.json"
fi

if ! ./build.sh; then
    echo "Failed to generate the docker-compose"
    exit 1
fi

. helpers.sh
check_docker_compose
install_tooling
bitcart_update_docker_env
bitcart_pull
bitcart_start

set +e
docker image prune -f --filter "label=org.bitcart.image" --filter "label!=org.bitcart.image=docker-compose-generator"
