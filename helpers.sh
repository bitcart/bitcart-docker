read_from_env_file() {
    if cat "$1" &>/dev/null; then
        while IFS= read -r line; do
            ! [[ "$line" == "#"* ]] && [[ "$line" == *"="* ]] && export "$line" || true
        done <"$1"
    fi
}

read_from_env_file .deploy

bitcart_update_docker_env() {
    touch $BITCART_ENV_FILE
    cat >$BITCART_ENV_FILE <<EOF
BITCART_HOST=$BITCART_HOST
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
REVERSEPROXY_HTTP_PORT=$REVERSEPROXY_HTTP_PORT
REVERSEPROXY_HTTPS_PORT=$REVERSEPROXY_HTTPS_PORT
REVERSEPROXY_DEFAULT_HOST=$REVERSEPROXY_DEFAULT_HOST
BITCART_SSH_KEY_FILE=$BITCART_SSH_KEY_FILE
BITCART_SSH_AUTHORIZED_KEYS=$BITCART_SSH_AUTHORIZED_KEYS
BITCART_HOST_SSH_AUTHORIZED_KEYS=$BITCART_HOST_SSH_AUTHORIZED_KEYS
BITCART_STORE_HOST=$BITCART_STORE_HOST
BITCART_STORE_API_URL=$BITCART_STORE_API_URL
BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
BITCART_ADMIN_API_URL=$BITCART_ADMIN_API_URL
BITCART_CRYPTOS=$BITCART_CRYPTOS
BTC_NETWORK=$BTC_NETWORK
BTC_LIGHTNING=$BTC_LIGHTNING
BCH_NETWORK=$BCH_NETWORK
ETH_NETWORK=$ETH_NETWORK
BNB_NETWORK=$BNB_NETWORK
SBCH_NETWORK=$SBCH_NETWORK
MATIC_NETWORK=$MATIC_NETWORK
TRX_NETWORK=$TRX_NETWORK
XRG_NETWORK=$XRG_NETWORK
LTC_NETWORK=$LTC_NETWORK
LTC_LIGHTNING=$LTC_LIGHTNING
BSTY_NETWORK=$BSTY_NETWORK
BSTY_LIGHTNING=$BSTY_LIGHTNING
GRS_NETWORK=$GRS_NETWORK
GRS_LIGHTNING=$GRS_LIGHTNING
XMR_NETWORK=$XMR_NETWORK
TOR_RELAY_NICKNAME=$TOR_RELAY_NICKNAME
TOR_RELAY_EMAIL=$TOR_RELAY_EMAIL
CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN
BITCART_HTTPS_ENABLED=$BITCART_HTTPS_ENABLED
BITCART_VERSION=$BITCART_VERSION
BITCART_UPDATE_URL=$BITCART_UPDATE_URL
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_PORT")
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_EXPOSE")
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_SCALE")
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_ROOTPATH")
$(env | awk -F "=" '{print "\n"$0}' | grep ".*_SERVER")
$(env | awk -F "=" '{print "\n"$0}' | grep ".*_DEBUG")
$(env | awk -F "=" '{print "\n"$0}' | grep ".*_LIGHTNING_GOSSIP")
EOF
}

bitcart_start() {
    create_backup_volume
    install_plugins
    docker compose -p "$NAME" -f compose/generated.yml up --build --remove-orphans -d $1
}

bitcart_stop() {
    docker compose -p "$NAME" -f compose/generated.yml down
}

bitcart_pull() {
    docker compose -f compose/generated.yml pull
    export ADMIN_PLUGINS_HASH=5cd337198ead0768975610a135e26257153198c7
    export STORE_PLUGINS_HASH=5cd337198ead0768975610a135e26257153198c7
    export BACKEND_PLUGINS_HASH=5cd337198ead0768975610a135e26257153198c7
    export DOCKER_PLUGINS_HASH=5cd337198ead0768975610a135e26257153198c7
}

bitcart_restart() {
    bitcart_stop
    bitcart_start
}

