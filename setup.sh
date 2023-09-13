#!/usr/bin/env bash

set +x

. helpers.sh

function display_help() {
    cat <<-END
Usage:
------
Install Bitcart on this server
This script must be run as root, except on Mac OS
    -h, --help: Show help
    -p: print settings and exit
    --name name: Configure new deployment name. Affects naming of profile env files and
    startup config files. Allows multiple deployments on one server.
    Empty by default
    --install-only: Run install only
    --no-startup-register: Do not register Bitcart to start via systemctl or upstart
    --no-systemd-reload: Do not reload systemd configuration
This script will:
* Install Docker
* Install Docker-Compose
* Setup Bitcart settings
* Make sure it starts at reboot via upstart or systemd
* Add Bitcart utilities in /usr/bin
* Start Bitcart
You can run again this script if you desire to change your configuration.
Make sure you own a domain with DNS record pointing to your website.
Passing domain ending with .local will automatically edit /etc/hosts to make it work.
Environment variables:
    BITCART_INSTALL: installation template to use (eg. all, backend, frontend)
    BITCART_CRYPTOS: comma-separated list of cryptocurrencies to enable (eg. btc)
    BITCART_REVERSEPROXY: which reverse proxy to use (eg. nginx, nginx-https, none)
    REVERSEPROXY_HTTP_PORT: The port the reverse proxy binds to for public HTTP requests. Default: 80
    REVERSEPROXY_HTTPS_PORT: The port the reverse proxy binds to for public HTTPS requests. Default: 443
    REVERSEPROXY_DEFAULT_HOST: Optional, if using a reverse proxy nginx, specify which website should be presented if the server is accessed by its IP.
    BITCART_ENABLE_SSH: Gives Bitcart SSH access to the host by allowing it to edit authorized_keys of the host, it can be used for updating or reconfiguring your instance directly through the website. (Default: true)
    BITCART_SSH_PORT: Port where ssh server runs on host machine. Default: 22
    BITCART_HOST: The hostname of your website API (eg. api.example.com)
    BITCART_LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
    BITCART_STORE_HOST: The hostname of your website store (eg. example.com)
    BITCART_STORE_API_URL: The URL to your website API (hosted locally or remotely, eg. https://api.example.com)
    BITCART_ADMIN_HOST: The hostname of your website admin panel (eg. admin.example.com)
    BITCART_ADMIN_API_URL: The URL to your website API (hosted locally or remotely, eg. https://api.example.com)
    BTC_NETWORK: The network to run bitcoin daemon on (eg. mainnet, testnet)
    BTC_LIGHTNING: Whether to enable bitcoin lightning network or not (eg. true, false)
    BCH_NETWORK: The network to run bitcoin cash daemon on (eg. mainnet, testnet)
    ETH_NETWORK: The network to run ethereum daemon on (eg. mainnet, kovan)
    BNB_NETWORK: The network to run binancecoin daemon on (eg. mainnet, testnet)
    SBCH_NETWORK: The network to run smartbch daemon on (eg. mainnet, testnet)
    MATIC_NETWORK: The network to run polygon daemon on (eg. mainnet, testnet)
    TRX_NETWORK: The network to run tron daemon on (eg. mainnet, testnet)
    XRG_NETWORK: The network to run ergon daemon on (eg. mainnet)
    LTC_NETWORK: The network to run litecoin daemon on (eg. mainnet, testnet)
    LTC_LIGHTNING: Whether to enable litecoin lightning network or not (eg. true, false)
    BSTY_NETWORK: The network to run globalboost daemon on (eg. mainnet, testnet)
    BSTY_LIGHTNING: Whether to enable globalboost lightning network or not (eg. true, false)
    GRS_NETWORK: The network to run groestlcoin daemon on (eg. mainnet, testnet)
    GRS_LIGHTNING: Whether to enable groestlcoin lightning network or not (eg. true, false)
    XMR_NETWORK: The network to run monero daemon on (eg. mainnet, testnet)
    BITCART_ADDITIONAL_COMPONENTS: A list of additional components to add
    BITCART_EXCLUDE_COMPONENTS: A list of components to exclude from the result set
    BITCART_HTTPS_ENABLED: a special flag to rewrite bitcart API URLs to https. It does not enable https setup automatically and is required for custom cases such as cloudflare tunnel.
Add-on specific variables:
    TOR_RELAY_NICKNAME: If tor relay is activated, the relay nickname
    TOR_RELAY_EMAIL: If tor relay is activated, the email for Tor to contact you regarding your relay
    CLOUDFLARE_TUNNEL_TOKEN: Used to expose your instance to clearnet with a Cloudflare Tunnel
END
}

START=true
STARTUP_REGISTER=true
SYSTEMD_RELOAD=true
NAME_INPUT=false
PREVIEW_SETTINGS=false
NAME=
SCRIPTS_POSTFIX=
while (("$#")); do
    case "$1" in
    -h)
        display_help
        exit 0
        ;;
    --help)
        display_help
        exit 0
        ;;
    -p)
        PREVIEW_SETTINGS=true
        shift 1
        ;;
    --install-only)
        START=false
        shift 1
        ;;
    --no-startup-register)
        STARTUP_REGISTER=false
        shift 1
        ;;
    --no-systemd-reload)
        SYSTEMD_RELOAD=false
        shift 1
        ;;
    --name)
        NAME_INPUT=true
        shift 1
        ;;
    --) # end argument parsing
        shift
        break
        ;;
    -* | --*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        display_help
        exit 1
        ;;
    *) # preserve positional arguments
        if $NAME_INPUT; then
            NAME="$1"
            SCRIPTS_POSTFIX="-$NAME"
            NAME_INPUT=false
        fi
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
done

