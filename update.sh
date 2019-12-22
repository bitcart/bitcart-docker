#!/usr/bin/env bash
source env.sh
echo "Updating git repo..."
git pull --force
echo "Updating images..."
docker-compose -f compose/generated.yml pull
docker pull mrnaif/docker-compose-generator
./build.sh