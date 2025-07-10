#!/usr/bin/env bash
set -e
if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install git
else
    sudo apt install -y git
fi
branch=${1:-master}
rm -rf compose/bitcart && git clone --depth=1 https://github.com/bitcart/bitcart -b $branch compose/bitcart
cd compose/bitcart
rm -rf .git
cat >conf/.env <<EOF
DB_HOST=database
REDIS_HOST=redis://redis
BTC_HOST=bitcoin
LTC_HOST=litecoin
BCH_HOST=bitcoincash
XRG_HOST=ergon
ETH_HOST=ethereum
BNB_HOST=binancecoin
MATIC_HOST=polygon
TRX_HOST=tron
GRS_HOST=groestlcoin
XMR_HOST=monero
EOF
cd ../..
