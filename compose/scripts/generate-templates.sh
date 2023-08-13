#!/usr/bin/env bash
set -Eeuo pipefail

# Thanks to https://github.com/docker-library

images="compose/scripts/.images.json"

if [ ! -f "$images" ] || [ ! "$#" -eq 0 ]; then
    wget -qO "$images" 'https://raw.githubusercontent.com/bitcart/bitcart/master/.circleci/images.json'
fi

generated_warning() {
    cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "generate-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

coins="$(jq -r '.[].dockerfile | sub(".Dockerfile"; "")' $images)"
eval "coins=( $coins )"

for coin in "${coins[@]}"; do
    if [ "$coin" == "backend" ]; then
        continue
    fi
    export bases=$(jq -r ".[\"bitcart-$coin\"].bases // \"btc\"" $images)
    export coin
    custom=false
    name=$(jq -r ".[\"bitcart-$coin\"].name // \"\"" $images)
    if [ -z "$name" ]; then
        if [ "$bases" == "btc" ]; then
            name="electrum"
        fi
        if [ "$bases" == "eth" ]; then
            name="bitcart"
        fi
    else
        custom=true
    fi
    export name
    export custom
    echo "processing compose/$coin..."
    {
        generated_warning
        gawk -f "compose/scripts/.jq-template.awk" "compose/Dockerfile-coin.template"
    } >"compose/$coin.Dockerfile"
done
