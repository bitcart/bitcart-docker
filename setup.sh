sudo apt install -y git
rm -rf bitcart && git clone https://github.com/MrNaif2018/bitcart
cd bitcart
cat >> .env << EOF
DB_HOST=database
MEMCACHED_URL=http://memcached:11211
CELERY_BROKER_URL=amqp://rabbitmq
CHANNEL_LAYERS_HOST=amqp://guest:guest@rabbitmq/asgi
RPC_URL=http://daemon:5000
DEBUG=True
EOF
rm -rf gui/migrations
cd ..
