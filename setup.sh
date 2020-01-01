#!/usr/bin/env bash
if ! [ -x "$(command -v curl)" ]; then
        apt-get update 2>error
        apt-get install -y \
            curl \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            2>/dev/null
fi
if ! [ -x "$(command -v docker)" ]; then
    echo "Trying to install docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi
if ! [ -x "$(command -v docker-compose)" ]; then
    curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi
if [[ "$BITCART_HOST" == *.local ]] ; then
    echo "Local setup detected."
    if [[ "$BITCART_NOHOSTSEDIT" = true ]] ; then
        echo "Not modifying hosts."
    else
        echo "WARNING! Modifying /etc/hosts to make local setup work. It may require superuser privileges."
        cat >> /etc/hosts << EOF
127.0.0.1   $BITCART_FRONTEND_HOST
127.0.0.1   $BITCART_HOST
127.0.0.1   $BITCART_ADMIN_HOST
EOF
    fi
fi
        
echo "Creating config file..."
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
EOF
echo "
Creating docker config file with parameters:
BITCART_HOST=$BITCART_HOST
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
BITCART_FRONTEND_HOST=$BITCART_FRONTEND_HOST
BITCART_FRONTEND_URL=$BITCART_FRONTEND_URL
BITCART_FRONTEND_EMAIL=$BITCART_FRONTEND_EMAIL
BITCART_FRONTEND_PASSWORD=$BITCART_FRONTEND_PASSWORD
BITCART_FRONTEND_STORE=$BITCART_FRONTEND_STORE
BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
BITCART_ADMIN_URL=$BITCART_ADMIN_URL
BITCART_ADMIN_TOKEN=$BITCART_ADMIN_TOKEN
BTC_NETWORK=${BTC_NETWORK:-mainnet}
BTC_LIGHTNING=${BTC_LIGHTNING:-true}
LTC_NETWORK=${LTC_NETWORK:-mainnet}
LTC_LIGHTNING=${LTC_LIGHTNING:-true}
GZRO_NETWORK=${GZRO_NETWORK:-mainnet}
GZRO_LIGHTNING=${GZRO_LIGHTNING:-true}
BSTY_NETWORK=${BSTY_NETWORK:-mainnet}
BSTY_LIGHTNING=${BSTY_LIGHTNING:-true}
BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS
"
echo "
Generating docker image based on parameters:
BITCART_INSTALL=${BITCART_INSTALL:-all}
BITCART_REVERSEPROXY=${BITCART_REVERSEPROXY:-nginx-https}
BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}
BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS
"
cat > generator-env.sh << EOF
export BITCART_INSTALL=${BITCART_INSTALL:-all}
export BITCART_REVERSEPROXY=${BITCART_REVERSEPROXY:-nginx-https}
export BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}
export BITCART_ADDITIONAL_COMPONENTS=$BITCART_ADDITIONAL_COMPONENTS
EOF
./build.sh
cat > env.sh << EOF
export BITCART_HOST=$BITCART_HOST
export BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
export BITCART_FRONTEND_HOST=$BITCART_FRONTEND_HOST
export BITCART_FRONTEND_URL=$BITCART_FRONTEND_URL
export BITCART_FRONTEND_EMAIL=$BITCART_FRONTEND_EMAIL
export BITCART_FRONTEND_PASSWORD=$BITCART_FRONTEND_PASSWORD
export BITCART_FRONTEND_STORE=$BITCART_FRONTEND_STORE
export BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
export BITCART_ADMIN_URL=$BITCART_ADMIN_URL
export BITCART_ADMIN_TOKEN=$BITCART_ADMIN_TOKEN
export BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}
export BTC_NETWORK=$BTC_NETWORK
export BTC_LIGHTNING=$BTC_LIGHTNING
export LTC_NETWORK=$LTC_NETWORK
export LTC_LIGHTNING=$LTC_LIGHTNING
export GZRO_NETWORK=$GZRO_NETWORK
export GZRO_LIGHTNING=$GZRO_LIGHTNING
export BSTY_NETWORK=$BSTY_NETWORK
export BSTY_LIGHTNING=$BSTY_LIGHTNING
EOF
chmod +x env.sh
echo "Pulling images..."
docker pull mrnaif/bitcart:stable
echo "Setup done."