# Check root, and set correct profile file for the platform
get_profile_file "$SCRIPTS_POSTFIX"

# Set settings default values
[[ $BITCART_LETSENCRYPT_EMAIL == *@example.com ]] && echo "BITCART_LETSENCRYPT_EMAIL ends with @example.com, setting to empty email instead" && BITCART_LETSENCRYPT_EMAIL=""

: "${BITCART_LETSENCRYPT_EMAIL:=}"
: "${BITCART_INSTALL:=all}"
: "${BITCART_CRYPTOS:=btc}"
: "${BITCART_REVERSEPROXY:=nginx-https}"
: "${REVERSEPROXY_DEFAULT_HOST:=none}"
: "${REVERSEPROXY_HTTP_PORT:=80}"
: "${REVERSEPROXY_HTTPS_PORT:=443}"
: "${BITCART_ENABLE_SSH:=true}"
: "${BITCART_SSH_PORT:=22}"
: "${CLOUDFLARE_TUNNEL_TOKEN:=}"
: "${PIHOLE_SERVERIP:=}"

# Crypto default settings (adjust to add a new coin)
: "${BTC_NETWORK:=mainnet}"
: "${BTC_LIGHTNING:=false}"
: "${BCH_NETWORK:=mainnet}"
: "${ETH_NETWORK:=mainnet}"
: "${BNB_NETWORK:=mainnet}"
: "${SBCH_NETWORK:=mainnet}"
: "${MATIC_NETWORK:=mainnet}"
: "${TRX_NETWORK:=mainnet}"
: "${XRG_NETWORK:=mainnet}"
: "${LTC_NETWORK:=mainnet}"
: "${LTC_LIGHTNING:=false}"
: "${BSTY_NETWORK:=mainnet}"
: "${BSTY_LIGHTNING:=false}"
: "${GRS_NETWORK:=mainnet}"
: "${GRS_LIGHTNING:=false}"
: "${XMR_NETWORK:=mainnet}"

BITCART_BASE_DIRECTORY="$(pwd)"
BITCART_ENV_FILE="$BITCART_BASE_DIRECTORY/.env"
BITCART_DEPLOYMENT_CONFIG="$BITCART_BASE_DIRECTORY/.deploy"

first_setup=false
if ! [ -f "$BITCART_DEPLOYMENT_CONFIG" ]; then
    first_setup=true
fi

# SSH settings
BITCART_SSH_KEY_FILE=""

if $BITCART_ENABLE_SSH && ! [[ "$BITCART_HOST_SSH_AUTHORIZED_KEYS" ]]; then
    BITCART_HOST_SSH_AUTHORIZED_KEYS=~/.ssh/authorized_keys
fi

if $BITCART_ENABLE_SSH && [[ "$BITCART_HOST_SSH_AUTHORIZED_KEYS" ]]; then
    if ! [[ -f "$BITCART_HOST_SSH_AUTHORIZED_KEYS" ]]; then
        mkdir -p "$(dirname $BITCART_HOST_SSH_AUTHORIZED_KEYS)"
        touch $BITCART_HOST_SSH_AUTHORIZED_KEYS
    fi
    BITCART_SSH_AUTHORIZED_KEYS="/datadir/host_authorized_keys"
    BITCART_SSH_KEY_FILE="/datadir/host_id_rsa"
fi

if [ "$BITCARTGEN_DOCKER_IMAGE" == "bitcartcc/docker-compose-generator:local" ]; then
    export BITCARTGEN_DOCKER_IMAGE="bitcart/docker-compose-generator:local"
fi

