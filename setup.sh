#!/usr/bin/env bash

set +x

. helpers.sh

function display_help () {
cat <<-END
Usage:
------
Install BitcartCC on this server
This script must be run as root, except on Mac OS
    -h, --help: Show help
    --name name: Configure new deployment name. Affects naming of profile env files and
    startup config files. Allows multiple deployments on one server. 
    Empty by default
    --install-only: Run install only
    --docker-unavailable: Same as --install-only, but will also skip install steps requiring docker
    --no-startup-register: Do not register BitcartCC to start via systemctl or upstart
    --no-systemd-reload: Do not reload systemd configuration
This script will:
* Install Docker
* Install Docker-Compose
* Setup BitcartCC settings
* Make sure it starts at reboot via upstart or systemd
* Add BitcartCC utilities in /usr/bin
* Start BitcartCC
You can run again this script if you desire to change your configuration.
Make sure you own a domain with DNS record pointing to your website.
Passing domain ending with .local will automatically edit /etc/hosts and make it work.
Environment variables:
    BITCART_INSTALL: installation template to use (eg. all, backend, frontend)
    BITCART_CRYPTOS: comma-separated list of cryptocurrencies to enable (eg. btc)
    BITCART_REVERSEPROXY: which reverse proxy to use (eg. nginx, nginx-https, none)
    BITCART_HOST: The hostname of your website API (eg. api.example.com)
    BITCART_LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
    BITCART_STORE_HOST: The hostname of your website store (eg. example.com)
    BITCART_STORE_URL: The URL to your website API (hosted locally or remotely, eg. https://api.example.com)
    BITCART_ADMIN_HOST: The hostname of your website admin panel (eg. admin.example.com)
    BITCART_ADMIN_URL: The URL to your website API (hosted locally or remotely, eg. https://api.example.com)
    BTC_NETWORK: The network to run bitcoin daemon on (eg. mainnet, testnet)
    BTC_LIGHTNING: Whether to enable bitcoin lightning network or not (eg. true, false)
    BCH_NETWORK: The network to run bitcoin cash daemon on (eg. mainnet, testnet)
    LTC_NETWORK: The network to run litecoin daemon on (eg. mainnet, testnet)
    LTC_LIGHTNING: Whether to enable litecoin lightning network or not (eg. true, false)
    GZRO_NETWORK: The network to run gravity daemon on (eg. mainnet, testnet)
    GZRO_LIGHTNING: Whether to enable gravity lightning network or not (eg. true, false)
    BSTY_NETWORK: The network to run globalboost daemon on (eg. mainnet, testnet)
    BSTY_LIGHTNING: Whether to enable globalboost lightning network or not (eg. true, false)
    BITCART_ADDITIONAL_COMPONENTS: A list of additional components to add
    
END
}

START=true
HAS_DOCKER=true
STARTUP_REGISTER=true
SYSTEMD_RELOAD=true
NAME_INPUT=false
NAME=
SCRIPTS_POSTFIX=
while (( "$#" )); do
  case "$1" in
    -h)
      display_help
      exit 0
      ;;
    --help)
      display_help
      exit 0
      ;;
    --install-only)
      START=false
      shift 1
      ;;
    --docker-unavailable)
      START=false
      HAS_DOCKER=false
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
    -*|--*=) # unsupported flags
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

get_profile_file "$SCRIPTS_POSTFIX"

BITCART_BASE_DIRECTORY="$(pwd)"
BITCART_ENV_FILE="$BITCART_BASE_DIRECTORY/.env"
BITCART_DEPLOYMENT_CONFIG="$BITCART_BASE_DIRECTORY/.deploy"

if [[ "$BITCART_HOST" == *.local ]] ; then
    echo "Local setup detected."
    if [[ "$BITCART_NOHOSTSEDIT" = true ]] ; then
        echo "Not modifying hosts."
    else
        echo "WARNING! Modifying /etc/hosts to make local setup work. It may require superuser privileges."
        cat >> /etc/hosts << EOF
127.0.0.1   $BITCART_STORE_HOST
127.0.0.1   $BITCART_HOST
127.0.0.1   $BITCART_ADMIN_HOST
EOF
    fi
fi

