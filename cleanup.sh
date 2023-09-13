#!/usr/bin/env bash

docker image prune -af --filter "label=org.bitcart.image" --filter "label!=org.bitcart.image=docker-compose-generator"
