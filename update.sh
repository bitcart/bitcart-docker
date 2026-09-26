#!/usr/bin/env bash

set -e

# shellcheck source=helpers.sh
. helpers.sh
# shellcheck source=host-agent/helpers.sh
. host-agent/helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY"

skip_git_pull=false
agent_only=false
for arg in "$@"; do
    case $arg in
    --skip-git-pull) skip_git_pull=true ;;
    --agent-only) agent_only=true ;;
    esac
done

if ! $skip_git_pull; then
    git pull --force
    exec "./update.sh" --skip-git-pull "$@"
fi

if ! [ -f "/etc/docker/daemon.json" ] && [ -w "/etc/docker" ]; then
    echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" >/etc/docker/daemon.json
    echo "Setting limited log files in /etc/docker/daemon.json"
fi

resolve_agent_settings
bitcart_update_docker_env
./build.sh --pull-only
install_host_agent
if $agent_only; then
    exit 0
fi

if ! ./build.sh; then
    echo "Failed to generate the docker-compose"
    exit 1
fi

# shellcheck source=helpers.sh
. helpers.sh
check_docker_compose
install_tooling
bitcart_pull
bitcart_start

set +e
run_upgrades
docker image prune -f --filter "label=org.bitcart.image" --filter "label!=org.bitcart.image=docker-compose-generator"
