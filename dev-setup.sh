#!/usr/bin/env bash
sudo apt install -y git
branch=${1:-master}
rm -rf compose/bitcart && git clone https://github.com/MrNaif2018/bitcart -b $branch compose/bitcart
cd compose/bitcart
cat > conf/.env << EOF
DB_HOST=database
REDIS_HOST=redis://redis
RPC_URL=http://bitcoin:5000
EOF
mkdir -p images
mkdir -p images/products
cd ../..
