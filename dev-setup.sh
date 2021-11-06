#!/usr/bin/env bash
sudo apt install -y git
branch=${1:-master}
rm -rf compose/bitcart && git clone --depth=1 https://github.com/bitcartcc/bitcart -b $branch compose/bitcart
cd compose/bitcart
rm -rf .git
cat >conf/.env <<EOF
DB_HOST=database
REDIS_HOST=redis://redis
BTC_HOST=bitcoin
LTC_HOST=litecoin
BSTY_HOST=globalboost
BCH_HOST=bitcoincash
XRG_HOST=ergon
EOF
cd ../..
