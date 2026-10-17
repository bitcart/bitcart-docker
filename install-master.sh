#!/usr/bin/env bash

set -e

usage="Usage: ./install-master.sh [--only component,...]"
args=("$@")
only=()
skip_git_pull=false
while [[ $# -gt 0 ]]; do
    case $1 in
    --skip-git-pull)
        skip_git_pull=true
        shift
        ;;
    --only)
        IFS=', ' read -r -a values <<<"$2"
        if [[ ${#values[@]} -eq 0 ]]; then
            echo "$usage" >&2
            exit 1
        fi
        only+=("${values[@]}")
        shift 2
        ;;
    *)
        echo "Error: Unsupported flag $1" >&2
        echo "$usage" >&2
        exit 1
        ;;
    esac
done

# shellcheck source=helpers.sh
. helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY"

if ! $skip_git_pull; then
    git pull --force
    exec ./install-master.sh --skip-git-pull "${args[@]}"
fi

components=$(bitcart_generator_list --components-only)
cryptos=$(bitcart_generator_list --cryptos-only)
read -r -a components <<<"$components"
read -r -a cryptos <<<"$cryptos"

buildable=()
for component in backend admin store; do
    if [[ " ${components[*]} " == *" $component "* ]]; then
        buildable+=("$component")
    fi
done
buildable+=("${cryptos[@]}")

if [[ ${#only[@]} -eq 0 ]]; then
    partial=false
    selection=("${buildable[@]}")
else
    partial=true
    for component in "${only[@]}"; do
        if [[ " ${buildable[*]} " != *" $component "* ]]; then
            echo "Error: Unknown or disabled component: $component. Available: ${buildable[*]}" >&2
            exit 1
        fi
    done
    selection=("${only[@]}")
fi

selected() {
    [[ " ${selection[*]} " == *" $1 "* ]]
}

selected_cryptos=()
for coin in "${cryptos[@]}"; do
    if selected "$coin"; then
        selected_cryptos+=("$coin")
    fi
done

# Create a backup
./backup.sh
for component in backend admin store; do
    if selected "$component"; then
        bitcart_reset_plugins "$(echo "$component" | tr '[:lower:]' '[:upper:]')"
    fi
done
# First, update to latest stable release, then we can apply staging changes
if $partial; then
    ./update.sh --skip-git-pull --no-start --keep-master-images
else
    ./update.sh --skip-git-pull --no-start
fi
# shellcheck source=helpers.sh
. helpers.sh

built=()
build_image() {
    local revision=$1 image=$2
    shift 2
    docker build --pull --label org.opencontainers.image.version=master \
        --label "org.opencontainers.image.revision=$revision" -t "$image:install-master" "$@"
    built+=("$image")
}

if selected backend || [[ ${#selected_cryptos[@]} -gt 0 ]]; then
    ./dev-setup.sh
    cd compose
    revision=$(cat bitcart/.revision)
    if selected backend; then
        build_image "$revision" bitcart/bitcart -f backend.Dockerfile .
    fi
    for coin in "${selected_cryptos[@]}"; do
        build_image "$revision" "bitcart/bitcart-$coin" -f "$coin.Dockerfile" .
    done
    cd ..
    rm -rf compose/bitcart
fi

temp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')
trap 'rm -rf "$temp_dir"' EXIT
for component in admin store; do
    if selected "$component"; then
        git clone "https://github.com/bitcart/bitcart-$component" "$temp_dir/$component"
        build_image "$(git -C "$temp_dir/$component" rev-parse HEAD)" "bitcart/bitcart-$component" "$temp_dir/$component"
    fi
done

for image in "${built[@]}"; do
    docker tag "$image:install-master" "$image:stable"
    docker rmi "$image:install-master" >/dev/null
done

for component in backend admin store; do
    if [[ " ${buildable[*]} " == *" $component "* ]] && ! selected "$component"; then
        BITCART_PLUGINS_AUTO_UPDATE=false
    fi
done
bitcart_finish_update
