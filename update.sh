#!/usr/bin/env bash
echo "Updating git repo..."
git pull --force
echo "Updating images..."
docker pull mrnaif/bitcart:stable