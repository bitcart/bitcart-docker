#!/usr/bin/env bash
sudo apt install -y git
branch=${1:-master}
rm -rf bitcart && git clone https://github.com/MrNaif2018/bitcart -b $branch
cd bitcart
cat > conf/.env << EOF
DB_HOST=database
CHANNEL_LAYERS_HOST=redis://redis
CACHE_REDIS_URL=redis://redis
DRAMATIQ_REDIS_URL=redis://redis
RPC_URL=http://daemon:5000
EOF
cd ..
