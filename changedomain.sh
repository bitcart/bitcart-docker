#!/usr/bin/env bash

. helpers.sh
load_env

export NEW_HOST="$1"

if [[ "$NEW_HOST" == https:* ]] || [[ "$NEW_HOST" == http:* ]]; then
    echo "The domain should not start by http: or https:"
    exit 1
fi

export OLD_HOST=$BITCART_HOST
echo "Changing domain from \"$OLD_HOST\" to \"$NEW_HOST\""

export BITCART_HOST="$NEW_HOST"
[[ "$OLD_HOST" == "$REVERSEPROXY_DEFAULT_HOST" ]] && export REVERSEPROXY_DEFAULT_HOST="$NEW_HOST"

bitcart_update_docker_env
apply_local_modifications
bitcart_start