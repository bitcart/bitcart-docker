sudo apt install -y git
rm -rf bitcart && git clone https://github.com/MrNaif2018/bitcart
cd bitcart
cat > conf/.env << EOF
DB_HOST=database
MEMCACHED_URL=http://memcached:11211
CELERY_BROKER_URL=amqp://rabbitmq
CHANNEL_LAYERS_HOST=amqp://rabbitmq
RPC_URL=http://daemon:5000
EOF
rm -rf gui/migrations
cd ..