get_profile_file() {
    CHECK_ROOT=${2:-true}
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OS

        if $CHECK_ROOT && [[ $EUID -eq 0 ]]; then
            # Running as root is discouraged on Mac OS. Run under the current user instead.
            echo "This script should not be run as root."
            exit 1
        fi

        BASH_PROFILE_SCRIPT="$HOME/bitcart-env$1.sh"

        # Mac OS doesn't use /etc/profile.d/xxx.sh. Instead we create a new file and load that from ~/.bash_profile
        if [[ ! -f "$HOME/.bash_profile" ]]; then
            touch "$HOME/.bash_profile"
        fi
        if [[ -z $(grep ". \"$BASH_PROFILE_SCRIPT\"" "$HOME/.bash_profile") ]]; then
            # Line does not exist, add it
            echo ". \"$BASH_PROFILE_SCRIPT\"" >>"$HOME/.bash_profile"
        fi

    else
        BASH_PROFILE_SCRIPT="/etc/profile.d/bitcart-env$1.sh"

        if $CHECK_ROOT && [[ $EUID -ne 0 ]]; then
            echo "This script must be run as root after running \"sudo su -\""
            exit 1
        fi
    fi
    export BASH_PROFILE_SCRIPT
}

load_env() {
    get_profile_file "$SCRIPTS_POSTFIX" ${1:-false}
    . ${BASH_PROFILE_SCRIPT}
}

try() {
    "$@" || true
}

remove_host() {
    if [ -n "$(grep -w "$1$" /etc/hosts)" ]; then
        try sudo sed -ie "/[[:space:]]$1/d" /etc/hosts
    fi
}

add_host() {
    if [ -z "$(grep -E "[[:space:]]$2" /etc/hosts)" ]; then
        try sudo printf "%s\t%s\n" "$1" "$2" | sudo tee -a /etc/hosts >/dev/null
    fi
}

modify_host() {
    if [ -z "$2" ]; then
        return
    fi
    remove_host $2
    add_host $1 $2
}

apply_local_modifications() {
    if [[ "$BITCART_HOST" == *.local ]]; then
        echo "Local setup detected."
        if [[ "$BITCART_NOHOSTSEDIT" = true ]]; then
            echo "Not modifying hosts."
        else
            echo "WARNING! Modifying /etc/hosts to make local setup work. It may require superuser privileges."
            modify_host 172.17.0.1 $BITCART_STORE_HOST
            modify_host 172.17.0.1 $BITCART_HOST
            modify_host 172.17.0.1 $BITCART_ADMIN_HOST
        fi
    fi
}

container_name() {
    deployment_name=${NAME:-compose}
    echo "${deployment_name}-$1"
}

volume_name() {
    deployment_name=${NAME:-compose}
    echo "${deployment_name}_$1"
}

create_backup_volume() {
    backup_dir="/var/lib/docker/volumes/backup_datadir/_data"
    if [ ! -d "$backup_dir" ]; then
        docker volume create backup_datadir >/dev/null 2>&1
    fi
}

bitcart_dump_db() {
    create_backup_volume
    docker exec $(container_name "database-1") pg_dumpall -c -U postgres >"$backup_dir/$1"
}

bitcart_restore_db() {
    bitcart_start database
    # wait for db to be up
    until docker exec -i $(container_name "database-1") psql -U postgres -c '\l'; do
        echo >&2 "Postgres is unavailable - sleeping"
        sleep 1
    done
    cat $1 | docker exec -i $(container_name "database-1") psql -U postgres
}

version() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

check_docker_compose() {
    if [ ! -z "$(docker-compose --version 2>/dev/null | grep docker-compose)" ] || ! [[ $(docker compose version 2>/dev/null) ]] || [ $(version $(docker compose version --short)) -lt $(version "2.9.0") ]; then
        install_docker_compose
    fi
}

install_docker_compose() {
    OS=$(uname -s)
    ARCH=$(uname -m)
    INSTALL_PATH=/usr/local/lib/docker/cli-plugins
    if [[ "$OS" == "Darwin" ]]; then
        INSTALL_PATH=~/.docker/cli-plugins
        if [[ "$ARCH" == "arm64" ]]; then
            ARCH="aarch64"
        fi
    fi
    DOCKER_COMPOSE_DOWNLOAD="https://github.com/docker/compose/releases/latest/download/docker-compose-$OS-$ARCH"
    echo "Trying to install docker-compose by downloading on $DOCKER_COMPOSE_DOWNLOAD ($(uname -m))"
    sudo mkdir -p $INSTALL_PATH
    sudo curl -L "$DOCKER_COMPOSE_DOWNLOAD" -o $INSTALL_PATH/docker-compose
    sudo chmod +x $INSTALL_PATH/docker-compose
    # remove old docker-compose
    try sudo rm "$(command -v docker-compose)" &>/dev/null
}

