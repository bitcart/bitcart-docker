#!/usr/bin/env bash
#
# dev-start.sh — Start the Bitcart stack for local development without root.
#
# The standard Bitcart startup flow is:
#
#   setup.sh  →  Installs Docker, writes system-level config to /etc/profile.d/,
#                registers systemd services, edits /etc/hosts for .local domains,
#                and calls start.sh. Must be run as root.
#
#   start.sh  →  Sources helpers.sh, calls load_env (which reads the profile
#                script from /etc/profile.d/ and the .deploy file), then runs
#                bitcart_start to build plugins and bring up containers.
#                Assumes setup.sh has already run.
#
# Both scripts assume root access for:
#   - Writing to /etc/profile.d/ (environment persistence)
#   - Binding ports 80/443
#   - Editing /etc/hosts for .local domains
#   - Touching files inside Docker volume paths on the host filesystem
#
# This script bypasses all of that:
#   - Writes the profile script to a local file (.bitcart-env-dev.sh) instead
#     of /etc/profile.d/
#   - Uses sslip.io wildcard DNS (*.127-0-0-1.sslip.io → 127.0.0.1) so no
#     /etc/hosts editing is needed
#   - Binds to high ports (8080/8443) instead of 80/443
#   - Manages the .plugins-failed sentinel file via a throwaway container
#     instead of touching the Docker volume path directly on the host
#   - Applies compose/dev-overrides.yml which adds extra_hosts entries so
#     that admin/store containers can reach the API via sslip.io (which
#     would otherwise resolve to 127.0.0.1 inside the container)
#   - Limits API workers to 2 to avoid exhausting postgres connections
#   - Sets all deployment config as env vars (not in .deploy) so they
#     survive save_deploy_config overwriting .deploy
#
# Usage:
#   ./dev-start.sh          # start/restart the stack
#   ./dev-stop.sh           # stop the stack
#
# After startup:
#   API:    http://api.127-0-0-1.sslip.io:8080/
#   Admin:  http://admin.127-0-0-1.sslip.io:8080/
#   Store:  http://127-0-0-1.sslip.io:8080/
#
set -e
cd "$(dirname "$0")"

echo "==> Setting up rootless dev environment"

# Override paths that normally require root on Linux
export BITCART_BASE_DIRECTORY="$(pwd)"
export BASH_PROFILE_SCRIPT="$BITCART_BASE_DIRECTORY/.bitcart-env-dev.sh"

# Ensure the profile script exists (load_env will source it)
touch "$BASH_PROFILE_SCRIPT"

# Set deployment config as env vars (survives save_deploy_config overwriting .deploy)
export NAME=bitcart
export BITCART_HOST=api.127-0-0-1.sslip.io
export BITCART_STORE_HOST=127-0-0-1.sslip.io
export BITCART_ADMIN_HOST=admin.127-0-0-1.sslip.io
export BITCART_INSTALL=all
export BITCART_REVERSEPROXY=nginx
export BITCART_CRYPTOS=btc
export BITCART_NOHOSTSEDIT=true
export REVERSEPROXY_HTTP_PORT=8080
export REVERSEPROXY_HTTPS_PORT=8443
export STATIC_SITES_PATH="$BITCART_BASE_DIRECTORY/var/statics"

# Tell the store and admin containers where the API lives.
# Both browser and SSR requests use the public sslip.io URL.
# dev-overrides.yml adds extra_hosts so sslip.io resolves to the
# Docker host (where nginx listens on 8080) instead of 127.0.0.1.
# Limit API workers to avoid exhausting postgres connections (default is 1 per CPU core)
export BITCART_API_WORKERS=2
export BITCART_STORE_API_URL="http://api.127-0-0-1.sslip.io:8080"
export BITCART_ADMIN_API_URL="http://api.127-0-0-1.sslip.io:8080"

echo "==> Loading helpers"
. helpers.sh

echo "==> Writing docker compose .env file"
export BITCART_ENV_FILE="$BITCART_BASE_DIRECTORY/.env"
bitcart_update_docker_env

echo "==> Resetting plugin hashes (forces rebuild)"
bitcart_reset_plugins

# ---------- rootless install_plugins ----------
# The upstream install_plugins touches a .plugins-failed sentinel on the host
# at /var/lib/docker/volumes/…, which is owned by root. We redefine the
# function to manage that file through a container instead.
_vol="bitcart_bitcart_datadir"
_failed=".plugins-failed"