mkdir -p compose/conf
mkdir -p compose/images
mkdir -p compose/images/products
cat > compose/conf/.env << EOF
DB_HOST=database
REDIS_HOST=redis://redis
BTC_HOST=bitcoin
LTC_HOST=litecoin
GZRO_HOST=gravity
BSTY_HOST=globalboost
BCH_HOST=bitcoincash
EOF
echo "
-------SETUP-----------
Parameters passed:
BITCART_HOST=$BITCART_HOST
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
BITCART_STORE_HOST=$BITCART_STORE_HOST
BITCART_STORE_URL=$BITCART_STORE_URL
BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
BITCART_ADMIN_URL=$BITCART_ADMIN_URL
BITCART_INSTALL=${BITCART_INSTALL:-all}
BITCART_REVERSEPROXY=${BITCART_REVERSEPROXY:-nginx-https}
BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}
BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS
BTC_NETWORK=${BTC_NETWORK:-mainnet}
BTC_LIGHTNING=${BTC_LIGHTNING:-false}
BCH_NETWORK=${BCH_NETWORK:-mainnet}
LTC_NETWORK=${LTC_NETWORK:-mainnet}
LTC_LIGHTNING=${LTC_LIGHTNING:-false}
GZRO_NETWORK=${GZRO_NETWORK:-mainnet}
GZRO_LIGHTNING=${GZRO_LIGHTNING:-false}
BSTY_NETWORK=${BSTY_NETWORK:-mainnet}
BSTY_LIGHTNING=${BSTY_LIGHTNING:-false}
----------------------
Additional exported variables:
BITCART_BASE_DIRECTORY=$BITCART_BASE_DIRECTORY
BITCART_ENV_FILE=$BITCART_ENV_FILE
BITCART_DEPLOYMENT_CONFIG=$BITCART_DEPLOYMENT_CONFIG
----------------------
"
# Init the variables when a user log interactively
cat > ${BITCART_DEPLOYMENT_CONFIG} << EOF
#!/bin/bash
NAME=$NAME
SCRIPTS_POSTFIX=$SCRIPTS_POSTFIX
EOF
touch "$BASH_PROFILE_SCRIPT"
cat > ${BASH_PROFILE_SCRIPT} << EOF
#!/bin/bash
export COMPOSE_HTTP_TIMEOUT="180"
export BITCART_BASE_DIRECTORY="$BITCART_BASE_DIRECTORY"
export BITCART_INSTALL="${BITCART_INSTALL:-all}"
export BITCART_REVERSEPROXY="${BITCART_REVERSEPROXY:-nginx-https}"
export BITCART_CRYPTOS="${BITCART_CRYPTOS:-btc}"
export BITCART_ADDITIONAL_COMPONENTS="$BITCART_ADDITIONAL_COMPONENTS"
export BITCART_ENV_FILE="$BITCART_ENV_FILE"
if cat "\$BITCART_ENV_FILE" &> /dev/null; then
  while IFS= read -r line; do
    ! [[ "\$line" == "#"* ]] && [[ "\$line" == *"="* ]] && export "\$line" || true
  done < "\$BITCART_ENV_FILE"
fi
EOF

chmod +x ${BASH_PROFILE_SCRIPT}
chmod +x ${BITCART_DEPLOYMENT_CONFIG}


echo -e "BitcartCC environment variables successfully saved in $BASH_PROFILE_SCRIPT\n"
echo -e "BitcartCC deployment config saved in $BITCART_DEPLOYMENT_CONFIG\n"

bitcart_update_docker_env

echo -e "BitcartCC docker-compose parameters saved in $BITCART_ENV_FILE\n"

. "$BASH_PROFILE_SCRIPT"

