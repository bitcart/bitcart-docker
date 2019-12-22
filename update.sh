#!/usr/bin/env bash
source env.sh
export USER_UID=${UID} 
export USER_GID=${GID}
echo "Updating git repo..."
git pull --force
echo "Updating images..."
docker-compose -f compose/generated.yml pull
docker pull mrnaif/docker-compose-generator
./build.sh