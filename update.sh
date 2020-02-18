#!/usr/bin/env bash

set -e

export USER_UID=${UID} 
export USER_GID=${GID}

if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OS
	BASH_PROFILE_SCRIPT="$HOME/bitcartcc-env.sh"

else
	# Linux
	BASH_PROFILE_SCRIPT="/etc/profile.d/bitcartcc-env.sh"
fi

. ${BASH_PROFILE_SCRIPT}

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
}" > /etc/docker/daemon.json
    echo "Setting limited log files in /etc/docker/daemon.json"
fi

if ! ./build.sh; then
    echo "Failed to generate the docker-compose"
    exit 1
fi

. helpers.sh
bitcart_update_docker_env
./start.sh

set +e
docker image prune -af --filter "label=org.bitcartcc.image" --filter "label!=org.bitcartcc.image=docker-compose-generator"