if ! [[ -x "$(command -v docker)" ]] || ! [[ -x "$(command -v docker-compose)" ]]; then
    if ! [[ -x "$(command -v curl)" ]]; then
        apt-get update 2>error
        apt-get install -y \
            curl \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            2>error
    fi
    if ! [[ -x "$(command -v docker)" ]]; then
        if [[ "$(uname -m)" == "x86_64" ]] || [[ "$(uname -m)" == "armv7l" ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # Mac OS	
                if ! [[ -x "$(command -v brew)" ]]; then
                    # Brew is not installed, install it now
                    echo "Homebrew, the package manager for Mac OS, is not installed. Installing it now..."
                    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
                fi
                if [[ -x "$(command -v brew)" ]]; then
                    echo "Homebrew is installed, but Docker isn't. Installing it now using brew..."
                    # Brew is installed, install docker now
                    # This sequence is a bit strange, but it's what what needed to get it working on a fresh Mac OS X Mojave install
                    brew cask install docker
                    brew install docker
                    brew link docker
                fi
            else
                # Not Mac OS
                echo "Trying to install docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                chmod +x get-docker.sh
                sh get-docker.sh
                rm get-docker.sh
            fi
        elif [[ "$(uname -m)" == "aarch64" ]]; then
            echo "Trying to install docker for armv7 on a aarch64 board..."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
            RELEASE=$(lsb_release -cs)
            if [[ "$RELEASE" == "bionic" ]]; then
                RELEASE=xenial
            fi
            if [[ -x "$(command -v dpkg)" ]]; then
                dpkg --add-architecture armhf
            fi
            add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $RELEASE stable"
            apt-get update -y
            # zlib1g:armhf is needed for docker-compose, but we install it here as we changed dpkg here
            apt-get install -y docker-ce:armhf zlib1g:armhf
        fi
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        if ! [[ "$OSTYPE" == "darwin"* ]] && $HAS_DOCKER; then
            echo "Trying to install docker-compose by using the docker-compose-builder ($(uname -m))"
            ! [[ -d "dist" ]] && mkdir dist
            docker run --rm -v "$(pwd)/dist:/dist" bitcartcc/docker-compose-builder:1.25.4
            mv dist/docker-compose /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            rm -rf "dist"
        fi
    fi
fi

if $HAS_DOCKER; then
    if ! [[ -x "$(command -v docker)" ]]; then
        echo "Failed to install 'docker'. Please install docker manually, then retry."
        exit 1
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        echo "Failed to install 'docker-compose'. Please install docker-compose manually, then retry."
        exit 1
    fi
fi

# Generate the docker compose
if $HAS_DOCKER; then
    if ! ./build.sh; then
        echo "Failed to generate the docker-compose"
        exit 1
    fi
fi
   
# Schedule for reboot
if $STARTUP_REGISTER && [[ -x "$(command -v systemctl)" ]]; then
    # Use systemd
    if [[ -e "/etc/init/start_containers.conf" ]]; then
        echo -e "Uninstalling upstart script /etc/init/start_containers.conf"
        rm "/etc/init/start_containers.conf"
        initctl reload-configuration
    fi
    echo "Adding bitcartcc$SCRIPTS_POSTFIX.service to systemd"
    echo "
[Unit]
Description=BitcartCC service
After=docker.service network-online.target
Requires=docker.service network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c  '. \"$BASH_PROFILE_SCRIPT\" && cd \"$BITCART_BASE_DIRECTORY\" && ./start.sh'
ExecStop=/bin/bash -c   '. \"$BASH_PROFILE_SCRIPT\" && cd \"$BITCART_BASE_DIRECTORY\" && ./stop.sh'
ExecReload=/bin/bash -c '. \"$BASH_PROFILE_SCRIPT\" && cd \"$BITCART_BASE_DIRECTORY\" && ./stop.sh && ./start.sh'
[Install]
WantedBy=multi-user.target" > "/etc/systemd/system/bitcartcc$SCRIPTS_POSTFIX.service"

    if ! [[ -f "/etc/docker/daemon.json" ]] && [ -w "/etc/docker" ]; then
        echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" > /etc/docker/daemon.json
        echo "Setting limited log files in /etc/docker/daemon.json"
        $SYSTEMD_RELOAD && $START && systemctl restart docker
    fi

    echo -e "BitcartCC systemd configured in /etc/systemd/system/bitcartcc$SCRIPTS_POSTFIX.service\n"
    if $SYSTEMD_RELOAD; then
        systemctl daemon-reload
        systemctl enable "bitcartcc$SCRIPTS_POSTFIX"
        if $START; then
            echo "BitcartCC starting... this can take 5 to 10 minutes..."
            systemctl start "bitcartcc$SCRIPTS_POSTFIX"
            echo "BitcartCC started"
        fi
    else
        systemctl --no-reload enable "bitcartcc$SCRIPTS_POSTFIX"
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
end script" > /etc/init/start_containers.conf
    echo -e "BitcartCC upstart configured in /etc/init/start_containers.conf\n"

    if $START; then
        initctl reload-configuration
    fi
fi

if $START; then
    ./start.sh
elif $HAS_DOCKER; then
    docker-compose -f compose/generated.yml pull
fi

echo "Setup done."
