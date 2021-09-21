#!/usr/bin/env bash

docker image prune -af --filter "label=org.bitcartcc.image" --filter "label!=org.bitcartcc.image=docker-compose-generator"