install_tooling() {
    try sudo cp compose/scripts/cli-autocomplete.sh /etc/bash_completion.d/bitcart-cli.sh
    try sudo chmod +x /etc/bash_completion.d/bitcart-cli.sh
}

save_deploy_config() {
    BITCART_DEPLOYMENT_CONFIG="$BITCART_BASE_DIRECTORY/.deploy"
    cat >${BITCART_DEPLOYMENT_CONFIG} <<EOF
#!/bin/bash
NAME=$NAME
SCRIPTS_POSTFIX=$SCRIPTS_POSTFIX
ADMIN_PLUGINS_HASH=$(get_plugins_hash admin)
STORE_PLUGINS_HASH=$(get_plugins_hash store)
BACKEND_PLUGINS_HASH=$(get_plugins_hash backend)
DOCKER_PLUGINS_HASH=$(get_plugins_hash docker)
EOF
    chmod +x ${BITCART_DEPLOYMENT_CONFIG}
    read_from_env_file $BITCART_DEPLOYMENT_CONFIG
}

get_plugins_hash() {
    LC_ALL=C find compose/plugins/$1 -type f -print0 2>/dev/null | sort -z | xargs -0 sha1sum | sha1sum | awk '{print $1}'
}

make_backup_image() {
    if [ "$(docker inspect --format '{{ index .Config.Labels "org.bitcart.plugins"}}' $1:stable)" = true ]; then
        :
    else
        docker tag $1:stable $1:original
    fi
}

install_plugins() {
    COMPONENTS=$(./build.sh --components-only | tail -1)
    failed_file="/var/lib/docker/volumes/$(volume_name "bitcart_datadir")/_data/.plugins-failed"
    error=false
    rm -f $failed_file
    if [[ " ${COMPONENTS[*]} " =~ " backend " ]]; then
        make_backup_image bitcart/bitcart
    fi
    if [[ " ${COMPONENTS[*]} " =~ " admin " ]]; then
        make_backup_image bitcart/bitcart-admin
    fi
    if [[ " ${COMPONENTS[*]} " =~ " store " ]]; then
        make_backup_image bitcart/bitcart-store
    fi
    if [[ "$DOCKER_PLUGINS_HASH" != "$(get_plugins_hash docker)" ]]; then
        ./build.sh || touch $failed_file
        docker compose -f compose/generated.yml config || touch $failed_file
    fi
    if [[ " ${COMPONENTS[*]} " =~ " backend " ]] && [[ "$BACKEND_PLUGINS_HASH" != "$(get_plugins_hash backend)" ]]; then
        docker build -t bitcart/bitcart:stable -f compose/backend-plugins.Dockerfile compose || error=true
    fi
    if [[ "$error" = false ]] && [[ " ${COMPONENTS[*]} " =~ " admin " ]] && [[ "$ADMIN_PLUGINS_HASH" != "$(get_plugins_hash admin)" ]]; then
        docker build -t bitcart/bitcart-admin:stable -f compose/admin-plugins.Dockerfile compose || error=true
    fi
    if [[ "$error" = false ]] && [[ " ${COMPONENTS[*]} " =~ " store " ]] && [[ "$STORE_PLUGINS_HASH" != "$(get_plugins_hash store)" ]]; then
        docker build -t bitcart/bitcart-store:stable -f compose/store-plugins.Dockerfile compose || error=true
    fi
    if [[ "$error" = true ]]; then
        echo "Plugins installation failed, restoring original images"
        if [[ " ${COMPONENTS[*]} " =~ " backend " ]]; then
            docker tag bitcart/bitcart:original bitcart/bitcart:stable
        fi
        if [[ " ${COMPONENTS[*]} " =~ " admin " ]]; then
            docker tag bitcart/bitcart-admin:original bitcart/bitcart-admin:stable
        fi
        if [[ " ${COMPONENTS[*]} " =~ " store " ]]; then
            docker tag bitcart/bitcart-store:original bitcart/bitcart-store:stable
        fi
        touch $failed_file
    fi
    save_deploy_config
}