echo "-------SETUP-----------
Parameters passed:
BITCART_HOST=$BITCART_HOST
REVERSEPROXY_HTTP_PORT=$REVERSEPROXY_HTTP_PORT
REVERSEPROXY_HTTPS_PORT=$REVERSEPROXY_HTTPS_PORT
REVERSEPROXY_DEFAULT_HOST=$REVERSEPROXY_DEFAULT_HOST
BITCART_ENABLE_SSH=$BITCART_ENABLE_SSH
BITCART_SSH_PORT=$BITCART_SSH_PORT
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
BITCART_STORE_HOST=$BITCART_STORE_HOST
BITCART_STORE_API_URL=$BITCART_STORE_API_URL
BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
BITCART_ADMIN_API_URL=$BITCART_ADMIN_API_URL
BITCART_INSTALL=$BITCART_INSTALL
BITCART_REVERSEPROXY=$BITCART_REVERSEPROXY
BITCART_CRYPTOS=$BITCART_CRYPTOS
BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS
BITCART_EXCLUDE_COMPONENTS=$BITCART_EXCLUDE_COMPONENTS
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
----------------------
Additional exported variables:
BITCART_BASE_DIRECTORY=$BITCART_BASE_DIRECTORY
BITCART_ENV_FILE=$BITCART_ENV_FILE
BITCART_DEPLOYMENT_CONFIG=$BITCART_DEPLOYMENT_CONFIG
BITCART_SSH_KEY_FILE=$BITCART_SSH_KEY_FILE
BITCART_SSH_AUTHORIZED_KEYS=$BITCART_SSH_AUTHORIZED_KEYS
BITCART_HOST_SSH_AUTHORIZED_KEYS=$BITCART_HOST_SSH_AUTHORIZED_KEYS
----------------------"

if $PREVIEW_SETTINGS; then
    exit 0
fi

# Local setup modifications
apply_local_modifications

# Configure deployment config to determine which deployment name to use
save_deploy_config

# Init the variables when a user log interactively
touch "$BASH_PROFILE_SCRIPT"
cat >${BASH_PROFILE_SCRIPT} <<EOF
#!/bin/bash
export COMPOSE_HTTP_TIMEOUT="180"
export BITCART_BASE_DIRECTORY="$BITCART_BASE_DIRECTORY"
export BITCART_INSTALL="${BITCART_INSTALL:-all}"
export BITCART_REVERSEPROXY="${BITCART_REVERSEPROXY:-nginx-https}"
export BITCART_CRYPTOS="${BITCART_CRYPTOS:-btc}"
export BITCART_ADDITIONAL_COMPONENTS="$BITCART_ADDITIONAL_COMPONENTS"
export BITCART_EXCLUDE_COMPONENTS="$BITCART_EXCLUDE_COMPONENTS"
export BITCART_ENV_FILE="$BITCART_ENV_FILE"
export BITCART_ENABLE_SSH=$BITCART_ENABLE_SSH
export BITCART_SSH_PORT=$BITCART_SSH_PORT
export BITCARTGEN_DOCKER_IMAGE="$BITCARTGEN_DOCKER_IMAGE"
export PIHOLE_SERVERIP="$PIHOLE_SERVERIP"
if cat "\$BITCART_ENV_FILE" &> /dev/null; then
  while IFS= read -r line; do
    ! [[ "\$line" == "#"* ]] && [[ "\$line" == *"="* ]] && export "\$line" || true
  done < "\$BITCART_ENV_FILE"
fi
EOF

chmod +x ${BASH_PROFILE_SCRIPT}

echo -e "Bitcart environment variables successfully saved in $BASH_PROFILE_SCRIPT\n"
echo -e "Bitcart deployment config saved in $BITCART_DEPLOYMENT_CONFIG\n"

bitcart_update_docker_env

echo -e "Bitcart docker-compose parameters saved in $BITCART_ENV_FILE\n"

. "$BASH_PROFILE_SCRIPT"

