#!/usr/bin/env bash
source env.sh
accepted_modes=(production dev)
echo Availables modes: ${accepted_modes[*]}
value=${1:-production}

if ! [[ " ${accepted_modes[*]} " == *"$value"* ]]; then
    echo Selected mode $value is not supported
    exit 1
fi
echo Selected mode: $value
if [ "$value" == "production" ];then
    docker-compose down
elif [ "$value" == "dev" ];then
    docker-compose -f docker-compose.dev.yml down 
fi