_clear_failed() { docker run --rm -v "$_vol":/data alpine rm -f "/data/$_failed" 2>/dev/null || true; }
_touch_failed() { docker run --rm -v "$_vol":/data alpine touch "/data/$_failed" 2>/dev/null || true; }

install_plugins() {
    echo "==> Resolving components"
    COMPONENTS=$(./build.sh --components-only | tail -1)
    COIN_COMPONENTS=$(./build.sh --cryptos-only | tail -1)
    echo "    Components: $COMPONENTS"
    echo "    Crypto components: ${COIN_COMPONENTS:-none}"
    error=false

    echo "==> Clearing previous plugin failure sentinel"
    _clear_failed

    echo "==> Backing up current images"
    if [[ " ${COMPONENTS[*]} " =~ " backend " ]]; then
        make_backup_image bitcart/bitcart
    fi
    if [[ " ${COMPONENTS[*]} " =~ " admin " ]]; then
        make_backup_image bitcart/bitcart-admin
    fi
    if [[ " ${COMPONENTS[*]} " =~ " store " ]]; then
        make_backup_image bitcart/bitcart-store
    fi
    for coin in $COIN_COMPONENTS; do
        make_backup_image bitcart/bitcart-$coin
    done

    if [[ "$DOCKER_PLUGINS_HASH" != "$(get_plugins_hash docker)" ]]; then
        echo "==> Building docker compose config from plugins"
        ./build.sh || _touch_failed
        docker compose -f compose/generated.yml config > /dev/null || _touch_failed
    else
        echo "==> Docker plugins unchanged, skipping compose rebuild"
    fi

    if [[ " ${COMPONENTS[*]} " =~ " backend " ]] && [[ "$BACKEND_PLUGINS_HASH" != "$(get_plugins_hash backend)" ]]; then
        echo "==> Building backend image with plugins"
        docker build -t bitcart/bitcart:stable -f compose/backend-plugins.Dockerfile compose || error=true
    fi
    if [[ "$error" = false ]] && [[ " ${COMPONENTS[*]} " =~ " admin " ]] && [[ "$ADMIN_PLUGINS_HASH" != "$(get_plugins_hash admin)" ]]; then
        echo "==> Building admin image with plugins"
        docker build -t bitcart/bitcart-admin:stable -f compose/admin-plugins.Dockerfile compose || error=true
    fi
    if [[ "$error" = false ]] && [[ " ${COMPONENTS[*]} " =~ " store " ]] && [[ "$STORE_PLUGINS_HASH" != "$(get_plugins_hash store)" ]]; then
        echo "==> Building store image with plugins"
        docker build -t bitcart/bitcart-store:stable -f compose/store-plugins.Dockerfile compose || error=true
    fi

    if [[ "$error" = true ]]; then
        echo "==> Plugins installation FAILED, restoring original images"
        if [[ " ${COMPONENTS[*]} " =~ " backend " ]]; then
            docker tag bitcart/bitcart:original bitcart/bitcart:stable
        fi
        if [[ " ${COMPONENTS[*]} " =~ " admin " ]]; then
            docker tag bitcart/bitcart-admin:original bitcart/bitcart-admin:stable
        fi
        if [[ " ${COMPONENTS[*]} " =~ " store " ]]; then
            docker tag bitcart/bitcart-store:original bitcart/bitcart-store:stable
        fi
        for coin in $COIN_COMPONENTS; do
            docker tag bitcart/bitcart-$coin:original bitcart/bitcart-$coin:stable
        done
        _touch_failed
    fi

    echo "==> Saving deploy config"
    save_deploy_config
}

# Override bitcart_start to include dev-overrides.yml (extra_hosts for SSR).
bitcart_start() {
    create_backup_volume
    install_plugins
    echo "==> Starting containers (with dev overrides)"
    docker compose -p "$NAME" \
        -f compose/generated.yml \
        -f compose/dev-overrides.yml \
        up --build --remove-orphans -d $1
}

echo "==> Installing plugins and starting containers"
bitcart_start

echo ""
echo "==> Dev stack is up"
echo "    API:   http://${BITCART_HOST}:${REVERSEPROXY_HTTP_PORT:-80}/"
echo "    Admin: http://${BITCART_ADMIN_HOST}:${REVERSEPROXY_HTTP_PORT:-80}/"
echo "    Store: http://${BITCART_STORE_HOST}:${REVERSEPROXY_HTTP_PORT:-80}/"
