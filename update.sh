#!/usr/bin/env bash
echo "Updating git repo..."
git pull --force
echo "Updating images..."
docker-compose -f compose/generated.yml pull
docker pull mrnaif/docker-compose-generator