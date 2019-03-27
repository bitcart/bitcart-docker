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
MEMCACHED_URL=http://memcached:11211
CELERY_BROKER_URL=amqp://rabbitmq
CHANNEL_LAYERS_HOST=amqp://rabbitmq
RPC_URL=http://daemon:5000
EOF
echo "Pulling images..."
docker pull mrnaif/bitcart
echo "Setup done."