# Try to install docker
if ! [[ -x "$(command -v docker)" ]]; then
    if ! [[ -x "$(command -v curl)" ]]; then
        apt-get update 2>error
        apt-get install -y \
            curl \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            2>error
    fi
    if [[ "$(uname -m)" == "x86_64" ]] || [[ "$(uname -m)" == "armv7l" ]] || [[ "$(uname -m)" == "aarch64" ]] || [[ "$(uname -m)" == "arm64" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # Mac OS
            if ! [[ -x "$(command -v brew)" ]]; then
                # Brew is not installed, install it now
                echo "Homebrew, the package manager for Mac OS, is not installed. Installing it now..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            if [[ -x "$(command -v brew)" ]]; then
                echo "Homebrew is installed, but Docker isn't. Installing it now using brew..."
                # Brew is installed, install docker now
                brew install --cask docker
                # Launch UI and wait for user to finish installation
                nohup open /Applications/Docker.app >/dev/null 2>&1 &
                echo "Please finish Docker installation from it's UI"
                while ! docker ps >/dev/null 2>&1; do
                    sleep 5
                    echo "Waiting for docker to come up"
                done
            fi
        else
            # Not Mac OS
            echo "Trying to install docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            chmod +x get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
        fi
    else
        echo "Unsupported architecture $(uname -m)"
        exit 1
    fi

    if [[ "$(uname -m)" == "armv7l" ]] && cat "/etc/os-release" 2>/dev/null | grep -q "VERSION_CODENAME=buster" 2>/dev/null; then
        if [[ "$(apt list libseccomp2 2>/dev/null)" == *" 2.3"* ]]; then
            echo "Outdated version of libseccomp2, updating... (see: https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/)"
            # https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/
            apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
            echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' | sudo tee -a /etc/apt/sources.list.d/debian-backports.list
            apt update
            apt install libseccomp2 -t buster-backports
        fi
    fi
fi

check_docker_compose

if ! [[ -x "$(command -v docker)" ]]; then
    echo "Failed to install 'docker'. Please install docker manually, then retry."
    exit 1
fi

if ! [[ $(docker compose version 2>/dev/null) ]]; then
    echo "Failed to install 'docker compose'. Please install docker compose manually, then retry."
    exit 1
fi

# Generate the docker compose
if ! ./build.sh; then
    echo "Failed to generate the docker-compose"
    exit 1
fi

# Schedule for reboot
if $STARTUP_REGISTER && [[ -x "$(command -v systemctl)" ]]; then
    # Use systemd
    if [[ -e "/etc/init/start_containers.conf" ]]; then
        echo -e "Uninstalling upstart script /etc/init/start_containers.conf"
        rm "/etc/init/start_containers.conf"
        initctl reload-configuration
    fi
    echo "Adding bitcart$SCRIPTS_POSTFIX.service to systemd"
    echo "
[Unit]
Description=Bitcart service
After=docker.service network-online.target
Requires=docker.service network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c  '. \"$BASH_PROFILE_SCRIPT\" && cd \"$BITCART_BASE_DIRECTORY\" && ./start.sh'
ExecStop=/bin/bash -c   '. \"$BASH_PROFILE_SCRIPT\" && cd \"$BITCART_BASE_DIRECTORY\" && ./stop.sh'
ExecReload=/bin/bash -c '. \"$BASH_PROFILE_SCRIPT\" && cd \"$BITCART_BASE_DIRECTORY\" && ./stop.sh && ./start.sh'
[Install]
WantedBy=multi-user.target" >"/etc/systemd/system/bitcart$SCRIPTS_POSTFIX.service"

    if ! [[ -f "/etc/docker/daemon.json" ]] && [ -w "/etc/docker" ]; then
        echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" >/etc/docker/daemon.json
        echo "Setting limited log files in /etc/docker/daemon.json"
        $SYSTEMD_RELOAD && $START && systemctl restart docker
    fi

    echo -e "Bitcart systemd configured in /etc/systemd/system/bitcart$SCRIPTS_POSTFIX.service\n"
    if $SYSTEMD_RELOAD; then
        systemctl daemon-reload
        systemctl enable "bitcart$SCRIPTS_POSTFIX"
        if $START; then
            echo "Bitcart starting... this can take 5 to 10 minutes..."
            systemctl start "bitcart$SCRIPTS_POSTFIX"
            echo "Bitcart started"
        fi
    else
        systemctl --no-reload enable "bitcart$SCRIPTS_POSTFIX"
    fi
elif $STARTUP_REGISTER && [[ -x "$(command -v initctl)" ]]; then
    # Use upstart
    echo "Using upstart"
    echo "
# File is saved under /etc/init/start_containers.conf
# After file is modified, update config with : $ initctl reload-configuration
description     \"Start containers (see http://askubuntu.com/a/22105 and http://askubuntu.com/questions/612928/how-to-run-docker-compose-at-bootup)\"
start on filesystem and started docker
stop on runlevel [!2345]
# if you want it to automatically restart if it crashes, leave the next line in
# respawn # might cause over charge
script
    . \"$BASH_PROFILE_SCRIPT\"
    cd \"$BITCART_BASE_DIRECTORY\"
    ./start.sh
end script" >/etc/init/start_containers.conf
    echo -e "Bitcart upstart configured in /etc/init/start_containers.conf\n"

    if $START; then
        initctl reload-configuration
    fi
fi

install_tooling
if [[ "$first_setup" = true ]]; then
    bitcart_pull
fi

if $START; then
    ./start.sh
fi

echo "Setup done."
