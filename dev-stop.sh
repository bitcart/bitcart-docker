#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
export NAME=bitcart
docker compose -p "$NAME" -f compose/generated.yml -f compose/dev-overrides.yml down
