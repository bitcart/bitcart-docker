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
echo "Creating config file..."
mkdir -p conf
cat > conf/.env << EOF
DB_HOST=database
CHANNEL_LAYERS_HOST=redis://redis
CACHE_REDIS_URL=redis://redis
DRAMATIQ_REDIS_URL=redis://redis
RPC_URL=http://daemon:5000
ALLOWED_HOSTS=$BITCART_HOST
EOF
echo "
Creating docker config file with parameters:
BITCART_HOST=$BITCART_HOST
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
"
echo "
Generating docker image based on parameters:
BITCART_INSTALL={$BITCART_INSTALL:-all}
"
./build.sh
cat > env.sh << EOF
export BITCART_HOST=$BITCART_HOST
export BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
EOF
chmod +x env.sh
echo "Pulling images..."
docker pull mrnaif/bitcart:stable
echo "Setup done."
